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
cdmDatabaseSchema <- "your_cdm_schema"           # Schema containing OMOP CDM data
workDatabaseSchema <- "your_work_schema"         # Schema for temporary tables (must have write access)
resultsDatabaseSchema <- "your_results_schema"   # Schema for storing results

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
executionSettings <- Strategus::createCdmExecutionSettings(
  workDatabaseSchema = workDatabaseSchema,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortTableNames = CohortGenerator::getCohortTableNames(cohortTable = "nlp_psychiatry_cohort"),
  workFolder = file.path(outputFolder, "strategusWork"),
  resultsFolder = file.path(outputFolder, "strategusOutput"),
  minCellCount = minCellCount,
  maxCores = maxCores
)

# Execute the study
ParallelLogger::logInfo("Executing Strategus study...")
Strategus::execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  connectionDetails = connectionDetails
)

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
