# ******************************************************************************
# BipolarMisclassificationModule - Helper Functions
# ******************************************************************************
#
# This file contains helper functions for the BipolarMisclassificationModule
# that implement the core prediction and validation logic from the original study.
#
# ******************************************************************************

# Get bipolar prediction data (adapted from original getBipolarData function)
.getBipolarData <- function(connectionDetails,
                           cdmDatabaseSchema,
                           cohortDatabaseSchema,
                           cohortTable,
                           targetId,
                           outcomeId,
                           sampleSize = NULL) {
  
  # Define cohorts for covariates (from original study)
  cohorts <- data.frame(
    names = c('mental health disorder','Suicidal thoughts or Self harm',
              'Pregnancy', 'Anxiety drugs and Anxiety', 'Mild depression',
              'Severe depression', 'MDD with pyschosis', 'Substance use disorder'),
    ids = c(11580, 11594, 11582, 11584, 11586, 11588, 11589, 11590),
    endDays = c(-1, rep(0, 7)),
    stringsAsFactors = FALSE
  )
  
  # Create covariate settings
  cohortCov <- list()
  length(cohortCov) <- nrow(cohorts) + 1
  
  # Add demographics age group
  cohortCov[[1]] <- FeatureExtraction::createCovariateSettings(useDemographicsAgeGroup = TRUE)
  
  # Add cohort-based covariates
  for(i in 1:nrow(cohorts)) {
    cohortCov[[1 + i]] <- .createCohortCovariateSettingsCustom(
      covariateName = as.character(cohorts$names[i]),
      covariateId = cohorts$ids[i] * 1000 + 456,
      cohortDatabaseSchema = cohortDatabaseSchema,
      cohortTable = cohortTable,
      targetId = cohorts$ids[i],
      startDay = -9999, 
      endDay = cohorts$endDays[i],
      count = FALSE,
      analysisId = 456
    )
  }
  
  # Create database details
  databaseDetails <- PatientLevelPrediction::createDatabaseDetails(
    connectionDetails = connectionDetails,
    cdmDatabaseSchema = cdmDatabaseSchema,
    cohortDatabaseSchema = cohortDatabaseSchema,
    cohortTable = cohortTable,
    outcomeDatabaseSchema = cohortDatabaseSchema,
    outcomeTable = cohortTable,
    targetId = targetId,
    outcomeIds = outcomeId
  )
  
  # Set up data restrictions
  restrictPlpDataSettings <- PatientLevelPrediction::createRestrictPlpDataSettings(sampleSize = sampleSize)
  
  # Get PLP data
  plpData <- PatientLevelPrediction::getPlpData(
    databaseDetails = databaseDetails,
    covariateSettings = cohortCov,
    restrictPlpDataSettings = restrictPlpDataSettings
  )
  
  return(plpData)
}

# Create custom cohort covariate settings (from original study)
.createCohortCovariateSettingsCustom <- function(covariateName, covariateId,
                                                cohortDatabaseSchema, cohortTable, targetId,
                                                startDay = -30, endDay = 0, count = TRUE, analysisId) {
  covariateSettings <- list(
    covariateName = covariateName, 
    covariateId = covariateId,
    cohortDatabaseSchema = cohortDatabaseSchema,
    cohortTable = cohortTable,
    targetId = targetId,
    startDay = startDay,
    endDay = endDay,
    count = count,
    analysisId = analysisId
  )
  
  attr(covariateSettings, "fun") <- "getCohortCovariateData"
  class(covariateSettings) <- "covariateSettings"
  return(covariateSettings)
}

