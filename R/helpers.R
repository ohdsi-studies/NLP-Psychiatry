# Copyright 2018 Observational Health Data Sciences and Informatics
#
# This file is part of bipolarValidation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#' Create the exposure and outcome cohorts
#'
#' @details
#' This function will create the exposure and outcome cohorts following the definitions included in
#' this package.
#'
#' @param connectionDetails    An object of type \code{connectionDetails} as created using the
#'                             \code{\link[DatabaseConnector]{createConnectionDetails}} function in the
#'                             DatabaseConnector package.
#' @param cdmDatabaseSchema    Schema name where your patient-level data in OMOP CDM format resides.
#'                             Note that for SQL Server, this should include both the database and
#'                             schema name, for example 'cdm_data.dbo'.
#' @param cohortDatabaseSchema Schema name where intermediate data can be stored. You will need to have
#'                             write priviliges in this schema. Note that for SQL Server, this should
#'                             include both the database and schema name, for example 'cdm_data.dbo'.
#' @param cohortTable          The name of the table that will be created in the work database schema.
#'                             This table will hold the exposure and outcome cohorts used in this
#'                             study.
#' @param tempEmulationSchema     Should be used in Oracle to specify a schema where the user has write
#'                             priviliges for storing temporary tables.
#' @param outputFolder         Name of local folder to place results; make sure to use forward slashes
#'                             (/)
#' @param restrictToAdults     Restrict the target cohort to patients 18 or older
#'
#' @export
createCohorts <- function(connectionDetails,
                          cdmDatabaseSchema,
                          cohortDatabaseSchema,
                          cohortTable = "cohort",
                          tempEmulationSchema,
                          outputFolder,
                          restrictToAdults) {
  if (!file.exists(outputFolder))
    dir.create(outputFolder)

  conn <- DatabaseConnector::connect(connectionDetails)

  .createCohorts(connection = conn,
                 cdmDatabaseSchema = cdmDatabaseSchema,
                 cohortDatabaseSchema = cohortDatabaseSchema,
                 cohortTable = cohortTable,
                 tempEmulationSchema = tempEmulationSchema,
                 outputFolder = outputFolder,
                 restrictToAdults = restrictToAdults)

  # Check number of subjects per cohort:
  # ParallelLogger::logInfo("Counting cohorts")
  sql <- SqlRender::loadRenderTranslateSql("GetCounts.sql",
                                           "BipolarMisclassificationValidation",
                                           dbms = connectionDetails$dbms,
                                           tempEmulationSchema = tempEmulationSchema,
                                           cdm_database_schema = cdmDatabaseSchema,
                                           work_database_schema = cohortDatabaseSchema,
                                           study_cohort_table = cohortTable)
  counts <- DatabaseConnector::querySql(conn, sql)
  colnames(counts) <- SqlRender::snakeCaseToCamelCase(colnames(counts))
  counts <- addCohortNames(counts)
  utils::write.csv(counts, file.path(outputFolder, "CohortCounts.csv"), row.names = FALSE)

  DatabaseConnector::disconnect(conn)
}

addCohortNames <- function(data, IdColumnName = "cohortDefinitionId", nameColumnName = "cohortName") {
  pathToCsv <- system.file("settings", "CohortsToCreate.csv", package = "BipolarMisclassificationValidation")
  cohortsToCreate <- utils::read.csv(pathToCsv)

  idToName <- data.frame(targetId = c(cohortsToCreate$targetId),
                         cohortName = c(as.character(cohortsToCreate$name)))
  idToName <- idToName[order(idToName$targetId), ]
  idToName <- idToName[!duplicated(idToName$targetId), ]
  names(idToName)[1] <- IdColumnName
  names(idToName)[2] <- nameColumnName
  data <- merge(data, idToName, all.x = TRUE)
  # Change order of columns:
  idCol <- which(colnames(data) == IdColumnName)
  if (idCol < ncol(data) - 1) {
    data <- data[, c(1:idCol, ncol(data) , (idCol+1):(ncol(data)-1))]
  }
  return(data)
}
# Print the package path and file to confirm
# cat("1Looking for file in: ", system.file("sql/sql_server", package = "BipolarMisclassificationValidation"), "\n")

# List contents of the folder R is actually using
list.files(system.file("sql/sql_server", package = "BipolarMisclassificationValidation"))

