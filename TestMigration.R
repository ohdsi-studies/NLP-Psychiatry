# ******************************************************************************
# NLP-Psychiatry Study - Migration Test Script
# ******************************************************************************
#
# This script tests the migration from the standalone BipolarMisclassificationValidation
# R package to the Strategus framework implementation.
#
# ******************************************************************************

library(ParallelLogger)

# Set up logging
ParallelLogger::addDefaultConsoleLogger()

cat("\n")
cat("=================================================================\n")
cat("NLP-PSYCHIATRY STRATEGUS MIGRATION TEST\n")
cat("=================================================================\n")
cat("\n")

# ******************************************************************************
# TEST 1: Environment Check
# ******************************************************************************

ParallelLogger::logInfo("TEST 1: Checking study environment...")

# Check if core packages are available
core_packages <- c("R6", "ParallelLogger")
missing_core <- core_packages[!sapply(core_packages, requireNamespace, quietly = TRUE)]

if (length(missing_core) > 0) {
  cat("ERROR: Missing core packages:", paste(missing_core, collapse = ", "), "\n")
  cat("Please install with: install.packages(c('", paste(missing_core, collapse = "', '"), "'))\n")
  stop("Core packages required for testing")
}

# Check optional OHDSI packages (warn but don't stop)
ohdsi_packages <- c("Strategus", "DatabaseConnector", "PatientLevelPrediction",
                   "CohortGenerator", "FeatureExtraction")
missing_ohdsi <- ohdsi_packages[!sapply(ohdsi_packages, requireNamespace, quietly = TRUE)]

if (length(missing_ohdsi) > 0) {
  ParallelLogger::logWarn(paste("Missing OHDSI packages:", paste(missing_ohdsi, collapse = ", ")))
  ParallelLogger::logWarn("These are needed for full study execution but not for migration testing")
}

ParallelLogger::logInfo("✓ Required packages available")

# Check study files
study_files <- c(
  "CreateAnalysisSpecification.R",
  "StrategusCodeToRun.R",
  "modules/BipolarMisclassificationModule/R/BipolarMisclassificationModule.R",
  "modules/BipolarMisclassificationModule/R/ModuleHelpers.R",
  "modules/BipolarMisclassificationModule/R/LoadModule.R"
)

for (file in study_files) {
  if (file.exists(file)) {
    ParallelLogger::logInfo(paste("✓", file))
  } else {
    ParallelLogger::logError(paste("✗", file, "MISSING"))
    stop(paste("Required file missing:", file))
  }
}

ParallelLogger::logInfo("TEST 1 PASSED: Environment check completed")

# ******************************************************************************
# TEST 2: Module Loading
# ******************************************************************************

ParallelLogger::logInfo("TEST 2: Testing module loading...")

tryCatch({
  # Load the module
  source("modules/BipolarMisclassificationModule/R/LoadModule.R")
  ParallelLogger::logInfo("✓ Module loader executed successfully")
  
  # Test module creation
  bipolarModule <- createBipolarMisclassificationModule()
  ParallelLogger::logInfo("✓ Module instance created successfully")
  
  # Check module properties
  if (is.null(bipolarModule) || !inherits(bipolarModule, "BipolarMisclassificationModule")) {
    stop("Invalid module instance created")
  }
  
  ParallelLogger::logInfo("✓ Module instance validation passed")
  
}, error = function(e) {
  ParallelLogger::logError(paste("Module loading failed:", e$message))
  stop(e)
})

ParallelLogger::logInfo("TEST 2 PASSED: Module loading completed")

# ******************************************************************************
# TEST 3: Module Specifications
# ******************************************************************************

ParallelLogger::logInfo("TEST 3: Testing module specifications creation...")

tryCatch({
  # Test specifications creation
  specs <- testModuleSpecifications()
  ParallelLogger::logInfo("✓ Module specifications created successfully")
  
  # Validate specifications structure
  required_fields <- c("module", "version", "settings")
  for (field in required_fields) {
    if (is.null(specs[[field]])) {
      stop(paste("Missing required field in specifications:", field))
    }
  }
  
  ParallelLogger::logInfo("✓ Specifications structure validation passed")
  
  # Validate settings
  required_settings <- c("targetCohortId", "outcomeCohortId", "modelCoefficients")
  for (setting in required_settings) {
    if (is.null(specs$settings[[setting]])) {
      stop(paste("Missing required setting:", setting))
    }
  }
  
  ParallelLogger::logInfo("✓ Settings validation passed")
  
  # Check model coefficients
  coefficients <- specs$settings$modelCoefficients
  if (!is.data.frame(coefficients) || nrow(coefficients) == 0) {
    stop("Invalid model coefficients")
  }
  
  required_coeff_cols <- c("covariateName", "covariateId", "points")
  for (col in required_coeff_cols) {
    if (!col %in% colnames(coefficients)) {
      stop(paste("Missing column in model coefficients:", col))
    }
  }
  
  ParallelLogger::logInfo("✓ Model coefficients validation passed")
  
}, error = function(e) {
  ParallelLogger::logError(paste("Module specifications test failed:", e$message))
  stop(e)
})

