# INSTALLING (uncomment to install)

#install.packages('devtools')
#devtools::install_github("OHDSI/OhdsiSharing")
#devtools::install_github("OHDSI/FeatureExtraction")
#devtools::install_github("OHDSI/PatientLevelPrediction")
#devtools::install_github("ohdsi-studies/BipolarMisclassificationValidation")
#devtools::install_github("OHDSI/DatabaseConnector")
devtools::load_all("/data/fmoomtaheen/BipolarMisclassificationValidation")

library(BipolarMisclassificationValidation)

if (!requireNamespace("getPass", quietly = TRUE)) {
  install.packages("getPass")
}
library(getPass)

mypassword = getPass::getPass("Enter your database password")


# USER INPUTS
#=======================
# minCellCount is a number (e.g., 0, 5 or 10) - this will
# remove any cell with a count less than minCellCount when packing the results to share
# you will have a complete copy of the results locally, but the results ready to
# share will have values less than minCellCount removed.
minCellCount <- 0
# the study runs n patients aged 10+ you can restrict to 18+ by setting restrictToAdults to TRUE
restrictToAdults <- FALSE

# The folder where the study intermediate and result files will be written:
outputFolder <- "/data/fmoomtaheen/bipolarValidationResults/ccae/"

# Specify where the temporary files (used by the ff package) will be created:
options(fftempdir = "/data/fmoomtaheen/tmp/")


# Details for connecting to the server:
dbms <- "postgresql"
user <- 'fmoomtaheen'
server <- 'localhost/truven'
port <- '5432'

connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = dbms,
                                                                server = server,
                                                                user = user,
                                                                password = mypassword,
                                                                port = port,
                                                                pathToDriver = "/data/fmoomtaheen/BipolarMisclassificationValidation/extras/")

# Add the database containing the OMOP CDM data
cdmDatabaseSchema <- 'ccae2003_2022'
# Add a sharebale name for the cdmDatabaseSchema database
databaseName <- 'ccae2003_2022'
# Add a database with read/write access as this is where the cohorts will be generated
cohortDatabaseSchema <- 'ccae_mdd_bd_ohdsi'

oracleTempSchema <- NULL

# table name where the cohorts will be generated
cohortTable <- 'bipolarValidationCohort'
#=======================

BipolarMisclassificationValidation::execute(connectionDetails = connectionDetails,
                                            cdmDatabaseSchema = cdmDatabaseSchema,
                                            cohortDatabaseSchema = cohortDatabaseSchema,
                                            cohortTable = cohortTable,
                                            outputFolder = outputFolder,
                                            databaseName = databaseName,
                                            oracleTempSchema = oracleTempSchema,
                                            viewModel = F,
                                            createCohorts = T,
                                            runValidation = T,
                                            packageResults = T,
                                            minCellCount = minCellCount,
                                            sampleSize = NULL,
                                            restrictToAdults = restrictToAdults)
