####### Script will combine methylation and clinical data
# this is 3th step in pipeline - check to see we are taking the first diagnosis

##########
# initialize libraries
##########
library(dplyr)
library(stringr)
library(impute)
library(data.table)
library(impute)
library(GenomicRanges)
library(biovizBase)
library(GEOquery)
library(IlluminaHumanMethylation450kmanifest)
library(preprocessCore)

##########
# Initialize folders
##########
home_folder <- '/home/benbrew/hpf/largeprojects/agoldenb/ben/Projects'
project_folder <- paste0(home_folder, '/LFS')
data_folder <- paste0(project_folder, '/Data')
methyl_data <- paste0(data_folder, '/methyl_data')
imputed_data <- paste0(data_folder, '/imputed_data')
idat_data <- paste0(methyl_data, '/raw_files')
model_data <- paste0(data_folder, '/model_data')
bumphunter_data <- paste0(data_folder, '/bumphunter_data')
clin_data <- paste0(data_folder, '/clin_data')

##########
# Read in methylation probe
##########
# raw
beta_raw <- readRDS(paste0(methyl_data, '/beta_raw.rda'))
beta_raw_controls <- readRDS(paste0(methyl_data, '/beta_raw_controls.rda'))

# quan
beta_quan <- readRDS(paste0(methyl_data, '/beta_quan.rda'))
beta_quan_controls <- readRDS(paste0(methyl_data, '/beta_quan_controls.rda'))

##########
# read in methylation for validation set
##########
beta_raw_valid <- readRDS(paste0(methyl_data, '/valid_raw.rda'))
beta_quan_valid <- readRDS(paste0(methyl_data, '/valid_quan.rda'))


##########
# make data frames
##########
#raw
beta_raw <- as.data.frame(beta_raw, stringsAsFactors = F)
beta_raw_controls <- as.data.frame(beta_raw_controls, stringAsFactors = F)
beta_raw_valid <- as.data.frame(beta_raw_valid, stringAsFactors = F)

#quan
beta_quan <- as.data.frame(beta_quan, stringsAsFactors = F)
beta_quan_controls <- as.data.frame(beta_quan_controls, stringAsFactors = F)
beta_quan_valid <- as.data.frame(beta_quan_valid, stringAsFactors = F)


##########
# new variable called sen_batch
##########
beta_raw$sen_batch <- ifelse(grepl('9721365183', rownames(beta_raw)), 'mon', 'tor_1')
beta_quan$sen_batch <- ifelse(grepl('9721365183', rownames(beta_quan)), 'mon', 'tor_1')


##########
# read in clinical data
##########
clin <- read.csv(paste0(clin_data, '/clinical_two.csv'), stringsAsFactors = F)

# clean clinical idss
clin$ids <-  gsub('A|B|_|-', '', clin$blood_dna_malkin_lab_)

##########
# function to clean ids names and get methyl_indicator for clin
##########
# dat_cases <- beta_raw
# dat_controls <- beta_raw_controls
# dat_valid <- beta_raw_valid
getMethylVar <- function(dat_cases, dat_controls, dat_vadlid) {
  
  # get idss from cases and controls
  cases_names <- as.character(dat_cases$ids)
  controls_names <- as.character(dat_controls$ids)
  valid_names <- as.character(dat_valid$ids)
  
  # combine idss
  methylation_names <- append(cases_names, controls_names)
  methylation_names <- append(methylation_names, valid_names)
  
  # remove 'A' and '_' in methylation names
  methylation_names <- gsub('A|B|_|-', '', methylation_names)
  
  # add '1' and make data frame 
  methylation_names <- as.data.frame(cbind(methylation_names, rep.int(1, length(methylation_names))))
  methylation_names$methylation_names <- as.character(methylation_names$methylation_names)
  methylation_names$V2 <- as.character(methylation_names$V2)
  names(methylation_names) <- c("ids", "methyl_indicator")
  methylation_names <- methylation_names[!duplicated(methylation_names),]
  
  # keep only first 4 characters of methylation_names$ids
  methylation_names$ids <- substr(methylation_names$ids, 1,4)
  
  # add methyl_indicator column to clin
  clin$methyl_indicator <- NA
  for (i in methylation_names$ids) {
    clin$methyl_indicator[clin$ids == i] <- methylation_names$methyl_indicator[methylation_names$ids == i]
  }
  
  # recode 1 = TRUE, FALSE otherwise
  clin$methyl_indicator <- ifelse(clin$methyl_indicator == 1, TRUE, FALSE)
  clin$methyl_indicator[is.na(clin$methyl_indicator)] <- FALSE
  
  return(clin)
  
  # summary(clin$methyl_indicator) # 193
}