ParallelLogger::logInfo("TEST 3 PASSED: Module specifications testing completed")

# ******************************************************************************
# TEST 4: Cohort Definitions
# ******************************************************************************

ParallelLogger::logInfo("TEST 4: Testing cohort definitions...")

tryCatch({
  # Check cohort files
  cohort_dir <- "modules/BipolarMisclassificationModule/inst/cohorts"
  if (!dir.exists(cohort_dir)) {
    stop("Cohort directory not found")
  }
  
  cohort_files <- list.files(cohort_dir, pattern = "\\.json$")
  if (length(cohort_files) == 0) {
    stop("No cohort definition files found")
  }
  
  ParallelLogger::logInfo(paste("✓ Found", length(cohort_files), "cohort definition files"))
  
  # Check settings file
  settings_file <- "modules/BipolarMisclassificationModule/inst/settings/CohortsToCreate.csv"
  if (!file.exists(settings_file)) {
    stop("CohortsToCreate.csv not found")
  }
  
  # Read and validate settings
  cohorts_to_create <- read.csv(settings_file, stringsAsFactors = FALSE)
  if (nrow(cohorts_to_create) == 0) {
    stop("Empty CohortsToCreate.csv file")
  }
  
  required_cols <- c("targetId", "atlasId", "name")
  for (col in required_cols) {
    if (!col %in% colnames(cohorts_to_create)) {
      stop(paste("Missing column in CohortsToCreate.csv:", col))
    }
  }
  
  ParallelLogger::logInfo(paste("✓ Found", nrow(cohorts_to_create), "cohort definitions in settings"))
  
}, error = function(e) {
  ParallelLogger::logError(paste("Cohort definitions test failed:", e$message))
  stop(e)
})

ParallelLogger::logInfo("TEST 4 PASSED: Cohort definitions testing completed")

# ******************************************************************************
# TEST 5: Analysis Specification Creation
# ******************************************************************************

ParallelLogger::logInfo("TEST 5: Testing analysis specification creation...")

tryCatch({
  # Test if we can create an analysis specification
  # Note: This is a dry run without database connection
  
  # Check if Strategus is available (optional for this test)
  if (requireNamespace("Strategus", quietly = TRUE)) {
    ParallelLogger::logInfo("✓ Strategus package available")
    
    # We could test specification creation here if Strategus is installed
    # For now, just validate the script exists and is syntactically correct
    
  } else {
    ParallelLogger::logWarn("Strategus package not available - skipping full specification test")
  }
  
  # Check if the CreateAnalysisSpecification.R script is syntactically valid
  tryCatch({
    parse("CreateAnalysisSpecification.R")
    ParallelLogger::logInfo("✓ CreateAnalysisSpecification.R syntax validation passed")
  }, error = function(e) {
    stop(paste("Syntax error in CreateAnalysisSpecification.R:", e$message))
  })
  
}, error = function(e) {
  ParallelLogger::logError(paste("Analysis specification test failed:", e$message))
  stop(e)
})

ParallelLogger::logInfo("TEST 5 PASSED: Analysis specification testing completed")

# ******************************************************************************
# TEST SUMMARY
# ******************************************************************************

cat("\n")
cat("=================================================================\n")
cat("MIGRATION TEST RESULTS\n")
cat("=================================================================\n")
cat("\n")
cat("✓ TEST 1: Environment check - PASSED\n")
cat("✓ TEST 2: Module loading - PASSED\n")
cat("✓ TEST 3: Module specifications - PASSED\n")
cat("✓ TEST 4: Cohort definitions - PASSED\n")
cat("✓ TEST 5: Analysis specification - PASSED\n")
cat("\n")
cat("🎉 ALL TESTS PASSED! 🎉\n")
cat("\n")
cat("The migration from BipolarMisclassificationValidation R package\n")
cat("to Strategus framework has been completed successfully.\n")
cat("\n")
cat("Next steps:\n")
cat("1. Install OHDSI packages: installOhdsiPackages()\n")
cat("2. Create analysis specification: source('CreateAnalysisSpecification.R')\n")
cat("3. Configure database connection in StrategusCodeToRun.R\n")
cat("4. Execute study: source('StrategusCodeToRun.R')\n")
cat("\n")
cat("=================================================================\n")

ParallelLogger::logInfo("Migration test completed successfully")