# Get cohort covariate data (from original BipolarMisclassificationValidation study)
getCohortCovariateData <- function(connection,
                                   tempEmulationSchema = NULL,
                                   cdmDatabaseSchema,
                                   cdmVersion = "5",
                                   cohortTable = "#cohort_person",
                                   rowIdField = "row_id",
                                   aggregated,
                                   targetId,
                                   covariateSettings,
                                   ...) {

  # Some SQL to construct the covariate (from original study):
  sql <- paste(
    "select a.@row_id_field AS row_id, @covariate_id AS covariate_id,
    {@countval}?{count(distinct b.cohort_start_date)}:{max(1)} as covariate_value",
    "from @cohort_temp_table a inner join @covariate_cohort_schema.@covariate_cohort_table b",
    " on a.subject_id = b.subject_id and ",
    " b.cohort_start_date >= dateadd(day, @startDay, a.cohort_start_date) and ",
    " b.cohort_start_date <= dateadd(day, @endDay, a.cohort_start_date) ",
    "where b.cohort_definition_id = @covariate_cohort_id
    group by a.@row_id_field "
  )

  sql <- SqlRender::render(sql,
                          row_id_field = rowIdField,
                          covariate_id = covariateSettings$covariateId,
                          countval = covariateSettings$count,
                          cohort_temp_table = cohortTable,
                          covariate_cohort_schema = covariateSettings$cohortDatabaseSchema,
                          covariate_cohort_table = covariateSettings$cohortTable,
                          covariate_cohort_id = covariateSettings$targetId,
                          startDay = covariateSettings$startDay,
                          endDay = covariateSettings$endDay)

  sql <- SqlRender::translate(sql, targetDialect = attr(connection, "dbms"), tempEmulationSchema = tempEmulationSchema)

  # Retrieve the covariate:
  covariates <- DatabaseConnector::querySql(connection, sql)

  # Convert column names to camelCase:
  colnames(covariates) <- SqlRender::snakeCaseToCamelCase(colnames(covariates))

  # Construct covariate reference:
  sql <- "select @covariate_id as covariate_id, '@concept_set' as covariate_name,
  456 as analysis_id, -1 as concept_id"

  sql <- SqlRender::render(sql,
                          covariate_id = covariateSettings$covariateId,
                          concept_set = covariateSettings$covariateName)

  sql <- SqlRender::translate(sql, targetDialect = attr(connection, "dbms"), tempEmulationSchema = tempEmulationSchema)

  # Retrieve the covariateRef:
  covariateRef  <- DatabaseConnector::querySql(connection, sql)
  colnames(covariateRef) <- SqlRender::snakeCaseToCamelCase(colnames(covariateRef))

  analysisRef <- data.frame(analysisId = 456,
                            analysisName = "cohort covariate",
                            domainId = "cohort covariate",
                            startDay = covariateSettings$startDay,
                            endDay = covariateSettings$endDay,
                            isBinary = "Y",
                            missingMeansZero = "Y")

  metaData <- list(sql = sql, call = match.call())

  # Use Andromeda for large data compatibility (updated from original ff)
  result <- Andromeda::andromeda(covariates = covariates,
                                 covariateRef = covariateRef,
                                 analysisRef = analysisRef)

  attr(result, "metaData") <- metaData
  class(result) <- "CovariateData"
  return(result)
}

# Apply the bipolar prediction model (adapted from original predictBipolar function)
.applyPredictionModel <- function(plpData, population, settings) {
  
  # Get model coefficients
  coefficients <- settings$modelCoefficients
  
  # Create prediction based on covariates and coefficients
  if('covariateData' %in% names(plpData)) {
    plpData$covariateData$coefficients <- tibble::as_tibble(coefficients)
    on.exit(plpData$covariateData$coefficients <- NULL)
    
    prediction <- plpData$covariateData$covariates %>%
      dplyr::inner_join(plpData$covariateData$coefficients, by = "covariateId") %>%
      dplyr::mutate(value = covariateValue * points) %>%
      dplyr::select(rowId, value) %>%
      dplyr::group_by(rowId) %>%
      dplyr::summarise(value = sum(value, na.rm = TRUE)) %>% 
      dplyr::collect()
    
  } else {
    prediction <- merge(plpData$covariates, ff::as.ffdf(coefficients), by = "covariateId")
    prediction$value <- prediction$covariateValue * prediction$points
    prediction <- PatientLevelPrediction:::bySumFf(prediction$value, prediction$rowId)
    colnames(prediction) <- c("rowId", "value")
  }
  
  # Merge with population
  prediction <- merge(population, prediction, by = "rowId", all.x = TRUE)
  prediction$value[is.na(prediction$value)] <- 0

  # Set metadata (exactly as in original predictBipolar function)
  attr(prediction, "metaData") <- list(
    predictionType = 'binary',
    modelType = 'binary',
    evaluationColumn = "value"
  )

  return(prediction)
}

# Create PLP model object (exactly replicating original study)
.createPlpModel <- function(settings) {
  # Get model coefficients (from original getModel function)
  modelCoefficients <- settings$modelCoefficients

  plpModel <- list(
    model = modelCoefficients,
    analysisId = 'Bipolar',  # Match original analysisId
    hyperParamSearch = NULL,
    index = NULL,
    trainCVAuc = NULL,
    modelSettings = list(model = 'score', modelParameters = NULL),
    metaData = list(
      modelType = "binary",
      predictionType = "binary",
      outcomeId = settings$outcomeCohortId,
      targetId = settings$targetCohortId
    ),
    populationSettings = NULL,
    trainingTime = NULL,
    varImp = NULL,
    dense = TRUE,
    targetId = settings$targetCohortId,
    outcomeId = settings$outcomeCohortId,
    covariateMap = NULL
  )

  class(plpModel) <- "plpModel"
  attr(plpModel, "predictionFunction") <- "predictBipolar"
  attr(plpModel, "saveType") <- "RtoJson"

  return(plpModel)
}

# Save validation results
.saveValidationResults <- function(result, jobContext, settings) {
  
  # Create results directory
  resultsDir <- file.path(jobContext$moduleExecutionSettings$resultsSubFolder, "BipolarMisclassificationModule")
  if (!dir.exists(resultsDir)) {
    dir.create(resultsDir, recursive = TRUE)
  }
  
  # Evaluate the prediction
  evaluation <- PatientLevelPrediction::evaluatePlp(
    prediction = result,
    plpData = NULL  # Not needed for evaluation
  )
  
  # Save main results
  saveRDS(list(
    prediction = result,
    evaluation = evaluation,
    settings = settings
  ), file.path(resultsDir, "validationResults.rds"))
  
  # Save CSV results for Strategus
  .exportResultsToCsv(result, evaluation, resultsDir, settings)
  
  ParallelLogger::logInfo("Validation results saved")
}