.createCohorts <- function(connection,
                           cdmDatabaseSchema,
                           vocabularyDatabaseSchema = cdmDatabaseSchema,
                           cohortDatabaseSchema,
                           cohortTable,
                           tempEmulationSchema,
                           outputFolder,
                           restrictToAdults) {
  # Print the package path and file to confirm
  # cat("2Looking for file in: ", system.file("sql/sql_server", package = "BipolarMisclassificationValidation"), "\n")
  
  # List contents of the folder R is actually using
  list.files(system.file("sql/sql_server", package = "BipolarMisclassificationValidation"))
  
  # Create study cohort table structure:
  sql <- SqlRender::loadRenderTranslateSql(sqlFilename = "CreateCohortTable.sql",
                                           packageName = "BipolarMisclassificationValidation",
                                           dbms = attr(connection, "dbms"),
                                           tempEmulationSchema = tempEmulationSchema,
                                           cohort_database_schema = cohortDatabaseSchema,
                                           cohort_table = cohortTable)
  DatabaseConnector::executeSql(connection, sql, progressBar = FALSE, reportOverallTime = FALSE)



  # Instantiate cohorts:
  pathToCsv <- system.file("settings", "CohortsToCreate.csv", package = "BipolarMisclassificationValidation")
  cohortsToCreate <- utils::read.csv(pathToCsv)
  for (i in 1:nrow(cohortsToCreate)) {

    if(cohortsToCreate$name[i]=='PLP_tutorial_2018_first_MDD_aged_10_or_older' &
       restrictToAdults){
      sqlname <- 'PLP_tutorial_2018_first_MDD_aged_18_or_older'
    } else{
      sqlname <- cohortsToCreate$name[i]
    }

    writeLines(paste("Creating cohort:", sqlname))
    sql <- SqlRender::loadRenderTranslateSql(sqlFilename = paste0(sqlname, ".sql"),
                                             packageName = "BipolarMisclassificationValidation",
                                             dbms = attr(connection, "dbms"),
                                             tempEmulationSchema = tempEmulationSchema,
                                             cdm_database_schema = cdmDatabaseSchema,
                                             vocabulary_database_schema = vocabularyDatabaseSchema,

                                             target_database_schema = cohortDatabaseSchema,
                                             target_cohort_table = cohortTable,
                                             target_cohort_id = cohortsToCreate$targetId[i])
    DatabaseConnector::executeSql(connection, sql)
  }
}


#' Creates the target population and outcome summary characteristics
#'
#' @details
#' This will create the patient characteristic table
#'
#' @param connectionDetails The connections details for connecting to the CDM
#' @param cdmDatabaseSchema  The schema holding the CDM data
#' @param cohortDatabaseSchema The schema holding the cohort table
#' @param cohortTable         The name of the cohort table
#' @param targetId          The cohort definition id of the target population
#' @param outcomeId         The cohort definition id of the outcome
#' @param tempCohortTable   The name of the temporary table used to hold the cohort
#'
#' @return
#' A dataframe with the characteristics
#'
#' @export
getTable1 <- function(connectionDetails,
                      cdmDatabaseSchema,
                      cohortDatabaseSchema,
                      cohortTable,
                      targetId,
                      outcomeId,
                      tempCohortTable='#temp_cohort'){

  covariateSettings <- FeatureExtraction::createCovariateSettings(useDemographicsGender = T)

  
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
  restrictPlpDataSettings <- PatientLevelPrediction::createRestrictPlpDataSettings()
  
  plpData <- PatientLevelPrediction::getPlpData(
    databaseDetails = databaseDetails,
    covariateSettings = covariateSettings,
    restrictPlpDataSettings = restrictPlpDataSettings
  )
  #plpData <- PatientLevelPrediction::getPlpData(connectionDetails,
   #                                             cdmDatabaseSchema = cdmDatabaseSchema,
    #                                            cohortId = targetId, outcomeIds = outcomeId,
     #                                           cohortDatabaseSchema = cohortDatabaseSchema,
      #                                          outcomeDatabaseSchema = cohortDatabaseSchema,
       #                                         cohortTable = cohortTable,
        #                                        outcomeTable = cohortTable,
         #                                       covariateSettings=covariateSettings)

  population <- PaftientLevelPrediction::createStudyPopulation(plpData = plpData,
                                                              outcomeId = outcomeId,
                                                              binary = T,
                                                              includeAllOutcomes = T,
                                                              requireTimeAtRisk = T,
                                                              minTimeAtRisk = 364,
                                                              riskWindowStart = 1,
                                                              riskWindowEnd = 365,
                                                              removeSubjectsWithPriorOutcome = T)

  table1 <- PatientLevelPrediction::getPlpTable(cdmDatabaseSchema = cdmDatabaseSchema,
                                                longTermStartDays = -9999,
                                                population=population,
                                                connectionDetails=connectionDetails,
                                                cohortTable=tempCohortTable)

  return(table1)
}

