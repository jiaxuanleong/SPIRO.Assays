
<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Hardware%20files/SPIRO%20logo.jpg?raw=true" height="50" title="SPIRO">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/SPIRO%20text%20logo.png?raw=true" width="200" title="SPIRO">
</p>

## Root growth assay</b>
<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/root-grwoth-v1-resized.gif?raw=true" height="200" title="SPIRO">
<br>

This semi-automated assay is designed to analyze root growth using data acquired by <a href="https://www.alyonaminina.org/spiro">SPIRO</a>. It was optimized for the typical plant model organism,<i> Arabidopsis thaliana</i>, but can be tuned for other plant species. 

The assay comprises of automated image analysis using `SPIRO_RootGrowth macro`, data quality control using `consolidate_rootgrowth_data.R` followed by root growth measurement and statistical analysis using `process_rootgrowth_data.R`. The assay provides data of root length for individual seedlings and groups of seedlings and statistical analysis of root grwoth rate for groups of seedlings.


## Requirements
- [Fiji](https://imagej.net/Fiji/Downloads) = ImageJ + default plugins. The macro was developed using v1.52p
- <a href="https://github.com/jiaxuanleong/SPIRO.Assays/tree/master/preprocessing">Preprocessed imaging data</a>
- [R](https://www.r-project.org/)
- [R Studio](https://www.rstudio.com/) 
- [Git](https://git-scm.com/downloads) 
- R packages:
  - dplyr
  - ggplot2
  - zoo
  - readr
  - doParallel
  - foreach
  - doRNG


## Implementation

Detailed instructions are avilable in the Root growth assay manual



## Troubleshooting
- For troubleshooting please refer to this <a href="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/Root%20growth%20assay%20troubleshooting.md">table</a>
- If you encounter an error not listed in the table, please submit a report as a github issue. We will address it ASAP.