##########
# functions to clean and join data
##########

# clean idss in each data set 
cleanids <- function(data){
  
  data$ids <- gsub('A|B|_|-', '', data$ids)
  data$ids <- substr(data$ids, 1,4) 
  return(data)
}
# get probe locations 

getIds <- function(cg_locations) {
  
  #idat files
  idatFiles <- list.files("GSE68777/idat", pattern = "idat.gz$", full = TRUE)
  sapply(idatFiles, gunzip, overwrite = TRUE)
  # read into rgSet
  rgSet <- read.450k.exp("GSE68777/idat")
  # preprocess quantil
  rgSet <- preprocessQuantile(rgSet)
  # get rangers 
  rgSet <- granges(rgSet)
  cg_locations <- as.data.frame(rgSet)
  # make rownames probe column
  cg_locations$probe <- rownames(cg_locations)
  rownames(cg_locations) <- NULL
  return(cg_locations)
}

# function that takes each methylation and merges with clinical - keep ids, family, p53 status, age data
joinData <- function(data, control, valid) {
  
  # get intersection of clin idss and data idss
  intersected_ids <- intersect(data$ids, clin$ids)
  features <- colnames(data)[1:(length(colnames(data)) - 3)]
  
  # loop to combine idsentifiers, without merging large table
  data$p53_germline <- NA
  data$age_diagnosis <- NA
  data$cancer_diagnosis_diagnoses <- NA
  data$age_sample_collection <- NA
  data$tm_donor_ <- NA
  data$gender <- NA
  
  if (!control) {
    
    for (i in intersected_ids) {
      
      data$p53_germline[data$ids == i] <- clin$p53_germline[which(clin$ids == i)]
      data$age_diagnosis[data$ids == i] <- clin$age_diagnosis[which(clin$ids == i)]
      data$cancer_diagnosis_diagnoses[data$ids == i] <- clin$cancer_diagnosis_diagnoses[which(clin$ids == i)]
      data$age_sample_collection[data$ids == i] <- clin$age_sample_collection[which(clin$ids == i)]
      data$tm_donor_[data$ids == i] <- clin$tm_donor_[which(clin$ids == i)]
      data$gender[data$ids == i] <- clin$gender[which(clin$ids == i)]

      
      
      print(i)
    } 
    data <- data[!is.na(data$p53_germline),]
    data <- data[!duplicated(data$ids),]
    data <- data[!duplicated(data$tm_donor_),]
    # data <- data[!is.na(data$age_diagnosis),]
    # data <- data[!is.na(data$age_sample_collection), ]
    if(valid) {
      data <- data[, c('ids', 'p53_germline', 'age_diagnosis', 'cancer_diagnosis_diagnoses',
                       'age_sample_collection', 'gender','sentrix_id', features)]
    } else {
      data <- data[, c('ids', 'p53_germline', 'age_diagnosis', 'cancer_diagnosis_diagnoses',
                       'age_sample_collection', 'gender','sentrix_id','sen_batch', features)]
    }
   
  } else {
    
    for (i in intersected_ids) {
      
      data$p53_germline[data$ids == i] <- clin$p53_germline[which(clin$ids == i)]
      data$cancer_diagnosis_diagnoses[data$ids == i] <- clin$cancer_diagnosis_diagnoses[which(clin$ids == i)]
      data$age_sample_collection[data$ids == i] <- clin$age_sample_collection[which(clin$ids == i)]
      data$tm_donor_[data$ids == i] <- clin$tm_donor_[which(clin$ids == i)]
      data$gender[data$ids == i] <- clin$gender[which(clin$ids == i)]
      
      
      print(i)
    } 
    data <- data[!is.na(data$p53_germline),]
    # data <- data[!duplicated(data$ids),]
    # data <- data[!duplicated(data$tm_donor_),]
    data <- data[, c('ids', 'p53_germline', 'age_diagnosis', 'cancer_diagnosis_diagnoses',
                     'age_sample_collection', 'gender', 'sentrix_id', features)]
  }
  
  return(data)
}