#==========================
#  Example of implementing an exisitng model in the PredictionComparison repository
#==========================

#' Checks the plp package is installed sufficiently for the network study and does other checks if needed
#'
#' @details
#' This will check that the network study dependancies work
#'
#' @param connectionDetails The connections details for connecting to the CDM
#'
#' @return
#' A number (a value other than 1 means an issue with the install)
#'
#' @export

checkInstall <- function(connectionDetails=NULL){
  result <- PatientLevelPrediction::checkPlpInstallation(connectionDetails=connectionDetails,
                                 python=F)
  return(result)
}


#' Transport trained PLP models into the validation package
#'
#' @details
#' This will tranport PLP models into a validation package
#'
#' @param analysesDir  The directory containing folders with PLP models
#' @param minCellCount  The min cell count when trasporting the PLP model evaluation results
#' @param databaseName  The name of the database as a string
#' @param outputDir  the location to save the transported models (defaults to inst/plp_models)
#'
#' @return
#' The models will now be in the package
#'
#' @export
transportPlpModels <- function(analysesDir,
                               minCellCount = 5,
                               databaseName = 'sharable name of development data',
                               outputDir
){
  if(missing(outputDir)){
    outputDir <- 'inst/plp_models'
  }

  files <- dir(analysesDir, recursive = F, full.names = F)
  files <- files[grep('Analysis_', files)]
  filesIn <- file.path(analysesDir, files , 'plpResult')
  filesOut <- file.path(outputDir, files, 'plpResult')

  for(i in 1:length(filesIn)){
    plpResult <- PatientLevelPrediction::loadPlpResult(filesIn[i])
    PatientLevelPrediction::transportPlp(plpResult,
                 modelName= files[i], dataName=databaseName,
                 outputFolder = filesOut[i],
                 n=minCellCount,
                 includeEvaluationStatistics=T,
                 includeThresholdSummary=T, includeDemographicSummary=T,
                 includeCalibrationSummary =T, includePredictionDistribution=T,
                 includeCovariateSummary=T, save=T)

  }
}


getModel <- function(){
  coefficients <- data.frame(covariateName =c('age group: 20-24', 'age group: 30-34',
                                              'age group: 35-39', 'age group: 40-44',
                                              'age group: 45-49', 'age group: 50-54',
                                              'age group: 55-59', 'age group: 70-74',
                                              'age group: 75-79', 'age group: 80-84',
                                              'age group: 85-89', 'age group: 90-94',
                                              'age group: 95-99',
                                              'mental health disorder days before: -9999 days after: -1',
                                              'Suicidal thoughts or Self harm days before: -9999 days after: 0',
                                              'Pregnancy days before: -9999 days after: 0',
                                              'Anxiety drugs and Anxiety days before: -9999 days after: 0',
                                              'Mild depression days before: -9999 days after: 0',
                                              'Severe depression days before: -9999 days after: 0',
                                              'MDD with pyschosis days before: -9999 days after: 0',
                                              'Substance use disorder days before: -9999 days after: 0',
                                              'age group: 10-14',
                                              'age group: 15-19',
                                              'age group: 25-29'),
                             covariateId = c(4003,6003,7003,8003,9003,10003,11003,
                                             14003,15003,16003,17003,18003,19003,
                                             11580456,11594456,11582456,11584456,
                                             11586456,11588456,11589456,11590456,
                                             2003,3003,5003),
                             points = c(12,10,9,8,7,5,3,
                                        -3,-5,-5,-5,-5,-5,
                                        2,9,-3,1,
                                        -5,5,10,5,
                                        11,12,12))

  return(coefficients)
}


