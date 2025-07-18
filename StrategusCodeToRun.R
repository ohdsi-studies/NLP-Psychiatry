# ******************************************************************************
# NLP-Psychiatry Multi-Component Study - Strategus Execution Script
# ******************************************************************************
#
# This script executes the NLP-Psychiatry study using the OHDSI Strategus framework.
# The study includes multiple psychiatric prediction components, starting with
# bipolar misclassification validation.
#
# Requirements:
# - R 4.2.0 or higher
# - OHDSI Strategus package
# - Access to OMOP CDM database
# - Appropriate database drivers
#
# ******************************************************************************

# Load required libraries
library(Strategus)
library(DatabaseConnector)
library(ParallelLogger)

# Load custom modules required for this study
ParallelLogger::logInfo("Loading custom study modules...")
source("modules/BipolarMisclassificationModule/R/LoadModule.R")

# Download and configure JDBC drivers for PostgreSQL
tryCatch({
  DatabaseConnector::downloadJdbcDrivers("postgresql")
  ParallelLogger::logInfo("PostgreSQL JDBC driver downloaded successfully")
}, error = function(e) {
  ParallelLogger::logWarn(paste("Could not download PostgreSQL JDBC driver:", e$message))
  ParallelLogger::logWarn("Proceeding with existing drivers...")
})

# ******************************************************************************
# CONFIGURATION SECTION - MODIFY THESE SETTINGS FOR YOUR ENVIRONMENT
# ******************************************************************************

# Database connection details
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "your_dbms",                    # e.g., "postgresql", "sql server", "oracle"
  server = "your_server",                # Your database server
  user = "your_username",                # Your database username
  password = "your_password",            # Your database password
  port = "your_port"                     # Your database port
)

# Database schema settings
# IMPORTANT: workDatabaseSchema and resultsDatabaseSchema must exist or your user must have CREATE SCHEMA permissions
# For PostgreSQL, create manually: CREATE SCHEMA IF NOT EXISTS your_work_schema;
cdmDatabaseSchema <- "your_cdm_schema"           # Schema containing OMOP CDM data (read-only)
workDatabaseSchema <- "your_work_schema"         # Schema for temporary tables (must have write access)
resultsDatabaseSchema <- "your_results_schema"   # Schema for storing results (must have write access)

# PostgreSQL case sensitivity fix: ensure schema names are lowercase
# PostgreSQL stores unquoted identifiers in lowercase
if (connectionDetails$dbms == "postgresql") {
  workDatabaseSchema <- tolower(workDatabaseSchema)
  resultsDatabaseSchema <- tolower(resultsDatabaseSchema)
  cdmDatabaseSchema <- tolower(cdmDatabaseSchema)
  ParallelLogger::logInfo(paste("PostgreSQL detected - using lowercase schema names"))
  ParallelLogger::logInfo(paste("Work schema:", workDatabaseSchema))
  ParallelLogger::logInfo(paste("CDM schema:", cdmDatabaseSchema))
}

# Study execution settings
outputFolder <- "./StrategusOutput"              # Local folder for study results
databaseId <- "YourDatabase"                     # Unique identifier for your database
databaseName <- "Your Database Name"             # Descriptive name for your database
databaseDescription <- "Description of your database"

# Execution options
maxCores <- parallel::detectCores()              # Number of CPU cores to use
minCellCount <- 5                               # Minimum cell count for results

# ******************************************************************************
# STUDY EXECUTION
# ******************************************************************************

# Create output directory if it doesn't exist
if (!dir.exists(outputFolder)) {
  dir.create(outputFolder, recursive = TRUE)
}

# Set up logging
logFileName <- file.path(outputFolder, paste0("strategus-log-", Sys.Date(), ".txt"))
logger <- ParallelLogger::createLogger(
  name = "STRATEGUS",
  threshold = "INFO",
  appenders = list(
    ParallelLogger::createFileAppender(
      layout = ParallelLogger::layoutTimestamp,
      fileName = logFileName
    ),
    ParallelLogger::createConsoleAppender(
      layout = ParallelLogger::layoutTimestamp
    )
  )
)
ParallelLogger::registerLogger(logger)

ParallelLogger::logInfo("Starting NLP-Psychiatry Strategus Study")
ParallelLogger::logInfo(paste("Database ID:", databaseId))
ParallelLogger::logInfo(paste("Output folder:", outputFolder))

# Load the analysis specification
analysisSpecificationsFileName <- "AnalysisSpecification.json"
if (!file.exists(analysisSpecificationsFileName)) {
  stop("Analysis specification file not found: ", analysisSpecificationsFileName)
}

analysisSpecifications <- ParallelLogger::loadSettingsFromJson(analysisSpecificationsFileName)
ParallelLogger::logInfo("Loaded analysis specification")

# Create execution settings
cohort_table_names_for_execution <- CohortGenerator::getCohortTableNames(cohortTable = "cohort")

# Create execution settings
ParallelLogger::logInfo("Creating execution settings...")

executionSettings <- Strategus::createCdmExecutionSettings(
  workDatabaseSchema = workDatabaseSchema,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortTableNames = cohort_table_names_for_execution,
  workFolder = file.path(outputFolder, "strategusWork"),
  resultsFolder = file.path(outputFolder, "strategusOutput"),
  minCellCount = minCellCount,
  maxCores = maxCores
)

