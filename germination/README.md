
<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Hardware%20files/SPIRO%20logo.jpg?raw=true" height="50" title="SPIRO">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/SPIRO%20text%20logo.png?raw=true" width="200" title="SPIRO">
</p>

## Seed germination assay
<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/germination%20v1-resized.gif?raw=true" height="200" title="SPIRO">
<br>

This semi-automated assay is designed to analyze seed germination using data acquired by <a href="https://www.alyonaminina.org/spiro">SPIRO</a>. It was optimized for the typical plant model organism,<i> Arabidopsis thaliana</i>, but can be tuned for other plant species. 

The assay comprises of automated image analysis using `SPIRO_Germination macro`,  data quality control performed by  `cleanup_germination_data.R` and followed by germination detection and statistical analysis using `process_germination_data.R`.  The assay also provides data on the seed size and statistical analysis for it.


##  Requirements
- [Fiji](https://imagej.net/Fiji/Downloads) = ImageJ + default plugins. The macro was developed using v1.52p
- <a href="https://github.com/jiaxuanleong/SPIRO.Assays/tree/master/preprocessing">Preprocessed imaging data</a>
- [R](https://www.r-project.org/)
- [R Studio](https://www.rstudio.com/) and [Git](https://git-scm.com/downloads) (sic! make sure that Git is enabled)
- R packages:
  - dplyr
  - reshape2
  - devtools
  - zoo
  - doParallel
  - foreach
  - ggplot2
  - survival
  - survminer
  - the development version of germinationmetrics

## Implementation
Detailed instructions are avilable in the Germination assay manual

## Troubleshooting
- For troubleshooting please refer to this <a href="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/Germination%20assay%20troubleshooting.md">table</a>
- If you encounter an error not listed in the table, please submit a report as a github issue. We will address it ASAP.