# get custom data:
getBipolarData <- function(connectionDetails,
                           cdmDatabaseSchema,
                           cohortDatabaseSchema,
                           cohortTable,
                           targetId,
                           outcomeDatabaseSchema,
                           outcomeTable,
                           outcomeId,
                           tempEmulationSchema = NULL,
                           sampleSize = NULL){
  # cat("inside\n")
  cohorts <- data.frame(names = c('mental health disorder','Suicidal thoughts or Self harm',
                                  'Pregnancy',
                                  'Anxiety drugs and Anxiety', 'Mild depression',
                                  'Severe depression', 'MDD with pyschosis',
                                  'Substance use disorder'),

  ids =	c(11580,11594,11582,11584,11586,11588,11589,11590),
  endDays = c(-1, rep(0,7)))


  cohortCov <- list()
  length(cohortCov) <- nrow(cohorts)+1
  cohortCov[[1]] <- FeatureExtraction::createCovariateSettings(useDemographicsAgeGroup = TRUE)

  # cat("feature extracted\n")

  for(i in 1:nrow(cohorts)){
    cohortCov[[1+i]] <- createCohortCovariateSettingsCustom(covariateName = as.character(cohorts$names[i]),
                                                      covariateId = cohorts$ids[i]*1000+456,
                                                      cohortDatabaseSchema = cohortDatabaseSchema,
                                                      cohortTable = cohortTable,
                                                      targetId = cohorts$ids[i],
                                                      startDay=-9999, endDay=cohorts$endDays[i],
                                                      count = FALSE,
                                                      analysisId = 456
                                                    )
  }

  # for (i in 1:nrow(cohorts)) {
  # cohortCov[[1 + i]] <- FeatureExtraction::createCovariateSettings(
  #   # covariateName = as.character(cohorts$names[i]),
  #   includedCovariateConceptIds = cohorts$ids[i], 
  #   longTermStartDays = -9999,  
  #   includedCovariateIds = cohorts$ids[i] * 1000 + 456,
  #   endDay = cohorts$endDays[i],
  #   # analsisId = 456,
  #   # isBinary = TRUE
  #   )
  # }

  # cat("cohort cov created\n")
  # str(cohortCov)
  # print(cohortCov)

  databaseDetails <- PatientLevelPrediction::createDatabaseDetails(
    connectionDetails = connectionDetails,
    cdmDatabaseSchema = cdmDatabaseSchema,
    cohortDatabaseSchema = cohortDatabaseSchema,
    cohortTable = cohortTable,
    outcomeDatabaseSchema = outcomeDatabaseSchema,
    outcomeTable = outcomeTable,
    targetId = targetId,
    outcomeIds = outcomeId
  )
  # cat("db details created\n")
  restrictPlpDataSettings <- PatientLevelPrediction::createRestrictPlpDataSettings(sampleSize = sampleSize)
  # cat("restrict\n")
  plpData <- PatientLevelPrediction::getPlpData(
    databaseDetails = databaseDetails,
    covariateSettings = cohortCov,
    restrictPlpDataSettings = restrictPlpDataSettings
  )

  # cat("get plp data done\n")
  # plpData <- PatientLevelPrediction::getPlpData(connectionDetails = connectionDetails,
  #                                              cdmDatabaseSchema = cdmDatabaseSchema,
   #                                             cohortId = cohortId,
    #                                            outcomeIds = outcomeId,
     #                                           cohortDatabaseSchema = cohortDatabaseSchema,
      #                                          cohortTable = cohortTable,
       #                                         outcomeDatabaseSchema = outcomeDatabaseSchema,
        #                                        outcomeTable = outcomeTable,
         #                                       covariateSettings = cohortCov,
          #                                      tempEmulationSchema = tempEmulationSchema,
           #                                     sampleSize = sampleSize)

  return(plpData)


}

predictBipolar <- function(plpModel, data, cohort) {
  # Map the arguments
  plpData <- data
  population <- cohort
  coefficients <- getModel()

  if('covariateData'%in%names(plpData)){
    plpData$covariateData$coefficients <- tibble::as_tibble(coefficients)
    on.exit(plpData$covariateData$coefficients <- NULL)

    prediction <- plpData$covariateData$covariates %>%
      dplyr::inner_join(plpData$covariateData$coefficients, by = "covariateId") %>%
      dplyr::mutate(value = covariateValue*points) %>%
      dplyr::select(rowId, value) %>%
      dplyr::group_by(rowId) %>%
      dplyr::summarise(value = sum(value, na.rm = TRUE)) %>% dplyr::collect()


  } else{

  prediction <- merge(plpData$covariates, ff::as.ffdf(coefficients), by = "covariateId")
  prediction$value <- prediction$covariateValue * prediction$points
  prediction <- PatientLevelPrediction:::bySumFf(prediction$value, prediction$rowId)
  colnames(prediction) <- c("rowId", "value")
  }

  prediction <- merge(population, prediction, by ="rowId", all.x = TRUE)
  prediction$value[is.na(prediction$value)] <- 0

  attr(prediction, "metaData") <- list(predictionType = 'binary', modelType = 'binary', evaluationColumn = "value")

return(prediction)
}



