# ******************************************************************************
# Install OHDSI Packages for NLP-Psychiatry Study
# ******************************************************************************
#
# This script installs all required OHDSI packages for the NLP-Psychiatry study.
# Run this script if you get errors about missing packages like CohortDiagnostics.
#
# Usage: Rscript InstallOhdsiPackages.R
#
# ******************************************************************************

cat("Installing OHDSI packages for NLP-Psychiatry study...\n")
cat("This may take several minutes.\n\n")

# Install remotes if not available
if (!requireNamespace("remotes", quietly = TRUE)) {
  cat("Installing remotes package...\n")
  install.packages("remotes")
}

# List of required OHDSI packages
ohdsi_packages <- c(
  "OHDSI/Strategus",
  "OHDSI/DatabaseConnector",
  "OHDSI/PatientLevelPrediction",
  "OHDSI/CohortGenerator",
  "OHDSI/CohortDiagnostics",
  "OHDSI/FeatureExtraction",
  "OHDSI/ParallelLogger",
  "OHDSI/SqlRender",
  "OHDSI/CirceR"
)

# Install each package
for (pkg in ohdsi_packages) {
  cat("Installing", pkg, "...\n")
  tryCatch({
    remotes::install_github(pkg, upgrade = "never", force = FALSE)
    cat("✓", pkg, "installed successfully\n")
  }, error = function(e) {
    cat("✗ Error installing", pkg, ":", e$message, "\n")
  })
}

# Also install some additional dependencies that might be needed
additional_packages <- c("magrittr", "dplyr", "tibble", "ff", "keyring")

cat("\nInstalling additional dependencies...\n")
for (pkg in additional_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat("Installing", pkg, "...\n")
    tryCatch({
      install.packages(pkg)
      cat("✓", pkg, "installed successfully\n")
    }, error = function(e) {
      cat("✗ Error installing", pkg, ":", e$message, "\n")
    })
  } else {
    cat("✓", pkg, "already installed\n")
  }
}

cat("\n=================================================================\n")
cat("OHDSI PACKAGE INSTALLATION COMPLETED\n")
cat("=================================================================\n")

# Check if all packages are now available
cat("\nChecking package availability...\n")
required_packages <- c("Strategus", "DatabaseConnector", "PatientLevelPrediction",
                      "CohortGenerator", "CohortDiagnostics", "FeatureExtraction",
                      "ParallelLogger", "CirceR", "R6", "magrittr")

all_available <- TRUE
for (pkg in required_packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    cat("✓", pkg, "available\n")
  } else {
    cat("✗", pkg, "NOT AVAILABLE\n")
    all_available <- FALSE
  }
}

if (all_available) {
  cat("\n🎉 All required packages are now installed!\n")
  cat("\nYou can now run:\n")
  cat("  source('CreateAnalysisSpecification.R')\n")
  cat("  source('StrategusCodeToRun.R')\n")
} else {
  cat("\n⚠️  Some packages are still missing.\n")
  cat("You may need to install them manually or check for installation errors above.\n")
}

cat("\n=================================================================\n")
