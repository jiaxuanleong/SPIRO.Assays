
<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Hardware%20files/SPIRO%20logo.jpg?raw=true" height="50" title="SPIRO">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/SPIRO%20text%20logo.png?raw=true" width="200" title="SPIRO">
</p>

## Root growth assay</b>
<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/root-grwoth-v1-resized.gif?raw=true" height="200" title="SPIRO">
<br>

This semi-automated assay is designed to analyze root growth using data acquired by <a href="https://www.alyonaminina.org/spiro">SPIRO</a>. It was optimized for the typical plant model organism,<i> Arabidopsis thaliana</i>, but can be tuned for other plant species. 

The assay comprises of automated image analysis using SPIRO_RootGrowth macro, quantitative data quality control followed by root growth measurement and statistical analysis using corresponding R scripts. An overview of the assay and quick instructions are provided in the text below, for the detailed instructions, please refer to the <b>SPIRO root growth assay manual.</b>


## SPIRO_RootGrowth macro

The macro contains three user-guided steps that enable implementation of the assay for a broad range of experiments with various layouts.
The analysis allows the user to select a subset of time range to be used for the root growth analysis. This feature is not crucial for the assay <i>per se</i> as it does not affect the output result, but it reduces requirement for RAM during image segmentation, thus enabling use of the macro even on shitty computers. Please note, that the assay relies on having at least one time point with ungerminated seeds being included into the analyzed data. 
The user will be also asked to indicate groups of seedlings, e.g. different genotypes and/or treatments. This step is crucial for downstream statistical analysis of the quantitative data. If needed, grouping can be manually modified after data quality control to enable different comparisons without re-running image analysis. 
Finally the user will be asked to manually remove any objects that were misidentified as seeds of seedlings to be analyzed. This step allows excluding accidental imperfections in the growth medium that might look very similar to seeds, and also allows the user to exclude any seedlings from analysis (e.g. due to abnormal growth, seedlings overlapping with adjacent seedlings or reflections in media visible after segmentation). 
After these user guided steps, the macro will automatically process data for all groups present in the experiment folder and produce three output files for each group of seedlings:
- `group name.tiff` contains selection of the corresponding group cropped from the original image stack
- `group name rootgrowthdetection.tiff` is the graphical output of the macro. It contains time-lapse side by side comparison of original images with marked root start identified for each seedling at each time point and corresponding segmented images showing detected roots. This information can be helpful to verify that image processing indeed identified roots correctly.
- `group name rootgrowthmeasurement.tsv` is the quantitative output of the macro, it contains root length data for each seedling at each time point.<br>
For each group these files will be saved in the experiment folder: ` Experiment name/Results/Root Growth/plate<i>n</i>/group name`

<b> Requirements and implementation</b>:
- [Fiji](https://imagej.net/Fiji/Downloads) = ImageJ + default plugins. The macro was developed using v1.52p
- <a href="https://github.com/jiaxuanleong/SPIRO.Assays/tree/master/preprocessing">Preprocessed imaging data</a> generated in the preceeding step
- Open Fiji
- In the top menu find Plugins -> Macros -> Run -> locate and open `SPIRO_RootGrowth.ijm` file in the SPIRO.Assays folder downloaded during the previous step
- Follow the instructions provided by the macro


## R scripts

Quantitative data processsing is done in two steps. Firstly, data is put through quality control (QC) using `consolidate_rootgrowth_data.R`. This step will produce plots of root length vs absolute and normalized time for each seedling and rootgrowth.postQC.tsv file with quantitative macro output data that passed quality control. <b>Importantly, in this file you can modify group names if you wish to perform different grouping for statistical analysis</b>. Normalized time represents elapsed time since the detected start of root growth.
After QC, cleaned data can be fed into `process_rootgrowth_data.R` for building of root growth trends for each group and  perform statistical analysis. Analysis can be performed several times on the same experiment, each analysis will be saved in a separate subfolder. The analysis produces four types of output files:
1. `modelfits.tsv`containing results of the statistical analysis comparing trend curves for all groups to the user-selected control group
2. `coefficients.tsv`contains <b>jonas the fuck is significance of this? elaborate please</b>
3. `rootgrowth-allgroups.pdf`contains plot with raw data points and growth trend curves for all groups
4. `rootgrowth-group name.pdf`contains plot with raw data points and growth trend curves for each group compared to the user-selected control group

<b> Requirements and implementation</b>:
- Download and install [R](https://www.r-project.org/)
- Download and install [R Studio](https://www.rstudio.com/) and [Git](https://git-scm.com/downloads) (sic! make sure that Git is enabled)
- Create a project using version control tool that will allow easy download of updates:
 In the top menu go to File -> New project -> Version control -> Git -> Select a suitable directory location for the project and copy paste the repository URL: `https://github.com/jiaxuanleong/SPIRO.Assays`. 
- run `consolidate_rootgrowth_data.R`( click on the corresponding file name in the right bottom panel of R studio)
- Point the script to the experiment folder: in the top menu find Code -> Source-> Select your experiment folder. For Windows users it can be done via file picker (please note, that RStudio conveniently places it behind the RStudio window). For Mac OS users, right click on your experiment folder and hold `Alt` key to enable the "copy path to the directory" option, then copy paste the path to your experiment folder in the console of the R studio.
- Quantitative output  of the QC step is saved in the experiment folder: `Experiment name/Results/Root Growth/rootgrowth.postQC.tsv`. The plots with absolute and dnormalized root growth curves can be found in the folder `Pre-analysis`
- If needed, manually modify group names in the `rootgrowth.postQC.tsv` file by using, for example, find/replace function in Excel
- Run `process_rootgrowth_data.R`
- Point the script to the experiment folder
- Results of the analysis step are saved in the experiment folder: `Experiment name/Results/oot Growth/Analysis output/number of the analysis.` File `rootgrowth.postQC.tsv` is also saved into analysis folder to preserve the group names used for this particular analysis.


## Troubleshooting
- For troubleshooting please refer to this <a href="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/Root%20growth%20assay%20troubleshooting.md">table</a>
- If you encounter an error not listed in the table, please submit a report as a github issue. We will address it ASAP.