createCohortCovariateSettingsCustom <- function(covariateName, covariateId,
                                          cohortDatabaseSchema, cohortTable, targetId,
                                          startDay=-30, endDay=0, count=T, analysisId) {
  covariateSettings <- list(covariateName=covariateName, covariateId=covariateId,
                            cohortDatabaseSchema=cohortDatabaseSchema,
                            cohortTable=cohortTable,
                            targetId=targetId,
                            startDay=startDay,
                            endDay=endDay,
                            count=count,
                            analysisId = analysisId)

  attr(covariateSettings, "fun") <- "getCohortCovariateData"
  class(covariateSettings) <- "covariateSettings"
  return(covariateSettings)
}

#' Extracts covariates based on cohorts
#'
#' @details
#' The user specifies a cohort and time period and then a covariate is constructed whether they are in the
#' cohort during the time periods relative to target population cohort index
#'
#' @param connection  The database connection
#' @param tempEmulationSchema  The temp schema if using oracle
#' @param cdmDatabaseSchema  The schema of the OMOP CDM data
#' @param cdmVersion  version of the OMOP CDM data
#' @param cohortTable  the table name that contains the target population cohort
#' @param rowIdField  string representing the unique identifier in the target population cohort
#' @param aggregated  whether the covariate should be aggregated
#' @param cohortId  cohort id for the target population cohort
#' @param targetId  cohort id for the target population cohort

#' @param covariateSettings  settings for the covariate cohorts and time periods
#'
#' @return
#' The models will now be in the package
#'
#' @export
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
  # ParallelLogger::logInfo("inside")

  # Some SQL to construct the covariate:
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
  # ParallelLogger::logInfo("sql constructed")

  sql <- SqlRender::render(sql,
                           covariate_cohort_schema = covariateSettings$cohortDatabaseSchema,
                           covariate_cohort_table = covariateSettings$cohortTable,
                           covariate_cohort_id = covariateSettings$targetId,
                           cohort_temp_table = cohortTable,
                           row_id_field = rowIdField,
                           startDay=covariateSettings$startDay,
                           covariate_id = covariateSettings$covariateId,
                           endDay=covariateSettings$endDay,
                           countval = covariateSettings$count)
  # ParallelLogger::logInfo("sql rendered")
  sql <- SqlRender::translate(sql, targetDialect = attr(connection, "dbms"), tempEmulationSchema = tempEmulationSchema)
  # ParallelLogger::logInfo("sql translated")
  # Retrieve the covariate:
  covariates <- DatabaseConnector::querySql(connection, sql)
  # ParallelLogger::logInfo("db connected")
  # Convert colum names to camelCase:
  colnames(covariates) <- SqlRender::snakeCaseToCamelCase(colnames(covariates))
  # ParallelLogger::logInfo("snakecase")
  # Construct covariate reference:
  sql <- "select @covariate_id as covariate_id, '@concept_set' as covariate_name,
  456 as analysis_id, -1 as concept_id"
  # ParallelLogger::logInfo("sql constructed2")
  sql <- SqlRender::render(sql, covariate_id = covariateSettings$covariateId,
                           concept_set=paste(ifelse(covariateSettings$count, 'Number of', ''),
                                             covariateSettings$covariateName,
                                             ifelse(covariateSettings$ageInteraction, ' X Age', ''),
                                             ' days before:', covariateSettings$startDay, 'days after:', covariateSettings$endDay)

  )
  # ParallelLogger::logInfo("sql rendered2")
  sql <- SqlRender::translate(sql, targetDialect = attr(connection, "dbms"),
                              tempEmulationSchema = tempEmulationSchema)

  # ParallelLogger::logInfo("sql translated2")
  # Retrieve the covariateRef:
  covariateRef  <- DatabaseConnector::querySql(connection, sql)
  # ParallelLogger::logInfo("db")
  colnames(covariateRef) <- SqlRender::snakeCaseToCamelCase(colnames(covariateRef))

  analysisRef <- data.frame(analysisId = 4,
                            analysisName = "cohort covariate",
                            domainId = "cohort covariate",
                            startDay = 0,
                            endDay = 0,
                            isBinary = "Y",
                            missingMeansZero = "Y")
  # ParallelLogger::logInfo("analysis ref")
  metaData <- list(sql = sql, call = match.call())
  result <- Andromeda::andromeda(covariates = covariates,
                                 covariateRef = covariateRef,
                                 analysisRef = analysisRef)
  # ParallelLogger::logInfo("result")
  attr(result, "metaData") <- metaData
  # ParallelLogger::logInfo("attr")
  class(result) <- "CovariateData"
  # ParallelLogger::logInfo("class assigned")
  return(result)
}


