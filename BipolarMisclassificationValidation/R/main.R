

#' Execute the validation study
#'
#' @details
#' This function will execute the sepcified parts of the study
#'
#' @param connectionDetails    An object of type \code{connectionDetails} as created using the
#'                             \code{\link[DatabaseConnector]{createConnectionDetails}} function in the
#'                             DatabaseConnector package.
#' @param databaseName         A string representing a shareable name of your databasd
#' @param cdmDatabaseSchema    Schema name where your patient-level data in OMOP CDM format resides.
#'                             Note that for SQL Server, this should include both the database and
#'                             schema name, for example 'cdm_data.dbo'.
#' @param cohortDatabaseSchema Schema name where intermediate data can be stored. You will need to have
#'                             write priviliges in this schema. Note that for SQL Server, this should
#'                             include both the database and schema name, for example 'cdm_data.dbo'.
#' @param tempEmulationSchema     Should be used in Oracle to specify a schema where the user has write
#'                             priviliges for storing temporary tables.
#' @param cohortTable          The name of the table that will be created in the work database schema.
#'                             This table will hold the exposure and outcome cohorts used in this
#'                             study.
#' @param outputFolder         Name of local folder to place results; make sure to use forward slashes
#'                             (/)
#' @param createCohorts        Whether to create the cohorts for the study
#' @param runValidation        Whether to run the valdiation models
#' @param packageResults       Whether to package the results (after removing sensitive details)
#' @param minCellCount         The min count for the result to be included in the package results
#' @param sampleSize           Whether to sample from the target cohort - if desired add the number to sample
#' @param restrictToAdults     Whether to restrict the validation to patients 18 or older
#' @export
execute <- function(connectionDetails,
                    databaseName,
                    cdmDatabaseSchema,
                    cohortDatabaseSchema,
                    tempEmulationSchema,
                    cohortTable,
                    outputFolder,
                    viewModel = F,
                    createCohorts = F,
                    runValidation = F,
                    packageResults = F,
                    minCellCount = 0,
                    sampleSize = NULL,
                    restrictToAdults = F){

  if (!file.exists(outputFolder))
    dir.create(outputFolder, recursive = TRUE)

  ParallelLogger::addDefaultFileLogger(file.path(outputFolder, "log.txt"))

  if(viewModel){
    View(getModel())
  }

  if(createCohorts){
    ParallelLogger::logInfo("Creating Cohorts")
    createCohorts(connectionDetails,
                  cdmDatabaseSchema=cdmDatabaseSchema,
                  cohortDatabaseSchema=cohortDatabaseSchema,
                  cohortTable=cohortTable,
                  tempEmulationSchema = tempEmulationSchema,
                  outputFolder = outputFolder,
                  restrictToAdults = restrictToAdults)
  }

  if(runValidation){
    ParallelLogger::logInfo("Validating Models")

    # get the data:
    plpData <- getBipolarData(connectionDetails = connectionDetails,
                              cdmDatabaseSchema = cdmDatabaseSchema,
                              cohortDatabaseSchema = cohortDatabaseSchema,
                              cohortTable = cohortTable,
                              targetId = 12292,
                              outcomeDatabaseSchema = cohortDatabaseSchema,
                              outcomeTable = cohortTable,
                              outcomeId = 7746,
                              tempEmulationSchema = tempEmulationSchema,
                              sampleSize = sampleSize)

    populationSettings <- createStudyPopulationSettings(removeSubjectsWithPriorOutcome = T,
                                                                 requireTimeAtRisk = T, minTimeAtRisk = 364,
                                                                 riskWindowStart = 1,
                                                                 riskWindowEnd = 365)

    population <-  PatientLevelPrediction::createStudyPopulation(plpData = plpData,
                                                                 outcomeId = 7746,
                                                                 populationSettings = populationSettings
                                                                 )

    # apply the model:
    plpModel <- list(model = getModel(),
                     analysisId = 'Bipolar',
                     hyperParamSearch = NULL,
                     index = NULL,
                     trainCVAuc = NULL,
                     modelSettings = list(model = 'score', modelParameters = NULL),
                     metaData = NULL,
                     populationSettings = NULL,
                     trainingTime = NULL,
                     varImp = NULL,
                     dense = T,
                     targetId = 12292,
                     outcomeId = 7746,
                     covariateMap = NULL
    )

    class(plpModel) <- "plpModel"
    attr(plpModel, "predictionFunction") <- "predictBipolar"
    attr(plpModel, "saveType") <- "RtoJson"

    plpModel <- augmentManualPlpModel(plpModel)

    result <- list()

    # Predict
    result$model <- plpModel
    result$prediction <- PatientLevelPrediction::predictPlp(
      plpModel = plpModel,
      plpData = plpData,
      population = population
    )

    # Set metadata (keep evaluationColumn as 'value')
    attr(result$prediction, "metaData") <- list(
      modelType = "binary",
      predictionType = "binary",
      evaluationColumn = "value"
    )


    # fix for error
    result$prediction <- result$prediction[
      !is.na(result$prediction$outcomeCount) &
      !is.na(result$prediction$value),
    ]
    # print("keeping evaluable patient only\n")

    # Convert score to probability
    result$prediction$value <- 1 / (1 + exp(-result$prediction$value))

    # Add preferenceScore if missing
    result$prediction$preferenceScore <- result$prediction$value


    # Ensure evaluation column exists
    evalColumn <- attr(result$prediction, "metaData")$evaluationColumn
    if (!evalColumn %in% colnames(result$prediction)) {
      result$prediction[[evalColumn]] <- result$prediction$value
    }

    # Add expected 'evaluationType' column
    result$prediction$evaluationType <- "Test"

    # print(table(result$prediction$outcomeCount))
    # print(summary(result$prediction$daysToEvent))


    # Evaluate
    result$performanceEvaluation <- PatientLevelPrediction::evaluatePlp(
      prediction = result$prediction,
      typeColumn = "evaluationType"
    )

    
    result$inputSetting$database <- databaseName


    # do the predicted risk to surivial spline
    require('survival')

    populationSettings <- createStudyPopulationSettings(removeSubjectsWithPriorOutcome = T,
                                                                requireTimeAtRisk = T, minTimeAtRisk = 364,
                                                                riskWindowStart = 1,
                                                                riskWindowEnd = 10*365)

    pop10 <- PatientLevelPrediction::createStudyPopulation(plpData = plpData,
                                                                outcomeId = 7746,
                                                                populationSettings = populationSettings
                                                                )
    ParallelLogger::logInfo("pop10 created")

    pop10 <- merge(result$prediction[, !colnames(result$prediction)%in%c('survivalTime','outcomeCount')],
          pop10[, colnames(pop10)%in%c('rowId','survivalTime','outcomeCount')],
          by = 'rowId', all.x=T)

    mfit <- survival::coxph(survival::Surv(survivalTime, outcomeCount) ~ survival::pspline(value, df=4),
                  data=pop10)


    ptemp <- stats::termplot(mfit, se=TRUE, plot=FALSE)
    riskterm <- ptemp$value # this will be a data frame
    #center <- with(riskterm, y[x==0])
    center <- riskterm$y[which.min(abs(riskterm$x-0))]
    ytemp <- riskterm$y + outer(riskterm$se, c(0, -1.96, 1.96), '*')
    sdata <- data.frame(x=riskterm$x, y= exp(ytemp - center))


    splinePlot <- ggplot2::ggplot(sdata ,  ggplot2::aes(x, y.1))+
      ggplot2::geom_line(data=sdata)+
      ggplot2::geom_ribbon(data=sdata, ggplot2::aes(ymin=y.2,ymax=y.3),alpha=0.3) +
      ggplot2::xlab("Risk Score") + ggplot2::ylab("Relative outcome rate") +
      ggplot2::scale_x_continuous(breaks = c(-1:6)*5) +
      ggplot2::coord_cartesian(ylim = c(0, max(ceiling(sdata$y.1))*1.2))


    result$spline <- list(mfit=mfit,
                          splinePlot = splinePlot)

    # get stats for each score - check potential privacy issues?
    scoreThres <- as.data.frame(getScoreSummaries(result$prediction))
    result$scoreThreshold <- scoreThres
  

    # get survival plots
    survInfo <- getSurvivalInfo(plpData = plpData, prediction = result$prediction)
    result$survInfo <- survInfo

    # get AUC per index year
    result$yauc <- getAUCbyYear(result)


    if(!dir.exists(file.path(outputFolder,databaseName))){
      dir.create(file.path(outputFolder,databaseName))
    }
    saveRDS(result, file.path(outputFolder,databaseName,'validationResults.rds'))

  }

  # package the results: this creates a compressed file with sensitive details removed - ready to be reviewed and then
  # submitted to the network study manager

  # results saved to outputFolder/databaseName
  # str(result)
  # class(result$model)
  # is.null(result$model)
  # inherits(result$model, "plpModel")


  if (packageResults) {
    ParallelLogger::logInfo("Packaging results")
    packageResults(outputFolder = file.path(outputFolder,databaseName),
                   minCellCount = minCellCount)
  }


  invisible(NULL)

}
