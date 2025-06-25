# ******************************************************************************
# NLP-Psychiatry Study - Analysis Specification Creation
# ******************************************************************************
#
# This script creates the Strategus analysis specification for the NLP-Psychiatry
# multi-component study. The specification defines all modules, cohorts, and
# analysis settings for coordinated execution across multiple databases.
#
# ******************************************************************************

library(Strategus)
library(CohortGenerator)
library(ParallelLogger)

# ******************************************************************************
# STUDY CONFIGURATION
# ******************************************************************************

# Output settings
outputFolder <- "./AnalysisSpecification"
analysisSpecificationFileName <- "AnalysisSpecification.json"

# Create output directory
if (!dir.exists(outputFolder)) {
  dir.create(outputFolder, recursive = TRUE)
}

# Set up logging
ParallelLogger::addDefaultFileLogger(file.path(outputFolder, "createAnalysisSpec.log"))
ParallelLogger::logInfo("Creating NLP-Psychiatry Analysis Specification")

# ******************************************************************************
# COHORT DEFINITIONS
# ******************************************************************************

# Load cohort definitions from the migrated BipolarMisclassificationValidation
cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(
  settingsFileName = "modules/BipolarMisclassificationModule/inst/settings/CohortsToCreate.csv",
  jsonFolder = "modules/BipolarMisclassificationModule/inst/cohorts",
  sqlFolder = "modules/BipolarMisclassificationModule/inst/sql/sql_server",
  packageName = NULL  # Using local files instead of package
)

ParallelLogger::logInfo(paste("Loaded", nrow(cohortDefinitionSet), "cohort definitions"))

# ******************************************************************************
# MODULE SPECIFICATIONS
# ******************************************************************************

# Initialize empty analysis specification
analysisSpecifications <- Strategus::createEmptyAnalysisSpecificiations()

# ============================================================================
# COHORT GENERATOR MODULE
# ============================================================================
ParallelLogger::logInfo("Setting up CohortGenerator module")

cgModule <- CohortGeneratorModule$new()

# Create cohort shared resource specifications
cohortDefinitionSharedResource <- cgModule$createCohortSharedResourceSpecifications(
  cohortDefinitionSet = cohortDefinitionSet
)

# Create cohort generator module specifications
cohortGeneratorModuleSpecifications <- cgModule$createModuleSpecifications(
  generateStats = TRUE
)

# Add to analysis specification
analysisSpecifications <- analysisSpecifications %>%
  Strategus::addSharedResources(cohortDefinitionSharedResource) %>%
  Strategus::addModuleSpecifications(cohortGeneratorModuleSpecifications)

# ============================================================================
# BIPOLAR MISCLASSIFICATION MODULE
# ============================================================================
ParallelLogger::logInfo("Setting up BipolarMisclassification module")

# Load the custom BipolarMisclassificationModule
source("modules/BipolarMisclassificationModule/R/LoadModule.R")

# Create module instance
bipolarModule <- createBipolarMisclassificationModule()

# Create module specifications
bipolarModuleSpecifications <- bipolarModule$createModuleSpecifications(
  targetCohortId = 12292,  # PLP_tutorial_2018_first_MDD_aged_10_or_older
  outcomeCohortId = 7746,  # Bipolar disorder diagnosis
  generateStats = TRUE,
  runValidation = TRUE,
  minCellCount = 5,
  restrictToAdults = FALSE
)

# Add to analysis specification
analysisSpecifications <- analysisSpecifications %>%
  Strategus::addModuleSpecifications(bipolarModuleSpecifications)

# ============================================================================
# COHORT DIAGNOSTICS MODULE (Optional)
# ============================================================================
ParallelLogger::logInfo("Setting up CohortDiagnostics module")

cdModule <- CohortDiagnosticsModule$new()
cohortDiagnosticsModuleSpecifications <- cdModule$createModuleSpecifications(
  runInclusionStatistics = TRUE,
  runIncludedSourceConcepts = TRUE,
  runOrphanConcepts = TRUE,
  runTimeSeries = FALSE,
  runVisitContext = TRUE,
  runBreakdownIndexEvents = TRUE,
  runIncidenceRate = TRUE,
  runCohortRelationship = TRUE,
  runTemporalCohortCharacterization = TRUE
)

# Add to analysis specification
analysisSpecifications <- analysisSpecifications %>%
  Strategus::addModuleSpecifications(cohortDiagnosticsModuleSpecifications)

# ******************************************************************************
# SAVE ANALYSIS SPECIFICATION
# ******************************************************************************

# Save the analysis specification to JSON
outputFile <- file.path(outputFolder, analysisSpecificationFileName)
ParallelLogger::saveSettingsToJson(analysisSpecifications, outputFile)

# Also save to the root directory for easy access
rootOutputFile <- analysisSpecificationFileName
ParallelLogger::saveSettingsToJson(analysisSpecifications, rootOutputFile)

ParallelLogger::logInfo(paste("Analysis specification saved to:", outputFile))
ParallelLogger::logInfo(paste("Analysis specification also saved to:", rootOutputFile))

# ******************************************************************************
# VALIDATION AND SUMMARY
# ******************************************************************************

# Validate the analysis specification
tryCatch({
  # Basic validation - check if it can be loaded back
  loadedSpec <- ParallelLogger::loadSettingsFromJson(outputFile)
  ParallelLogger::logInfo("Analysis specification validation: PASSED")
  
  # Print summary
  ParallelLogger::logInfo("=== ANALYSIS SPECIFICATION SUMMARY ===")
  
  if (!is.null(loadedSpec$sharedResources)) {
    ParallelLogger::logInfo(paste("Shared resources:", length(loadedSpec$sharedResources)))
  }
  
  if (!is.null(loadedSpec$moduleSpecifications)) {
    ParallelLogger::logInfo(paste("Module specifications:", length(loadedSpec$moduleSpecifications)))
    
    for (i in seq_along(loadedSpec$moduleSpecifications)) {
      module <- loadedSpec$moduleSpecifications[[i]]
      if (!is.null(module$module)) {
        ParallelLogger::logInfo(paste("  Module", i, ":", module$module))
      }
    }
  }
  
}, error = function(e) {
  ParallelLogger::logError(paste("Analysis specification validation FAILED:", e$message))
  stop("Invalid analysis specification created")
})

ParallelLogger::logInfo("Analysis specification creation completed successfully")

# ******************************************************************************
# USAGE INSTRUCTIONS
# ******************************************************************************

cat("\n")
cat("=================================================================\n")
cat("ANALYSIS SPECIFICATION CREATED SUCCESSFULLY\n")
cat("=================================================================\n")
cat("\n")
cat("Next steps:\n")
cat("1. Review the analysis specification file:", rootOutputFile, "\n")
cat("2. Modify StrategusCodeToRun.R with your database connection details\n")
cat("3. Execute the study using: source('StrategusCodeToRun.R')\n")
cat("\n")
cat("The analysis specification includes:\n")
cat("- Cohort generation for all study cohorts\n")
cat("- Bipolar misclassification validation module\n")
cat("- Cohort diagnostics for quality assessment\n")
cat("\n")
cat("For questions or support:\n")
cat("- Study lead: Christophe Lambert (cglambert@unm.edu)\n")
cat("- OHDSI Forums: https://forums.ohdsi.org/\n")
cat("=================================================================\n")
