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
  
  # Convert score to probability
  prediction$value <- 1 / (1 + exp(-prediction$value))
  
  # Add preference score
  prediction$preferenceScore <- prediction$value
  
  # Set metadata
  attr(prediction, "metaData") <- list(
    predictionType = 'binary', 
    modelType = 'binary', 
    evaluationColumn = "value"
  )
  
  return(prediction)
}

# Create PLP model object (adapted from original study)
.createPlpModel <- function(settings) {
  plpModel <- list(
    model = settings$modelCoefficients,
    analysisId = 'BipolarMisclassification',
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