getScoreSummaries <- function(prediction){
  getInfo <- function(thres, pred){
    TP = sum(pred$outcomeCount[pred$value>=thres])
    P = sum(pred$outcomeCount>0)
    pN = sum(pred$value>=thres)
    N <- length(pred$value)
    thresN <- sum(pred$value==thres)
    thresO <- sum(pred$outcomeCount[pred$value==thres])
    return(c(thres = thres, N= thresN, O = thresO , popN = pN/N,sensitivity = TP/P, PPV = TP/pN))
  }
  res <- do.call(rbind, lapply(unique(prediction$value), function(x) getInfo(x, prediction)))
  return(res)
}


getSurvivalInfo <- function(plpData, prediction){

  populationSettings <- createStudyPopulationSettings(removeSubjectsWithPriorOutcome = T,
                                                              requireTimeAtRisk = T, minTimeAtRisk = 364,
                                                              riskWindowStart = 1,
                                                              riskWindowEnd = 10*365)


  population <- PatientLevelPrediction::createStudyPopulation(plpData = plpData,
                                                              outcomeId = 7746,
                                                              populationSettings = populationSettings
                                                              )

  data <- merge(population, prediction[, c('rowId','value')], by='rowId')
  data$daysToEvent[is.na(data$daysToEvent)] <- data$survivalTime[is.na(data$daysToEvent)]

  getSurv <- function(dayL, dayU, data){
    return(c(dayL = dayL,
             dayU=dayU,
             remainingDayL = sum(data$daysToEvent>=dayL),
             lost = sum(data$outcomeCount[data$daysToEvent <dayU & data$daysToEvent >= dayL]==0),
             outcome = sum(data$outcomeCount[data$daysToEvent <dayU & data$daysToEvent >= dayL])))
  }

  #100 time points - loss to follow-up and outcome counts?
  dates <- cbind(seq(0,3650, 30), c(seq(30,3650, 30), 3650))
  allSurv <- c()
  for(val in unique(data$value)){
    dataTemp <- data[data$value == val, ]
    survival <- as.data.frame(t(apply(dates,1, function(x) getSurv(x[1], x[2], dataTemp))))
    survival$score = val

    allSurv <- rbind(allSurv, survival)
  }
  return(allSurv)
}


aucPerYear <- function(prediction, year){
  temp <- prediction[prediction$year==year,]

  # print(paste("Year:", year, "Unique outcome counts:", unique(temp$outcomeCount)))
  
  if (length(unique(temp$outcomeCount)) < 2) {
    warning(paste("Year", year, "has only one level in 'truth'. Skipping AUC calculation."))
    return(NA)
  }

  auc <- PatientLevelPrediction::computeAuc(temp)
  return(auc)
}

getAUCbyYear <- function(plpResult){
  
  res <- plpResult
  str(res$prediction)
  attr(res$prediction, "metaData")$modelType <- attr(res$prediction, "metaData")$predictionType

  res$prediction$year <- format(as.Date(res$prediction$cohortStartDate, format="%Y-%m-%d"),"%Y")

  # aucs <- lapply(unique(res$prediction$year), function(x) aucPerYear(prediction = res$prediction, year = x ))
  aucs <- lapply(unique(res$prediction$year), function(x) {
    if (sum(res$prediction$outcomeCount[res$prediction$year == x]) == 0) {
      print(paste(year, unique(res$prediction[prediction$year==year,]$outcomeCount)))
      return(NA)  # Assign NA for years with no events
    }
    aucPerYear(prediction = res$prediction, year = x)
  })

  size <- lapply(unique(res$prediction$year), function(x) nrow(res$prediction[res$prediction$year== x, ]))

  result <- data.frame(year= unique(res$prediction$year),
                       auc = unlist(aucs),
                       N= unlist(size))
  result <- result[order(result$year),]
  return(result)
}
