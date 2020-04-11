
<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Hardware%20files/SPIRO%20logo.jpg?raw=true" height="50" title="SPIRO">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/SPIRO%20text%20logo.png?raw=true" width="200" title="SPIRO">
</p>

## Seed germination assay</b>
<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/germination%20v1-resized.gif?raw=true" height="200" title="SPIRO">
<br>

This semi-automated assay is designed to analyze seed germiantion using data acuired by <a href="https://www.alyonaminina.org/spiro">SPIRO</a>. It was optmized for the typical plant model organism,<i> Arabidopsis thaliana</i>, but can be potentially fine-tuned to be used for other plant species. 

The assay comprises automated image analysis using SPIRO_Germination macro, quantitative data quality control followed by germination detection and statistical analysis using corresponding R scripts.


## Requirements

- [Fiji](https://imagej.net/Fiji/Downloads) (will be installed for the preeceding step of <a href="https://github.com/jiaxuanleong/SPIRO.Assays/tree/master/preprocessing">data preprocessing</a>)
- <a href="https://github.com/jiaxuanleong/SPIRO.Assays/tree/master/preprocessing">Preprocessed imaging data</a>
- [R](https://www.r-project.org/)
- [R Studio](https://www.rstudio.com/) and [Git](https://git-scm.com/downloads) (not necessary, but highly recommended. sic! make sure that Git is enabled)
- Required R packages are specified below


## SPIRO Germination macro

The macro contains several user-guided steps that enable implementation of the assay for a broad range of expereimetns with various layouts.
The analysis allows user to select a subset time range to be used for the germination analysis. This feature is not crucial for the assay <i>per se</i>, but it reduces requirement for RAM during image segmentation, thus enabling use of the macro even on shitty computers. 
The user will be also asked to indicate groups of seeds, e.g. different genotypes and/or treatments. This step is crucial for downstream statistical analysis of the quantitative data. If needed, grouping can be additionally manually modified after data qulaity control to enable different comparisons without reruning image analysis. 
The macro will produce two output files for each analyzed group of seeds:
- graphical output is a time-lapse stack .tiff file containing photographs of seeds and the results of their identification by 

- Open Fiji
- In the top menu find Plugins-> Macro-> Open -> locate and open the downloded SPIRO_Germination.ijm file
- Follow the instrucitons provided by the macro


## R scripts

The R scripts consist of two parts: a quality control script
(`cleanup_germination_data.R`) and a script that runs the germination
determination algorithm and outputs some statistics and nice graphs.

To use the scripts, first install the required packages:

```
install.packages(c('dplyr', 'reshape2', 'devtools', 'zoo', 'doParallel',
                   'foreach', 'ggplot2', 'survival', 'survminer'))
# we need the development version of germinationmetrics:
devtools::install_github("aravind-j/germinationmetrics")
```

Then, run the `cleanup_germination_data.R` script and select the folder
containing the output from the ImageJ macro. The script will process the
data and remove problematic seeds. After it is done, it will produce a file
called `output.tsv` in the main data directory. *Edit this file and set the
correct groups, e.g. by using Find/Replace!*

After making sure that the groups in `output.tsv` are correct, run
`process_data.R`. Point the script to the folder where the `output.tsv` file
is located. After a little while, the script will output t50, and mean
germination time (+SE) to a file called `germinationstats.tsv`. Germination
times and TIFF frame numbers for all seeds will be written to the file
`germination-perseed.tsv`. Finally, a germination graph with some metrics
indicated will be written for each group, named
`germinationplot-*GROUP*.pdf`.

## Troubleshooting
- For troubleshooting please refer to this <a href="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/Preprocessing%20troubleshooting.md">table</a>
- If you encounter error not listed in the table, please submit a report as a github issue. We will address it asap.