# Check if cohort tables exist before creating them
ParallelLogger::logInfo("Checking cohort tables...")
tryCatch({
  connection <- DatabaseConnector::connect(connectionDetails)

  # Check if main cohort table exists
  tables_exist <- DatabaseConnector::existsTable(
    connection = connection,
    databaseSchema = workDatabaseSchema,
    tableName = "cohort"
  )

  DatabaseConnector::disconnect(connection)

  if (!tables_exist) {
    ParallelLogger::logInfo("Creating cohort tables...")
    # Create all required cohort tables using CohortGenerator
    cohort_table_names <- CohortGenerator::getCohortTableNames(
      cohortTable = "cohort"
    )

    CohortGenerator::createCohortTables(
      connectionDetails = connectionDetails,
      cohortDatabaseSchema = workDatabaseSchema,
      cohortTableNames = cohort_table_names
    )
    ParallelLogger::logInfo("Cohort tables created")
  } else {
    ParallelLogger::logInfo("Cohort tables already exist - preserving existing data")
  }

}, error = function(e) {
  ParallelLogger::logWarn(paste("Could not check/create cohort tables:",
                                e$message))
  ParallelLogger::logWarn("Proceeding - CohortGenerator will create tables as needed")
})

# Execute the study with enhanced error handling
ParallelLogger::logInfo("Executing Strategus study...")

tryCatch({
  # Test database connection first
  ParallelLogger::logInfo("Testing database connection...")
  connection <- DatabaseConnector::connect(connectionDetails)

  # Create schemas if they don't exist (PostgreSQL)
  ParallelLogger::logInfo("Ensuring required schemas exist...")
  if (connectionDetails$dbms == "postgresql") {
    tryCatch({
      DatabaseConnector::executeSql(connection, paste0("CREATE SCHEMA IF NOT EXISTS ", workDatabaseSchema, ";"))
      ParallelLogger::logInfo(paste("Work schema ensured:", workDatabaseSchema))

      if (workDatabaseSchema != resultsDatabaseSchema) {
        DatabaseConnector::executeSql(connection, paste0("CREATE SCHEMA IF NOT EXISTS ", resultsDatabaseSchema, ";"))
        ParallelLogger::logInfo(paste("Results schema ensured:", resultsDatabaseSchema))
      }
    }, error = function(e) {
      ParallelLogger::logWarn(paste("Could not create schemas automatically:", e$message))
      ParallelLogger::logWarn("You may need to create schemas manually or check permissions")
    })
  }

  DatabaseConnector::disconnect(connection)
  ParallelLogger::logInfo("Database connection test successful")

  # Execute the study
  result <- Strategus::execute(
    analysisSpecifications = analysisSpecifications,
    executionSettings = executionSettings,
    connectionDetails = connectionDetails
  )

  ParallelLogger::logInfo("Strategus execution completed successfully")

}, error = function(e) {
  # Safely handle error messages that might contain quotes or special characters
  error_message <- tryCatch({
    as.character(e$message)
  }, error = function(err) {
    "Error message could not be retrieved"
  })

  ParallelLogger::logError(paste("Strategus execution failed:", error_message))
  ParallelLogger::logError("Full error details:")

  # Safely capture traceback
  traceback_info <- tryCatch({
    paste(capture.output(traceback()), collapse = "\n")
  }, error = function(err) {
    "Traceback could not be captured"
  })

  ParallelLogger::logError(traceback_info)

  # Provide specific guidance for common errors
  if (grepl("JDBC", error_message, ignore.case = TRUE)) {
    ParallelLogger::logError("JDBC driver issue detected. Try:")
    ParallelLogger::logError("1. DatabaseConnector::downloadJdbcDrivers('postgresql')")
    ParallelLogger::logError("2. Check database connection parameters")
  }

  if (grepl("metadata", error_message, ignore.case = TRUE)) {
    ParallelLogger::logError("CDM metadata collection failed. Check:")
    ParallelLogger::logError("1. Database connection permissions")
    ParallelLogger::logError("2. CDM schema access")
    ParallelLogger::logError("3. OMOP CDM version compatibility")
  }

  stop(e)
})

ParallelLogger::logInfo("Study execution completed")

# ******************************************************************************
# RESULTS PROCESSING
# ******************************************************************************

# The results will be available in the strategusOutput folder
resultsFolder <- file.path(outputFolder, "strategusOutput")
ParallelLogger::logInfo(paste("Results available in:", resultsFolder))

# Optional: Create a summary of results
if (dir.exists(resultsFolder)) {
  resultFiles <- list.files(resultsFolder, recursive = TRUE, pattern = "\\.csv$")
  ParallelLogger::logInfo(paste("Generated", length(resultFiles), "result files"))
  
  # Log the result files for review
  for (file in resultFiles) {
    ParallelLogger::logInfo(paste("Result file:", file))
  }
}

ParallelLogger::logInfo("NLP-Psychiatry Strategus Study completed successfully")

# Clean up
ParallelLogger::unregisterLogger(logger)

# ******************************************************************************
# NEXT STEPS
# ******************************************************************************
#
# 1. Review the results in the strategusOutput folder
# 2. Check the log file for any warnings or errors
# 3. Package results for sharing (if participating in network study)
# 4. Use the results viewer application to explore findings
#
# For questions or support:
# - OHDSI Forums: https://forums.ohdsi.org/
# - Study lead: Christophe Lambert (cglambert@unm.edu)
#
# ******************************************************************************
