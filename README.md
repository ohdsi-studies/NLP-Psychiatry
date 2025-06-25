Study Title: NLP-Psychiatry
===========================

<img src="https://img.shields.io/badge/Study%20Status-Started-blue.svg" alt="Study Status: Started">

- Analytics use case(s): **Patient-Level Prediction**
- Study type: **Clinical Application**
- Tags: **Psychiatry, NLP, Bipolar Disorder, Depression, OHDSI, Strategus**
- Study lead: **Ming Huang*
- Study lead forums tag:
- Study start date:
- Study end date:
- Protocol: **[Protocol](https://ohdsiorg.sharepoint.com/:w:/r/sites/Workgroup-Psychiatry/_layouts/15/Doc2.aspx?action=edit&sourcedoc=%7B70fd0235-3cce-412e-af2d-df0eaacd56bc%7D&wdOrigin=TEAMS-MAGLEV.teamsSdk_ns.rwc&wdExp=TEAMS-TREATMENT)**
- Publications: **-**
- Results explorer: **-**

This repository contains a multi-component psychiatric prediction study framework using the OHDSI Strategus platform. The study currently includes validation of a bipolar misclassification prediction model and is designed to be extensible for additional psychiatric prediction components.


## Background

This study framework addresses the critical need for improved psychiatric diagnosis prediction using electronic health records. The initial component focuses on bipolar disorder misclassification - a significant clinical problem where patients with Bipolar Disorder are frequently misdiagnosed as having Major Depressive Disorder (MDD), leading to delayed proper treatment.

### Current Study Components

1. **Bipolar Misclassification Validation**: Validates a predictive model that identifies patients initially diagnosed with MDD who are likely to be rediagnosed with Bipolar Disorder within 1 year.

### Future Planned Components

The framework is designed to accommodate additional psychiatric prediction modules, such as:
- Suicide risk prediction
- Treatment response prediction
- Psychiatric comorbidity identification
- NLP-based symptom extraction and prediction

## Technical Architecture

This study uses the **OHDSI Strategus framework** for coordinated multi-database execution. The architecture includes:

- **Strategus Study Protocol**: JSON-based analysis specification for multi-component execution
- **Custom Modules**: Psychiatric prediction modules that integrate with the Strategus ecosystem
- **Extensible Design**: Framework supports adding new prediction components without disrupting existing functionality
- **OMOP CDM Compatibility**: Works with standardized healthcare databases across the OHDSI network

## Quick Start

### 1. Test Migration (Verify Setup)
```r
source("TestMigration.R")
```

### 2. Install OHDSI Packages
```r
installOhdsiPackages()
```

### 3. Create Analysis Specification
```r
source("CreateAnalysisSpecification.R")
```

### 4. Configure Database Connection
Edit `StrategusCodeToRun.R` with your database details

### 5. Execute Study
```r
source("StrategusCodeToRun.R")
```

## Documentation

- **[Migration Guide](MIGRATION_GUIDE.md)**: Comprehensive migration documentation
- **[Migration Complete](MIGRATION_COMPLETE.md)**: Summary of completed migration
- **[Module Documentation](modules/BipolarMisclassificationModule/README.md)**: BipolarMisclassificationModule details

### Study Status

Choose one of the following options:

| Badge             | Description                          |
| ----------------- | ------------------------------------ |
| <img src="https://img.shields.io/badge/Study%20Status-Repo%20Created-lightgray.svg" alt="Study Status: Repo Created"> | The study repository has just been created. Work has not yet commenced. | 
| <img src="https://img.shields.io/badge/Study%20Status-Started-blue.svg" alt="Study Status: Started"> | A first commit was made (to something else than the README file). Work has commenced. |
| <img src="https://img.shields.io/badge/Study%20Status-Design%20Finalized-brightgreen.svg" alt="Study Status: Design Finalized"> | The protocol and study code have been finalized. | 
| <img src="https://img.shields.io/badge/Study%20Status-Results%20Available-yellow.svg" alt="Study Status: Results Available"> | The study results are publicly available, for example in a paper or results explorer app. | 
| <img src="https://img.shields.io/badge/Study%20Status-Complete-orange.svg" alt="Study Status: Complete"> | The study is complete, no further dissemination planned. | 
| <img src="https://img.shields.io/badge/Study%20Status-Suspended-red.svg" alt="Study Status: Suspended"> | The study has been suspended, and may or may not be continued at a later point in time. | 

Copy the relevant markdown code from [this page](badgesMarkdownCode.md), and paste it in your README file, just below the study title.

### Analytics Use Cases

Choose one or more options from: 

- `Characterization`
- `Population-Level Estimation`, or
- `Patient-Level Prediction` 

See [the Data Analytics Use Cases chapter](https://ohdsi.github.io/TheBookOfOhdsi/DataAnalyticsUseCases.html) for more details.

### Study types

Can be either:

- `Methods Research` if the study explores a methodological question, for example an evaluation of various propensity score approaches. 
- `Clinical Application` if the study aims to answer a clinically relevant question, for example 'Does drug A cause outcome B?'.

