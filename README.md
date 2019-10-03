# LFS-age-of-onset

# Main folders

## 1) Scripts

This folder contains the main sub folders for the analysis. 

### 1A) predict_age

This is the main folder in the repository and holds all the scripts used in the main pipeline. 

#### a) Strategy = With Age removal - First principle component removed and data reconstructed.

Run in this order:
##### First script: read_in_450k.R - this script reads in the .IDAT files and clean the data. it creates 4 main datasets.
1) cases_450_beta.rda (can be m_value instead of beta). These are LFS cancer patients that had methylation generated from 450k array.
2) cases_wt_450_beta.rda - These are cancer patients that don't have LFS (family members. Also cases means cancer patients and controls are cancer free. the wt stands for wild type).
3) controls_450_beta.rda - These are LFS patients with no cancer yet. 
4) controls_wt_450_beta.rda - Theses patients that don't have cancer or LFS (family members).

#### Second Script: read_in_850k. - The same exact thing is done for this script, it creates 
1) cases_850_beta.rda
2) cases_wt_850_beta.rda
3) controls_850_beta.rda
4) controls_wt_850_beta.rda
- The only difference is this .rda files with '850' come from IDAT files generated on an 850k array, not a 450k array.

#### Third Script: get_g_ranges.R
- This script simply reads in generic methylation data to grab genomic locations. We need those locations for the next script to run bumphunter.

#### Fourth Script: get_pca.R
- This script reads in all they data and uses a function called get_pca to view the batch effects from technology - 450k vs 850k. This script also runs bumphunter to remove the batch effects. It saves a combat version of each dataset and also a version that doen't remove the batch effects (to compare later with the others). I experimented with a lot of combat strategies  It also combines the data an


#### Fifth Script: prepare_data.R 
- This script reads in all the data generated at this point: normal data prepare's the data for modeling, buy removing duplicates and running bumphunter to take the subset of probes that are differentially methylated between con_wt (dataset of non cancer non LFS patients) and con_mut (data of non cancer LFS patients). This subset is 'LFS' specific and cuts down the dimentionality of the data significantly).
- 





#### 2) Data

This folder is in the .gitignore file so it's not on github. 