# take p53 germline column and relevel factors to get rids of NA level
relevelFactor <- function (data) {
  
  data$p53_germline <- factor(data$p53_germline, levels = c('Mut', 'WT'))
  return(data)
}

# # Function to convert all genes/probe columns to numeric
# makeNum <- function (model_data) {
#   
#   model_data[, 6:ncol(model_data)] <- apply (model_data[, 6:ncol(model_data)], 2, function(x) as.numeric(as.character(x)))
#   
#   return(model_data)
# }


##########
# apply functions to idat data - cases and controls and save to model_data folder
# ##########
# # get clinical methylation indicator
# clin <- getMethylVar(beta_quan, beta_quan_controls)
# 
# # get cg locations
# cg_locations <- getIds()
# 
# write.csv(cg_locations, paste0(model_data, '/cg_locations.csv'))
# write.csv(clin, paste0(clin_data, '/clinical_two.csv'))
##########
# First do cases
##########

# raw
# first clean idss
beta_raw <- cleanids(beta_raw)

options(warn=1)

# second join data
beta_raw <- joinData(beta_raw, control = F, valid = F)

# thrids relevel factors
beta_raw <- relevelFactor(beta_raw)

#quan
# first clean idss
beta_quan <- cleanids(beta_quan)

options(warn=1)

# second join data
beta_quan <- joinData(beta_quan, control = F, valid = F)

# thrids relevel factors
beta_quan <- relevelFactor(beta_quan)

#########
# 2nd do controls
##########

# raw
# first clean ids
beta_raw_controls <- cleanids(beta_raw_controls)

# second join data
beta_raw_controls <- joinData(beta_raw_controls, control = T, valid = F)

# quan
# first clean ids
beta_quan_controls <- cleanids(beta_quan_controls)

# second join data
beta_quan_controls <- joinData(beta_quan_controls, control = T, valid = F)

#########
# 3rd do validation
##########

# raw
# first clean ids
beta_raw_valid <- cleanids(beta_raw_valid)

# second join data
beta_raw_valid <- joinData(beta_raw_valid, control = F, valid = T)

# thrids relevel factors
beta_raw_valid <- relevelFactor(beta_raw_valid)


# quan
# first clean ids
beta_quan_valid <- cleanids(beta_quan_valid)

# second join data
beta_quan_valid <- joinData(beta_quan_valid, control = F, valid = T)

# thrids relevel factors
beta_quan_valid <- relevelFactor(beta_quan_valid)



#########
# save data
#########

# raw
saveRDS(beta_raw, paste0(methyl_data, '/beta_raw.rda'))

saveRDS(beta_raw_controls, paste0(methyl_data, '/beta_raw_controls.rda'))

saveRDS(beta_raw_valid, paste0(methyl_data, '/beta_raw_valid.rda'))


# quan
saveRDS(beta_quan, paste0(methyl_data, '/beta_quan.rda'))

saveRDS(beta_quan_controls, paste0(methyl_data, '/beta_quan_controls.rda'))

saveRDS(beta_quan_valid, paste0(methyl_data, '/beta_quan_valid.rda'))


