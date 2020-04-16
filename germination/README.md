
<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Hardware%20files/SPIRO%20logo.jpg?raw=true" height="50" title="SPIRO">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/SPIRO%20text%20logo.png?raw=true" width="200" title="SPIRO">
</p>

## Seed germination assay</b>
<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/germination%20v1-resized.gif?raw=true" height="200" title="SPIRO">
<br>

This semi-automated assay is designed to analyze seed germination using data acquired by <a href="https://www.alyonaminina.org/spiro">SPIRO</a>. It was optimized for the typical plant model organism,<i> Arabidopsis thaliana</i>, but can be tuned for other plant species. 

The assay comprises of automated image analysis using SPIRO_Germination macro, quantitative data quality control followed by germination detection and statistical analysis using corresponding R scripts. An overview of the assay and quick instructions are provided in the text below, for the detailed instructions, please refer to the <b>SPIRO seed germination assay manual.</b>


## SPIRO_Germination macro

The macro contains several user-guided steps that enable implementation of the assay for a broad range of experiments with various layouts.
The analysis allows the user to select a subset of time range to be used for the germination analysis. This feature is not crucial for the assay <i>per se</i> as it does not affect germination analysis, but it reduces requirement for RAM during image segmentation, thus enabling use of the macro even on shitty computers. 
The user will also be asked to indicate groups of seeds, e.g. different genotypes and/or treatments. This step is crucial for downstream statistical analysis of the quantitative data. If needed, grouping can be manually modified after data quality control to enable different comparisons without re-running image analysis. The macro will produce three output files for each group of seeds:
- `group name.tiff` contains selection of the corresponding group cropped from the original image stack
- `group name germinationlabelled.tiff` is the graphical output of the macro. It contains time-lapse side by side comparison of original and segmented images for the corresponindg group with numbered identified seeds. This information can be helpful to verify that image processing indeed identified seeds and only seeds.
- `group name germination analysis.tsv` is the quantitative output of the macro, it contains perimeter and area data for each seed at each time point.<br>
For each group both files will be saved in the experiment folder: ` Experiment name/Results/Germination/plate<i>n</i>/group name`

<b> Requirements and implementation</b>:
- [Fiji](https://imagej.net/Fiji/Downloads) = ImageJ + default plugins. The macro was developed using v1.52p
- <a href="https://github.com/jiaxuanleong/SPIRO.Assays/tree/master/preprocessing">Preprocessed imaging data</a> generated in the preceding step
- Open Fiji
- In the top menu find Plugins -> Macros -> Run -> locate and open `SPIRO_Germination.ijm` file in the SPIRO.Assays folder downloaded during the previous step
- Follow the instructions provided by the macro


## R scripts

Quantitative data processsing is done in two steps. Firstly, data is put trhough quality control (QC) using `cleanup_germination_data.R`. This step will produce two ouput .tsv files. In the germination.postQC.log.tsv you can find a summary of QC, which seeds were processed normally and which has been filterd out by the QC. germination.postQC.tsv contains quantitative macro ouput data that passed quality control. <b>Importantly, in this file you can modify group names if you wish to perform different grouping for statistical analysis</b>. 
After QC, cleaned data can be fed into `process_germination_data.R` for detection of seed size, germination and statistical analysis. Analysis can be performed several times on the same experiment, each analysis will be saved in a separate subfolder. The analysis produces six types of output:
1. `descriptive_stats.tsv`contains T50, mean germination time, number of germinated and ungerminated seeds for each group and mean seed size per group
2. `germination-perseed.tsv`contains time and slice number at which germination of each seed was detected by our algorithm
3. `germination.t-tests.tsv`contains Welch's t-test results for pairwaise comparison of mean germination time for groups
4. `seedsize.t-tests.tsv`contains Welch's t-test results for pairwaise comparison of mean germination time for groups
5. Folder `Germination Plots`contains pdf files with germination curves plots for each group
6. Folder `Kaplan-Meier Plots`contains pdf files with  Kaplan-Meier test for pairwaise group comparison

<b> Requirements and implementation</b>:
- Download and install [R](https://www.r-project.org/)
- Download and install [R Studio](https://www.rstudio.com/) and [Git](https://git-scm.com/downloads) (sic! make sure that Git is enabled)
- Install required packages by copy pasting the following into the console of the R Studio:
```
install.packages(c('dplyr', 'reshape2', 'devtools', 'zoo', 'doParallel',
                   'foreach', 'ggplot2', 'survival', 'survminer'))
# we need the development version of germinationmetrics:
devtools::install_github("aravind-j/germinationmetrics")
```
- Create a project using version control tool that will allow easy download of updates:
 In the top menu go to File -> New project -> Version control -> Git -> Select a suitable directory location for the project and copy paste the repository URL: `https://github.com/jiaxuanleong/SPIRO.Assays`. 
- run `cleanup_germination_data.R`( click on the corresponding file name in the right bottom panel of R studio)
- Point the script to the experiment folder: in the top menu find Code -> Source-> Select your experiment folder. For Windows users it can be done via file picker (please note, that RStudio conveniently places it behind the RStudio window). For Mac OS users, right click on your experiment folder and hold `Alt` key to enable the "copy path to the directory" option, then copy paste the path to your experiment folder in the console of the R studio.
- Results of the QC step are saved in two files in the experiment folder: `Experiment name/Results/Germination/germination.postQC.log.tsv` and `germination.postQC.tsv`
- If needed, manually modify group names in the `germination.postQC.tsv` file by using, for example, find/replace function in Excel
- Run `process_germination_data.R`
- Point the script to the experiment folder
- Results of the analysis step are saved in the experiment folder: `Experiment name/Results/Germination/Analysis output/number of the analysis`. File `germination.postQC.tsv` is also saved into analysis folder to preserve the group names used for this particular analysis.


## Troubleshooting
- For troubleshooting please refer to this <a href="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/Germination%20assay%20troubleshooting.md">table</a>
- If you encounter an error not listed in the table, please submit a report as a github issue. We will address it ASAP.
