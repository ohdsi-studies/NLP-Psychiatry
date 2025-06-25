# BipolarMisclassificationModule

A Strategus module for validating bipolar misclassification prediction models in patients initially diagnosed with Major Depressive Disorder (MDD).

## Overview

This module implements the bipolar misclassification validation study as a Strategus module. It validates a predictive model that identifies patients initially diagnosed with MDD who are likely to be rediagnosed with Bipolar Disorder within 1 year.

### Clinical Background

Patients with Bipolar Disorder are frequently misdiagnosed as having Major Depressive Disorder initially, leading to delayed proper treatment. This module validates a simple scoring model that can predict which newly diagnosed MDD patients will receive a bipolar diagnosis within the next year.

## Features

- **Fixed Coefficient Scoring Model**: Uses predefined weights for various clinical features
- **Risk Factor Analysis**: Includes age groups, mental health history, and clinical indicators
- **Strategus Integration**: Fully compatible with the OHDSI Strategus framework
- **Multi-Database Support**: Designed for execution across multiple OMOP CDM databases
- **Results Standardization**: Outputs results in CSV format following Strategus conventions

## Module Structure

```
BipolarMisclassificationModule/
├── R/
│   ├── BipolarMisclassificationModule.R  # Main R6 module class
│   ├── ModuleHelpers.R                   # Helper functions
│   └── LoadModule.R                      # Module loader script
├── inst/
│   ├── cohorts/                          # Cohort definition JSON files
│   ├── settings/                         # Configuration files
│   └── sql/                              # SQL scripts
├── man/                                  # Documentation
├── DESCRIPTION                           # Package metadata
└── README.md                             # This file
```

## Usage

### As Part of Strategus Study

The module is designed to be used within the NLP-Psychiatry Strategus study framework:

```r
# Load the module
source("modules/BipolarMisclassificationModule/R/LoadModule.R")

# Create module instance
bipolarModule <- createBipolarMisclassificationModule()

# Create module specifications
moduleSpecs <- bipolarModule$createModuleSpecifications(
  targetCohortId = 12292,  # MDD cohort
  outcomeCohortId = 7746,  # Bipolar diagnosis cohort
  generateStats = TRUE,
  runValidation = TRUE,
  minCellCount = 5,
  restrictToAdults = FALSE
)

# Add to analysis specification
analysisSpecifications <- analysisSpecifications %>%
  Strategus::addModuleSpecifications(moduleSpecs)
```

### Standalone Testing

```r
# Test module specifications creation
source("modules/BipolarMisclassificationModule/R/LoadModule.R")
specs <- testModuleSpecifications()
```

## Configuration Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `targetCohortId` | integer | 12292 | Cohort ID for target population (MDD patients) |
| `outcomeCohortId` | integer | 7746 | Cohort ID for outcome (bipolar diagnosis) |
| `generateStats` | boolean | TRUE | Whether to generate cohort statistics |
| `runValidation` | boolean | TRUE | Whether to run validation analysis |
| `minCellCount` | integer | 5 | Minimum cell count for results |
| `restrictToAdults` | boolean | FALSE | Whether to restrict to patients 18+ |

## Prediction Model

The module uses a fixed coefficient scoring model with the following features:

### Age Groups
- Various age group coefficients (20-24, 30-34, 35-39, etc.)
- Negative coefficients for older age groups (70+)

### Clinical Features
- Mental health disorder history
- Suicidal thoughts or self-harm
- Pregnancy status
- Anxiety disorders and medications
- Depression severity (mild, severe, with psychosis)
- Substance use disorders

### Scoring
The model calculates a risk score by summing weighted feature values, then converts to probability using logistic transformation.

## Output

The module generates the following CSV result files:

- `performance_metrics.csv`: AUC, AUPRC, Brier score, population metrics
- `calibration.csv`: Calibration statistics by risk decile
- `threshold_summary.csv`: Operating characteristics at various thresholds

## Dependencies

- R (>= 4.2.0)
- Strategus
- DatabaseConnector
- PatientLevelPrediction (>= 4.0.0)
- CohortGenerator
- FeatureExtraction
- ParallelLogger
- R6
- dplyr
- tibble

## Installation

This module is part of the NLP-Psychiatry study repository. No separate installation is required when using the study framework.

## Support

For questions or issues:
- Study lead: Christophe Lambert (cglambert@unm.edu)
- Original study lead: Jenna Reps
- OHDSI Forums: https://forums.ohdsi.org/

## License

Apache License 2.0

## Citation

If you use this module in your research, please cite the original bipolar misclassification validation study and the NLP-Psychiatry framework.

## Version History

- v1.0.0: Initial Strategus module implementation
  - Migrated from standalone R package
  - Added Strategus framework compatibility
  - Standardized result outputs
