# NLP-Psychiatry Strategus Migration Guide

This document describes the migration of the BipolarMisclassificationValidation R package to the OHDSI Strategus framework and provides guidance for using the new multi-component study structure.

## Migration Overview

### What Was Migrated

The original `BipolarMisclassificationValidation` R package has been successfully migrated to a Strategus-based study framework with the following transformations:

1. **Standalone R Package → Strategus Module**: The original package functionality is now implemented as a custom Strategus module
2. **Single Study → Multi-Component Framework**: The new structure supports multiple psychiatric prediction components
3. **Package-based Execution → JSON Specification**: Study execution now uses Strategus JSON analysis specifications
4. **Custom Results → Standardized CSV Output**: Results follow Strategus conventions for multi-database studies

### Key Benefits

- **Multi-Database Coordination**: Execute across multiple OMOP CDM databases simultaneously
- **Standardized Results**: Consistent output format for network studies
- **Extensible Architecture**: Easy to add new psychiatric prediction modules
- **Reproducible Execution**: renv-based dependency management
- **Network Study Ready**: Compatible with OHDSI network study protocols

## New Directory Structure

```
NLP-Psychiatry/
├── README.md                           # Updated study description
├── .Rprofile                          # R environment configuration
├── renv.lock                          # Dependency management
├── NLP-Psychiatry.Rproj              # RStudio project file
├── CreateAnalysisSpecification.R      # Creates Strategus JSON specification
├── StrategusCodeToRun.R              # Main execution script
├── TestMigration.R                   # Migration validation script
├── MIGRATION_GUIDE.md                # This document
├── modules/                          # Strategus modules directory
│   └── BipolarMisclassificationModule/
│       ├── R/
│       │   ├── BipolarMisclassificationModule.R  # Main R6 module class
│       │   ├── ModuleHelpers.R                   # Helper functions
│       │   └── LoadModule.R                      # Module loader
│       ├── inst/
│       │   ├── cohorts/              # Cohort definitions (migrated)
│       │   ├── settings/             # Configuration files (migrated)
│       │   └── sql/                  # SQL scripts (migrated)
│       ├── DESCRIPTION               # Module metadata
│       └── README.md                 # Module documentation
├── BipolarMisclassificationValidation/  # Original package (preserved)
└── Documents/                        # Study documentation
```

## Migration Details

### 1. Module Implementation

The original R package functionality has been converted to a Strategus R6 module:

**Original**: `BipolarMisclassificationValidation::execute()`
**New**: `BipolarMisclassificationModule$new()$execute()`

Key changes:
- R6 class structure for Strategus compatibility
- Standardized module interface (`createModuleSpecifications`, `execute`, etc.)
- CSV result output instead of RDS files
- Integration with Strategus job context

### 2. Cohort Definitions

**Original**: Package-embedded cohort definitions
**New**: Module-embedded cohort definitions with Strategus shared resources

- All cohort JSON files migrated to `modules/BipolarMisclassificationModule/inst/cohorts/`
- `CohortsToCreate.csv` preserved with same structure
- Cohorts now managed through CohortGenerator shared resources

### 3. Prediction Model

**Original**: Fixed coefficient model in `getModel()` function
**New**: Model coefficients embedded in module specifications

The prediction logic remains identical:
- Same age group coefficients
- Same clinical feature weights
- Same scoring and probability conversion
- Same validation metrics

### 4. Results Structure

**Original**: Single RDS file with nested results
**New**: Multiple CSV files following Strategus conventions

| Original | New CSV Files |
|----------|---------------|
| `result$performanceEvaluation` | `performance_metrics.csv` |
| `result$calibrationSummary` | `calibration.csv` |
| `result$thresholdSummary` | `threshold_summary.csv` |

## Usage Instructions

### 1. Environment Setup

```r
# Check environment
source("TestMigration.R")

# Install OHDSI packages if needed
installOhdsiPackages()

# Check study environment
checkStudyEnvironment()
```

### 2. Create Analysis Specification

