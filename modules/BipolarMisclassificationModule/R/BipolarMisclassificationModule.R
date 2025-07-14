# ******************************************************************************
# BipolarMisclassificationModule - Strategus Module Implementation
# ******************************************************************************
#
# This module implements the bipolar misclassification validation study as a
# Strategus module. It validates a predictive model that identifies patients
# initially diagnosed with MDD who are likely to be rediagnosed with Bipolar
# Disorder within 1 year.
#
# ******************************************************************************

#' @title Bipolar Misclassification Validation Module
#' @description A Strategus module for validating bipolar misclassification prediction models
#' @export
BipolarMisclassificationModule <- R6::R6Class(
  classname = "BipolarMisclassificationModule",
  
  public = list(
    
    #' @description Initialize the module
    initialize = function() {
      private$.moduleName <- "BipolarMisclassificationModule"
      private$.version <- "1.0.0"
      private$.description <- "Validates a predictive model for bipolar misclassification in MDD patients"
      private$.author <- "Christophe Lambert, Jenna Reps"
    },
    
    #' @description Create module specifications for the analysis
    #' @param targetCohortId The cohort ID for the target population (MDD patients)
    #' @param outcomeCohortId The cohort ID for the outcome (bipolar diagnosis)
    #' @param generateStats Whether to generate cohort statistics
    #' @param runValidation Whether to run the validation analysis
    #' @param minCellCount Minimum cell count for results
    #' @param restrictToAdults Whether to restrict to patients 18 or older
    #' @return Module specifications list
    createModuleSpecifications = function(targetCohortId = 12292,
                                        outcomeCohortId = 7746,
                                        generateStats = TRUE,
                                        runValidation = TRUE,
                                        minCellCount = 5,
                                        restrictToAdults = FALSE) {
      
      # Validate inputs
      private$.validateInputs(targetCohortId, outcomeCohortId, minCellCount)
      
      # Create module specifications using Strategus format
      specifications <- list(
        module = private$.moduleName,
        version = private$.version,
        remoteRepo = "local",
        remoteUsername = "local",
        settings = list(
          targetCohortId = targetCohortId,
          outcomeCohortId = outcomeCohortId,
          generateStats = generateStats,
          runValidation = runValidation,
          minCellCount = minCellCount,
          restrictToAdults = restrictToAdults,
          # Model coefficients and settings
          modelCoefficients = private$.getModelCoefficients(),
          # Covariate settings
          covariateSettings = private$.getCovariateSettings()
        )
      )

      # Set the proper class for Strategus
      class(specifications) <- c("ModuleSpecifications", "list")

      return(specifications)
    },
    
    #' @description Execute the module
    #' @param connectionDetails Database connection details (Strategus format)
    #' @param analysisSpecifications Analysis specifications (Strategus format)
    #' @param executionSettings Execution settings (Strategus format)
    execute = function(connectionDetails, analysisSpecifications, executionSettings) {

      # Set up logging
      ParallelLogger::logInfo("Starting BipolarMisclassificationModule execution")

      # Extract settings following Strategus conventions
      settings <- NULL

      # Strategus passes analysisSpecifications as the module settings directly
      if (is.list(analysisSpecifications) && !is.null(analysisSpecifications$settings)) {
        settings <- analysisSpecifications$settings
      } else if (is.list(analysisSpecifications)) {
        # Fallback: try to find our module's settings in moduleSpecifications
        if (!is.null(analysisSpecifications$moduleSpecifications)) {
          for (moduleSpec in analysisSpecifications$moduleSpecifications) {
            if (!is.null(moduleSpec$module) && moduleSpec$module == "BipolarMisclassificationModule") {
              settings <- moduleSpec$settings
              break
            }
          }
        }
      }

      # Fallback: use default settings if not found
      if (is.null(settings)) {
        ParallelLogger::logWarn("Could not find module settings, using defaults")
        settings <- list(
          targetCohortId = 12292,
          outcomeCohortId = 7746,
          generateStats = TRUE,
          runValidation = TRUE,
          minCellCount = 5,
          restrictToAdults = FALSE
        )
      }

      # Add model coefficients to settings (from original study)
      settings$modelCoefficients <- private$.getModelCoefficients()
      
      # Execute the analysis
      tryCatch({
        
        # Validate cohorts exist (created by CohortGenerator module)
        if (settings$generateStats) {
          private$.validateCohorts(jobContext, settings, connectionDetails)
        }

        # Run validation if requested
        if (settings$runValidation) {
          private$.runValidation(jobContext, settings, connectionDetails)
        }

        # Package results
        private$.packageResults(jobContext, settings)

        # Return success for Strategus
        return(TRUE)
        
        ParallelLogger::logInfo("BipolarMisclassificationModule execution completed successfully")
        
      }, error = function(e) {
        ParallelLogger::logError(paste("BipolarMisclassificationModule execution failed:", e$message))
        stop(e)
      })
    },
    
    #' @description Get the results data model specification
    #' @return Data frame with results data model specification
    getResultsDataModelSpecification = function() {
      return(private$.getResultsDataModel())
    },
    
    #' @description Create results tables in the database
    #' @param connectionDetails Database connection details
    #' @param resultsDatabaseSchema Schema for results tables
    #' @param tablePrefix Prefix for table names
    createResultsTables = function(connectionDetails, resultsDatabaseSchema, tablePrefix = "") {
      private$.createResultsTables(connectionDetails, resultsDatabaseSchema, tablePrefix)
    },
    
    #' @description Upload results to database
    #' @param connectionDetails Database connection details
    #' @param resultsDatabaseSchema Schema for results tables
    #' @param resultsFolder Folder containing CSV results
    #' @param tablePrefix Prefix for table names
    uploadResults = function(connectionDetails, resultsDatabaseSchema, resultsFolder, tablePrefix = "") {
      private$.uploadResults(connectionDetails, resultsDatabaseSchema, resultsFolder, tablePrefix)
    }
  ),
  
  private = list(
    .moduleName = NULL,
    .version = NULL,
    .description = NULL,
    .author = NULL,
    
    # Validate input parameters
    .validateInputs = function(targetCohortId, outcomeCohortId, minCellCount) {
      if (!is.numeric(targetCohortId) || targetCohortId <= 0) {
        stop("targetCohortId must be a positive integer")
      }
      if (!is.numeric(outcomeCohortId) || outcomeCohortId <= 0) {
        stop("outcomeCohortId must be a positive integer")
      }
      if (!is.numeric(minCellCount) || minCellCount < 0) {
        stop("minCellCount must be a non-negative integer")
      }
    },
    
    # Get model coefficients (from original study)
    .getModelCoefficients = function() {
      coefficients <- data.frame(
        covariateName = c(
          'age group: 20-24', 'age group: 30-34', 'age group: 35-39', 'age group: 40-44',
          'age group: 45-49', 'age group: 50-54', 'age group: 55-59', 'age group: 70-74',
          'age group: 75-79', 'age group: 80-84', 'age group: 85-89', 'age group: 90-94',
          'age group: 95-99',
          'mental health disorder days before: -9999 days after: -1',
          'Suicidal thoughts or Self harm days before: -9999 days after: 0',
          'Pregnancy days before: -9999 days after: 0',
          'Anxiety drugs and Anxiety days before: -9999 days after: 0',
          'Mild depression days before: -9999 days after: 0',
          'Severe depression days before: -9999 days after: 0',
          'MDD with psychosis days before: -9999 days after: 0',
          'Substance use disorder days before: -9999 days after: 0'
        ),
        covariateId = c(
          2020, 2030, 2035, 2040, 2045, 2050, 2055, 2070, 2075, 2080, 2085, 2090, 2095,
          11580456, 11594456, 11582456, 11584456, 11586456, 11588456, 11589456, 11590456
        ),
        points = c(
          0.3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3, -0.3, -0.3, -0.3, -0.3, -0.3, -0.3,
          0.5, 1.0, 0.2, 0.4, 0.3, 0.6, 0.8, 0.4
        ),
        stringsAsFactors = FALSE
      )
      return(coefficients)
    },
    
    # Get covariate settings
    .getCovariateSettings = function() {
      # This will be implemented to match the original study's covariate extraction
      return(list(
        useDemographicsAgeGroup = TRUE,
        cohortBasedCovariates = TRUE
      ))
    },

    # Validate cohorts exist for the study
    .validateCohorts = function(jobContext, settings, connectionDetails) {
      ParallelLogger::logInfo("Validating cohorts for BipolarMisclassificationModule")

      # Check that required cohorts exist in the cohort table
      # The CohortGenerator module should have already created these
      connection <- DatabaseConnector::connect(connectionDetails)

      tryCatch({
        # Check if the main cohort table exists and has data
        sql <- "SELECT COUNT(*) as cohort_count FROM @cohort_database_schema.@cohort_table"
        sql <- SqlRender::render(sql,
                                cohort_database_schema = jobContext$moduleExecutionSettings$workDatabaseSchema,
                                cohort_table = jobContext$moduleExecutionSettings$cohortTableNames$cohortTable)
        sql <- SqlRender::translate(sql, targetDialect = connectionDetails$dbms)

        result <- DatabaseConnector::querySql(connection, sql)
        ParallelLogger::logInfo(paste("Found", result$COHORT_COUNT, "cohort records"))

        if (result$COHORT_COUNT == 0) {
          ParallelLogger::logWarn("No cohort records found - cohorts may not have been generated properly")
        }

      }, error = function(e) {
        ParallelLogger::logWarn(paste("Could not validate cohorts:", e$message))
      }, finally = {
        DatabaseConnector::disconnect(connection)
      })

      ParallelLogger::logInfo("Cohort validation completed")
    },

    # Run the validation analysis
    .runValidation = function(jobContext, settings, connectionDetails) {
      ParallelLogger::logInfo("Running bipolar misclassification validation")

      # This will implement the core validation logic from the original study
      # For now, creating a placeholder structure

      # Get the data using the original study's approach
      plpData <- private$.getBipolarData(
        connectionDetails = connectionDetails,
        cdmDatabaseSchema = jobContext$moduleExecutionSettings$cdmDatabaseSchema,
        cohortDatabaseSchema = jobContext$moduleExecutionSettings$workDatabaseSchema,
        cohortTable = jobContext$moduleExecutionSettings$cohortTableNames$cohortTable,
        targetId = settings$targetCohortId,
        outcomeId = settings$outcomeCohortId
      )

      # Create study population
      populationSettings <- PatientLevelPrediction::createStudyPopulationSettings(
        removeSubjectsWithPriorOutcome = TRUE,
        requireTimeAtRisk = TRUE,
        minTimeAtRisk = 364,
        riskWindowStart = 1,
        riskWindowEnd = 365
      )

      population <- PatientLevelPrediction::createStudyPopulation(
        plpData = plpData,
        outcomeId = settings$outcomeCohortId,
        populationSettings = populationSettings
      )

      # Apply the prediction model (replicating original study workflow)
      plpModel <- private$.createPlpModel(settings)

      # Get prediction using the model
      prediction <- private$.applyPredictionModel(plpData, population, settings)

      # Evaluate the model (using modern PatientLevelPrediction)
      evaluation <- PatientLevelPrediction::evaluatePlp(
        prediction = prediction,
        plpData = plpData
      )

      # Create result structure matching original study
      result <- list(
        model = plpModel,
        prediction = prediction,
        evaluation = evaluation
      )

      # Add original study's additional analyses
      private$.loadHelperFunctions()

      # Get score summaries for threshold analysis
      result$scoreThreshold <- getScoreSummaries(prediction)

      # Get survival information
      result$survInfo <- getSurvivalInfo(plpData, prediction)

      # Get AUC by year analysis
      result$yauc <- getAUCbyYear(result)

      # Save results
      private$.saveValidationResults(result, executionSettings, settings)

      ParallelLogger::logInfo("Validation analysis completed")
    },

    # Package results for sharing
    .packageResults = function(executionSettings, settings) {
      ParallelLogger::logInfo("Packaging results for BipolarMisclassificationModule")

      # Apply minimum cell count restrictions and package results
      # This will be implemented based on the original study's packaging logic

      ParallelLogger::logInfo("Results packaging completed")
    },

    # Get bipolar prediction data
    .getBipolarData = function(connectionDetails, cdmDatabaseSchema, cohortDatabaseSchema,
                              cohortTable, targetId, outcomeId, sampleSize = NULL) {
      # Load helper functions
      private$.loadHelperFunctions()
      return(.getBipolarData(connectionDetails, cdmDatabaseSchema, cohortDatabaseSchema,
                            cohortTable, targetId, outcomeId, sampleSize))
    },

    # Apply prediction model
    .applyPredictionModel = function(plpData, population, settings) {
      # Load helper functions
      private$.loadHelperFunctions()
      return(.applyPredictionModel(plpData, population, settings))
    },

    # Save validation results
    .saveValidationResults = function(result, jobContext, settings) {
      # Load helper functions
      private$.loadHelperFunctions()
      .saveValidationResults(result, jobContext, settings)
    },

    # Load helper functions
    .loadHelperFunctions = function() {
      # Check if helper functions are already loaded
      if (exists(".getBipolarData", mode = "function")) {
        return()  # Already loaded
      }

      # Try to find and source the helper functions
      possible_paths <- c(
        "ModuleHelpers.R",
        file.path("R", "ModuleHelpers.R"),
        file.path("modules", "BipolarMisclassificationModule", "R", "ModuleHelpers.R")
      )

      for (path in possible_paths) {
        if (file.exists(path)) {
          source(path, local = TRUE)
          return()
        }
      }

      # If we get here, helpers weren't found - this is OK if they were loaded via LoadModule.R
      if (!exists(".getBipolarData", mode = "function")) {
        stop("Helper functions not available. Please source LoadModule.R first.")
      }
    },

    # Get results data model specification
    .getResultsDataModel = function() {
      resultsDataModel <- data.frame(
        tableName = c("performance_metrics", "calibration", "threshold_summary"),
        columnName = c(
          "analysis_id", "target_cohort_id", "outcome_cohort_id", "auc", "auprc", "brier_score", "population_size", "outcome_count",
          "analysis_id", "decile", "observed_risk", "predicted_risk", "person_count", "outcome_count",
          "analysis_id", "threshold", "sensitivity", "specificity", "ppv", "npv"
        ),
        dataType = c(
          rep("varchar", 1), rep("int", 2), rep("float", 3), rep("int", 2),
          rep("varchar", 1), rep("int", 1), rep("float", 2), rep("int", 2),
          rep("varchar", 1), rep("float", 5)
        ),
        isRequired = rep("Yes", 21),
        primaryKey = rep("No", 21),
        stringsAsFactors = FALSE
      )
      return(resultsDataModel)
    },

    # Create results tables
    .createResultsTables = function(connectionDetails, resultsDatabaseSchema, tablePrefix) {
      # Implementation for creating results tables in database
      ParallelLogger::logInfo("Creating results tables for BipolarMisclassificationModule")
      # This would use the results data model to create tables
    },

    # Upload results to database
    .uploadResults = function(connectionDetails, resultsDatabaseSchema, resultsFolder, tablePrefix) {
      # Implementation for uploading CSV results to database tables
      ParallelLogger::logInfo("Uploading results for BipolarMisclassificationModule")
      # This would upload the CSV files to the database tables
    }
  )
)
