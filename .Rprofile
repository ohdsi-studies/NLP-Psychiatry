# ******************************************************************************
# NLP-Psychiatry Study - R Profile Configuration
# ******************************************************************************
#
# This .Rprofile file sets up the R environment for the NLP-Psychiatry study
# using the OHDSI Strategus framework.
#
# ******************************************************************************

# Activate renv for dependency management
if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
}

# Set CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Configure Java for OHDSI packages
options(java.parameters = "-Xmx8g")

# Set default options for better performance
options(
  # Increase memory limits
  expressions = 500000,
  
  # Set number of digits for output
  digits = 10,
  
  # Configure parallel processing
  mc.cores = parallel::detectCores(),
  
  # Set timeout for downloads
  timeout = 300
)

# Load commonly used libraries on startup
.First <- function() {
  cat("\n")
  cat("=================================================================\n")
  cat("NLP-PSYCHIATRY MULTI-COMPONENT STUDY\n")
  cat("=================================================================\n")
  cat("Using OHDSI Strategus Framework\n")
  cat("\n")
  cat("Study Components:\n")
  cat("- Bipolar Misclassification Validation\n")
  cat("- [Future psychiatric prediction modules]\n")
  cat("\n")
  cat("Quick Start:\n")
  cat("1. Create analysis specification: source('CreateAnalysisSpecification.R')\n")
  cat("2. Execute study: source('StrategusCodeToRun.R')\n")
  cat("\n")
  cat("For help: ?Strategus or visit https://ohdsi.github.io/Strategus/\n")
  cat("=================================================================\n")
  cat("\n")
  
  # Check if required packages are available
  core_packages <- c("R6", "ParallelLogger")
  optional_packages <- c("Strategus", "DatabaseConnector", "PatientLevelPrediction",
                        "CohortGenerator", "CohortDiagnostics", "FeatureExtraction")

  missing_core <- core_packages[!sapply(core_packages, requireNamespace, quietly = TRUE)]
  missing_optional <- optional_packages[!sapply(optional_packages, requireNamespace, quietly = TRUE)]

  if (length(missing_core) > 0) {
    cat("ERROR: Missing core packages:", paste(missing_core, collapse = ", "), "\n")
    cat("Please install core packages: install.packages(c('", paste(missing_core, collapse = "', '"), "'))\n")
    cat("\n")
  }

  if (length(missing_optional) > 0) {
    cat("WARNING: Missing OHDSI packages:", paste(missing_optional, collapse = ", "), "\n")
    cat("Install with: installOhdsiPackages()\n")
    cat("\n")
  }
}

# Function to check study environment
checkStudyEnvironment <- function() {
  cat("Checking NLP-Psychiatry Study Environment...\n")
  
  # Check R version
  r_version <- R.version.string
  cat("R Version:", r_version, "\n")
  
  # Check required packages
  required_packages <- c("Strategus", "DatabaseConnector", "PatientLevelPrediction", 
                        "CohortGenerator", "CohortDiagnostics", "FeatureExtraction", 
                        "ParallelLogger", "R6", "dplyr")
  
  cat("\nPackage Status:\n")
  for (pkg in required_packages) {
    if (requireNamespace(pkg, quietly = TRUE)) {
      version <- packageVersion(pkg)
      cat("✓", pkg, "version", as.character(version), "\n")
    } else {
      cat("✗", pkg, "NOT INSTALLED\n")
    }
  }
  
  # Check Java
  cat("\nJava Configuration:\n")
  tryCatch({
    java_version <- system("java -version", intern = TRUE, ignore.stderr = FALSE)
    cat("✓ Java available\n")
  }, error = function(e) {
    cat("✗ Java not found or not configured\n")
  })
  
  # Check study files
  cat("\nStudy Files:\n")
  study_files <- c("CreateAnalysisSpecification.R", "StrategusCodeToRun.R", 
                   "modules/BipolarMisclassificationModule/R/BipolarMisclassificationModule.R")
  
  for (file in study_files) {
    if (file.exists(file)) {
      cat("✓", file, "\n")
    } else {
      cat("✗", file, "MISSING\n")
    }
  }
  
  cat("\nEnvironment check completed.\n")
}

# Function to install OHDSI packages
installOhdsiPackages <- function() {
  cat("Installing OHDSI packages...\n")
  
  if (!requireNamespace("remotes", quietly = TRUE)) {
    install.packages("remotes")
  }
  
  ohdsi_packages <- c(
    "OHDSI/Strategus",
    "OHDSI/DatabaseConnector", 
    "OHDSI/PatientLevelPrediction",
    "OHDSI/CohortGenerator",
    "OHDSI/CohortDiagnostics",
    "OHDSI/FeatureExtraction",
    "OHDSI/ParallelLogger",
    "OHDSI/SqlRender"
  )
  
  for (pkg in ohdsi_packages) {
    cat("Installing", pkg, "...\n")
    remotes::install_github(pkg, upgrade = "never")
  }
  
  cat("OHDSI packages installation completed.\n")
}

# Make helper functions available globally
.GlobalEnv$checkStudyEnvironment <- checkStudyEnvironment
.GlobalEnv$installOhdsiPackages <- installOhdsiPackages
