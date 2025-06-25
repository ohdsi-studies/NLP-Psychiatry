# INSTALLING (uncomment to install)

# install.packages('devtools')
library(devtools)

# devtools::install_github("OHDSI/OhdsiSharing")
# devtools::install_github("OHDSI/FeatureExtraction", dependencies=TRUE, force=TRUE)
# devtools::install_github("ohdsi-studies/BipolarMisclassificationValidation", force=TRUE)
# devtools::install_github("OHDSI/DatabaseConnector", dependencies=TRUE,force=TRUE)
# devtools::install_github("OHDSI/SqlRender", dependencies=TRUE,force=TRUE)
# devtools::install_github("OHDSI/PatientLevelPrediction", dependencies=TRUE,force=TRUE)

library(BipolarMisclassificationValidation)
library(OhdsiSharing)
library(FeatureExtraction)
library(PatientLevelPrediction)
library(DatabaseConnector)
library(rJava)
library(getPass)



if (!requireNamespace("getPass", quietly = TRUE)) {
  install.packages("getPass")
}


# USER INPUTS
#=======================
# minCellCount is a number (e.g., 0, 5 or 10) - this will
# remove any cell with a count less than minCellCount when packing the results to share # nolint
# you will have a complete copy of the results locally, but the results ready to
# share will have values less than minCellCount removed.
minCellCount <- 0
# the study runs n patients aged 10+ you can restrict to 18+ by setting restrictToAdults to TRUE
restrictToAdults <- FALSE

# The folder where the study intermediate and result files will be written:
outputFolder <- "./bipolarValidationResults"

# Specify where the temporary files (used by the ff package) will be created:
options(fftempdir = "location with space to save big data")


# Details for connecting to the server:
dbms <- "you dbms"
user <- 'your username'
pw <- getPass::getPass("Enter your database password")
server <- 'your server'
port <- 'your port'


connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = dbms,
                                                                server = server,
                                                                user = user,
                                                                password = pw,
                                                                port = port,
                                                                pathToDriver = "path to your driver",)

# Add the database containing the OMOP CDM data
cdmDatabaseSchema <- 'cdm database schema'
# Add a sharebale name for the cdmDatabaseSchema database
databaseName <- 'Validation Data Name'
# Add a database with read/write access as this is where the cohorts will be generated
cohortDatabaseSchema <- 'work database schema'

tempEmulationSchema <- NULL

# table name where the cohorts will be generated
cohortTable <- 'bipolarValidationCohort'
#=======================


BipolarMisclassificationValidation::execute(connectionDetails = connectionDetails,
                                            cdmDatabaseSchema = cdmDatabaseSchema,
                                            cohortDatabaseSchema = cohortDatabaseSchema,
                                            cohortTable = cohortTable,
                                            outputFolder = outputFolder,
                                            databaseName = databaseName,
                                            tempEmulationSchema = tempEmulationSchema,
                                            viewModel = F,
                                            createCohorts = T,
                                            runValidation = T,
                                            packageResults = T,
                                            minCellCount = minCellCount,
                                            sampleSize = NULL,
                                            restrictToAdults = restrictToAdults)