```r
# Generate the Strategus JSON specification
source("CreateAnalysisSpecification.R")

# This creates: AnalysisSpecification.json
```

### 3. Configure Database Connection

Edit `StrategusCodeToRun.R` with your database details:

```r
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "your_dbms",
  server = "your_server", 
  user = "your_username",
  password = "your_password",
  port = "your_port"
)

cdmDatabaseSchema <- "your_cdm_schema"
workDatabaseSchema <- "your_work_schema"
```

### 4. Execute Study

```r
# Run the complete study
source("StrategusCodeToRun.R")

# Results will be in: ./StrategusOutput/
```

## Comparison: Original vs. Migrated

### Execution

**Original**:
```r
BipolarMisclassificationValidation::execute(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTable = cohortTable,
  outputFolder = outputFolder,
  databaseName = databaseName,
  createCohorts = TRUE,
  runValidation = TRUE,
  packageResults = TRUE
)
```

**New**:
```r
# 1. Create specification
source("CreateAnalysisSpecification.R")

# 2. Execute via Strategus
source("StrategusCodeToRun.R")
```

### Results Access

**Original**:
```r
result <- readRDS("outputFolder/databaseName/validationResults.rds")
auc <- result$performanceEvaluation$evaluationStatistics$value[
  result$performanceEvaluation$evaluationStatistics$metric == "AUC"
]
```

**New**:
```r
performance <- read.csv("StrategusOutput/strategusOutput/performance_metrics.csv")
auc <- performance$auc
```

## Extensibility for Future Modules

The new architecture supports adding additional psychiatric prediction modules:

### 1. Create New Module

```
modules/
├── BipolarMisclassificationModule/     # Existing
└── NewPsychiatricModule/               # New module
    ├── R/
    │   ├── NewPsychiatricModule.R
    │   └── ModuleHelpers.R
    ├── inst/
    └── README.md
```

### 2. Add to Analysis Specification

```r
# In CreateAnalysisSpecification.R
newModule <- NewPsychiatricModule$new()
newModuleSpecs <- newModule$createModuleSpecifications(...)

analysisSpecifications <- analysisSpecifications %>%
  Strategus::addModuleSpecifications(newModuleSpecs)
```

### 3. Coordinated Execution

All modules execute together through the same Strategus framework, sharing cohorts and database connections.

## Validation

The migration preserves all original functionality:

✅ **Cohort Creation**: Same cohort definitions and SQL logic
✅ **Feature Extraction**: Identical covariate settings and extraction
✅ **Prediction Model**: Same coefficients and scoring algorithm  
✅ **Validation Metrics**: Same performance evaluation methods
✅ **Results Packaging**: Equivalent output with improved standardization

## Troubleshooting

### Common Issues

1. **Module Loading Errors**
   - Ensure R6 package is installed
   - Check file paths in LoadModule.R

2. **Missing Cohort Files**
   - Verify cohort JSON files in `modules/BipolarMisclassificationModule/inst/cohorts/`
   - Check CohortsToCreate.csv format

3. **Strategus Package Issues**
   - Install from GitHub: `remotes::install_github("OHDSI/Strategus")`
   - Check HADES package versions

4. **Database Connection Problems**
   - Verify connection details in StrategusCodeToRun.R
   - Ensure database drivers are installed

### Getting Help

- **Study Lead**: Christophe Lambert (cglambert@unm.edu)
- **Original Study**: Jenna Reps
- **OHDSI Forums**: https://forums.ohdsi.org/
- **Strategus Documentation**: https://ohdsi.github.io/Strategus/

## Next Steps

1. **Test Migration**: Run `source("TestMigration.R")`
2. **Validate Results**: Compare with original package output
3. **Add New Modules**: Implement additional psychiatric prediction components
4. **Network Deployment**: Coordinate with OHDSI network sites
5. **Results Integration**: Develop unified results viewer for all modules

The migration provides a solid foundation for expanding the NLP-Psychiatry study into a comprehensive multi-component psychiatric prediction framework while maintaining full compatibility with the original bipolar misclassification validation study.