# Get score summaries for threshold analysis (from original study)
getScoreSummaries <- function(prediction) {
  # Added later - clamp values to avoid Inf/NaN (from original)
  prediction$value <- pmin(pmax(prediction$value, 1e-15), 1 - 1e-15)

  getInfo <- function(thres, pred) {
    TP = sum(pred$outcomeCount[pred$value >= thres])
    P = sum(pred$outcomeCount > 0)
    pN = sum(pred$value >= thres)
    N <- length(pred$value)
    thresN <- sum(pred$value == thres)
    thresO <- sum(pred$outcomeCount[pred$value == thres])
    return(c(thres = thres, N = thresN, O = thresO, popN = pN/N,
             sensitivity = TP/P, PPV = TP/pN))
  }

  res <- do.call(rbind, lapply(unique(prediction$value), function(x) getInfo(x, prediction)))
  return(res)
}

# Get survival information (from original study)
getSurvivalInfo <- function(plpData, prediction) {
  # Extract population from plpData
  population <- plpData$population

  data <- merge(population, prediction[, c('rowId','value')], by='rowId')
  data$daysToEvent[is.na(data$daysToEvent)] <- data$survivalTime[is.na(data$daysToEvent)]

  getSurv <- function(dayL, dayU, data) {
    return(c(dayL = dayL,
             dayU = dayU,
             remainingDayL = sum(data$daysToEvent >= dayL),
             lost = sum(data$outcomeCount[data$daysToEvent < dayU & data$daysToEvent >= dayL] == 0),
             outcome = sum(data$outcomeCount[data$daysToEvent < dayU & data$daysToEvent >= dayL])))
  }

  # Time periods from original study
  periods <- list(
    c(0, 30), c(30, 60), c(60, 90), c(90, 120), c(120, 150), c(150, 180),
    c(180, 210), c(210, 240), c(240, 270), c(270, 300), c(300, 330), c(330, 365)
  )

  survInfo <- do.call(rbind, lapply(periods, function(p) getSurv(p[1], p[2], data)))
  return(as.data.frame(survInfo))
}

# Get AUC by year analysis (from original study)
getAUCbyYear <- function(result) {
  prediction <- result$prediction

  # Extract year from index date
  prediction$indexYear <- as.numeric(format(as.Date(prediction$cohortStartDate), "%Y"))

  # Calculate AUC for each year
  years <- unique(prediction$indexYear)
  aucByYear <- data.frame()

  for(year in years) {
    yearData <- prediction[prediction$indexYear == year, ]
    if(nrow(yearData) > 10 && sum(yearData$outcomeCount) > 0) {
      # Calculate AUC using ROCR or similar
      tryCatch({
        auc <- PatientLevelPrediction::computeAuc(yearData)
        aucByYear <- rbind(aucByYear, data.frame(
          year = year,
          auc = auc,
          n = nrow(yearData),
          events = sum(yearData$outcomeCount)
        ))
      }, error = function(e) {
        ParallelLogger::logWarn(paste("Could not calculate AUC for year", year, ":", e$message))
      })
    }
  }

  return(aucByYear)
}

# Export results to CSV format for Strategus
.exportResultsToCsv <- function(prediction, evaluation, resultsDir, settings) {
  
  # Performance metrics
  performance <- data.frame(
    analysis_id = "BipolarMisclassification",
    target_cohort_id = settings$targetCohortId,
    outcome_cohort_id = settings$outcomeCohortId,
    auc = evaluation$evaluationStatistics$value[evaluation$evaluationStatistics$metric == "AUC"],
    auprc = evaluation$evaluationStatistics$value[evaluation$evaluationStatistics$metric == "AUPRC"],
    brier_score = evaluation$evaluationStatistics$value[evaluation$evaluationStatistics$metric == "BrierScore"],
    population_size = nrow(prediction),
    outcome_count = sum(prediction$outcomeCount),
    stringsAsFactors = FALSE
  )
  
  write.csv(performance, file.path(resultsDir, "performance_metrics.csv"), row.names = FALSE)
  
  # Calibration results
  if (!is.null(evaluation$calibrationSummary)) {
    calibration <- evaluation$calibrationSummary
    calibration$analysis_id <- "BipolarMisclassification"
    write.csv(calibration, file.path(resultsDir, "calibration.csv"), row.names = FALSE)
  }
  
  # Threshold summary
  if (!is.null(evaluation$thresholdSummary)) {
    threshold <- evaluation$thresholdSummary
    threshold$analysis_id <- "BipolarMisclassification"
    write.csv(threshold, file.path(resultsDir, "threshold_summary.csv"), row.names = FALSE)
  }
  
  ParallelLogger::logInfo("Results exported to CSV format")
}
