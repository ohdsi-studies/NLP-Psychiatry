# ******************************************************************************
# BipolarMisclassificationModule - Module Loader
# ******************************************************************************
#
# This script loads the BipolarMisclassificationModule and its dependencies
# for use in the Strategus framework.
#
# ******************************************************************************

# Load required libraries
if (!requireNamespace("R6", quietly = TRUE)) {
  stop("R6 package is required but not installed")
}

if (!requireNamespace("ParallelLogger", quietly = TRUE)) {
  stop("ParallelLogger package is required but not installed")
}

library(R6)
library(ParallelLogger)

# Find module files using multiple strategies
findModuleFile <- function(filename) {
  possible_paths <- c(
    # If we're in the module R directory
    filename,
    # If we're in the module root
    file.path("R", filename),
    # If we're in project root
    file.path("modules", "BipolarMisclassificationModule", "R", filename),
    # If we're in a subdirectory
    file.path("..", "modules", "BipolarMisclassificationModule", "R", filename),
    file.path("..", "..", "modules", "BipolarMisclassificationModule", "R", filename)
  )

  for (path in possible_paths) {
    if (file.exists(path)) {
      return(normalizePath(path))
    }
  }

  stop(paste("Could not find", filename, "in any of the expected locations"))
}

# Source the helper functions first
helpers_file <- findModuleFile("ModuleHelpers.R")
source(helpers_file)
ParallelLogger::logInfo(paste("Loaded helper functions from:", helpers_file))

# Source the main module class
module_file <- findModuleFile("BipolarMisclassificationModule.R")
source(module_file)
ParallelLogger::logInfo(paste("Loaded module class from:", module_file))

# Function to create and validate a module instance
createBipolarMisclassificationModule <- function() {
  tryCatch({
    module <- BipolarMisclassificationModule$new()
    ParallelLogger::logInfo("BipolarMisclassificationModule instance created successfully")
    return(module)
  }, error = function(e) {
    ParallelLogger::logError(paste("Failed to create BipolarMisclassificationModule:", e$message))
    stop(e)
  })
}

# Function to test module specifications creation
testModuleSpecifications <- function() {
  ParallelLogger::logInfo("Testing BipolarMisclassificationModule specifications creation...")
  
  module <- createBipolarMisclassificationModule()
  
  # Test with default parameters
  specs <- module$createModuleSpecifications()
  
  # Validate the specifications
  if (is.null(specs) || !is.list(specs)) {
    stop("Module specifications creation failed")
  }
  
  if (is.null(specs$module) || specs$module != "BipolarMisclassificationModule") {
    stop("Invalid module name in specifications")
  }
  
  if (is.null(specs$settings)) {
    stop("Missing settings in module specifications")
  }
  
  ParallelLogger::logInfo("Module specifications test passed")
  return(specs)
}

# Export functions to global environment
.GlobalEnv$createBipolarMisclassificationModule <- createBipolarMisclassificationModule
.GlobalEnv$testModuleSpecifications <- testModuleSpecifications

ParallelLogger::logInfo("BipolarMisclassificationModule loader completed successfully")
