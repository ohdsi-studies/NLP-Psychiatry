# Copyright 2018 Observational Health Data Sciences and Informatics
#
# This file is part of PredictionNetworkStudySkeleton
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#' Package the results for sharing with OHDSI researchers
#'
#' @details
#' This function packages the results.
#'
#' @param outputFolder        Name of local folder to place results; make sure to use forward slashes
#'                            (/)
#' @param minCellCount        The minimum number of subjects contributing to a count before it can be included in the results.
#'
#' @export
packageResults <- function(outputFolder,
                           minCellCount = 5) {
  if(missing(outputFolder)){
    stop('Missing outputFolder...')
  }

  # transport the results

  #create export subfolder in workFolder
  exportFolder <- file.path(outputFolder, "resultsToShare")

  if (!file.exists(exportFolder)){
    dir.create(exportFolder, recursive = T)
  }

  # loads analysis results
  if(file.exists(file.path(outputFolder, 'validationResults.rds'))){
    plpResult <- readRDS(file.path(outputFolder, 'validationResults.rds'))

    if(minCellCount==0){
      minCellCount <- NULL
    }

    # Save the shareable PLP result
    PatientLevelPrediction::savePlpShareable(plpResult, saveDirectory = exportFolder, minCellCount = minCellCount)

    # Load the modified PLP result from the export folder
    result <- readRDS(file.path(exportFolder, 'validationResults.rds'))


    if (!is.data.frame(result$scoreThreshold)) {
      result$scoreThreshold <- as.data.frame(result$scoreThreshold)
    }

    #==== remove low counts from extras:
    if(!is.null(minCellCount) && minCellCount>0){
      result$survInfo <- NULL

      # scoreThreshold
      removeId <- result$scoreThreshold[,'N'] < minCellCount | result$scoreThreshold[,'O'] < minCellCount
      result$scoreThreshold[removeId,c('N','O','popN','sensitivity','PPV')] <- -1

      # yauc
      removeId <- result$yauc$N < minCellCount
      result$yauc[removeId, 'auc'] <- -1
      result$yauc[removeId, 'N'] <- -1
    }

    saveRDS(result, file.path(exportFolder, 'validationResults.rds'))

  }



  ### Add all to zip file ###
  zipName <- paste0(outputFolder, '.zip')
  OhdsiSharing::compressFolder(exportFolder, zipName)
  # delete temp folder
  unlink(exportFolder, recursive = T)

  writeLines(paste("\nStudy results are compressed and ready for sharing at:", zipName))
  return(zipName)
}
