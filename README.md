<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/SPIRO%20text%20logo.png?raw=true" height="80" title="SPIRO Assays">
<br/>
<p align="center"> <b>S</b>mart <b>P</b>late <b>I</b>maging <b>Ro</b>bot semi-automated assays</p>

This repository contains ImageJ macro, R scripts and detailed manual (will be uploaded soon!) for semi-automated high-throughput image analyses developed for SPIRO seed germination and root growth assays. Both assays were optimized for the typical plant model organism *Arabidopsis thaliana* and data acquired using [SPIRO](https://github.com/jonasoh/spiro). 

Each assay comprises three major steps:
* Raw data preprocessing (ImageJ macro)
* Image analysis (ImageJ macro)
* Quality control and statistical analysis (R scripts, SPIRO assay customizer)
<br/>


<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/spiro-assays-v1-resized-v2.gif" height="400" title="SPIRO assays overview">
</p>


<b>Figure1.</b> SPIRO semi-automated assays require preprocessing of the raw data to create 8-bit time-lapse stack files with scale set in cm. The preprocessed data can than be used either for seed germination or for root growth assay.


# Image preprocessing
<img align="right" width="600" src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/preprocessing-v2%20flat.png" alt="Preprocessing  overview">

The first step in either of the SPIRO assays is preprocessing of the raw data. **It is used for**:
* Creating a time-lapse file for each analysed Petri plate
* Setting scale in cm
* Reducing file size by cropping off unnecessary background in images
* Converting RGB images into greyscale 8-bit to facilitate further segmentation
* If needed, correcting for accidental drift of object during imaging

<br/>


# SPIRO Seed Germination Assay

<img align="right" width="600" src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/germination%20v2%20flat.png" alt="SPIRO Germination assay overview">

This assay was designed for *Arabidopsis thaliana* seed germination analysis by detecting the time point, starting from which the seed perimeter shows a stable increase.

**The assay comprises several steps**:
* Preprocessed data is used to select groups of seeds and define the desired time range for analysis (ImageJ macro)
* The perimeters and area of each seed is recorded at each time point (ImageJ macro)
* The data is data is than subjected to quality control (R script)
* The data can be optionally adjusted using SPIRO assay customizer that enables relabeling and regrouping of samples
* The data that passed QC is processed further to determine germination time point for each seed based on dynamics of its perimeter changes (R script)
<br/>

**The results of the assay comprise**:
* Germination time point for each seed
* Size of each seed
* Statistics for germination of each user-selected group of seeds (based on [Germinationmetrics]( https://cran.r-project.org/web/packages/germinationmetrics/index.html))
* Kaplan-Meier plots for pairwaise comparison of germination in groups 
* T-test comparing seed sizes for all groups
<br/>



# SPIRO Root Growth Assay

<img align="right" width="600" src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/root-grwoth-v2%20flat.png" alt="SPIRO Root Growth assay overview">

This assay allows to track primary root length and rate of its growth for indivual seedlings and groups of seedlings. The priamry root growth is tracked starting from the germination time point and statistical comprison of root growth between groups is performed using a mixed model. 

**The assay comprises several steps**:
* Preprocessed data is used to select groups of seeds and define the desired time range for analysis (ImageJ macro)
* The perimiters and area of each seed is recorded at each time point (ImageJ macro)
* The primary root length is recorded for each seedling at each time point (ImageJ macro)
* Germination time point is detected for each seed (R script)
* The primary root length data is normalized to the germination time point and subjected to quality control (R script)
* The data can be optionally adjusted using SPIRO assay customizer that enables relabeling and regrouping of samples
* data that passed QC is processed further to plot root length vs time for each seedling and for groups of seedlings and to perform statistical analysis (R script)
<br/>

**The results of the assay comprise**:
* Root length for each seedling at each time point
* Bar charts representing average root length for each group of seedlings detected at 24h intervals
* Bar charts representing root growth rate for each group of seedlings detected at 24h intervals
* Plots visualizing the model prediction of the root growth for each group
* Plot with raw root lenght vs time for each seedling of a group 
* Plot with root length of each seedling normalized to the corresponding germiantion time
* Results of statistical analysis comparing root growth between groups 

<br/>



# SPIRO Assay DEBUG mode

DEBUG mode can be enabled at the start of each assay by holding down the CTRL key.

**Preprocessing**
* Batch size during drift correction may be lowered for reduced lower RAM requirement

  Application: Drift correction for large datasets (e.g. more than 200 time points) can take up a lot of RAM. This may cause ImageJ to freeze up when its allocated RAM is too low, thus images are drift-corrected in batches. If the default batch size of 350 is still causing ImageJ to freeze up on your computer, you may reduce this number e.g. to 100, when the macro prompts you to do so.

**Seed Germination Assay**:
* Seed detection parameters i.e. area and circularity may be modified

  Application: The default seed detection parameters were optimized using typical Arabidopsis thaliana seeds. If your seeds do not fit the default parameters, the expected area and circularity may be modified when the appropriate dialog box appears during macro run in the debug mode.  The area and circularity of your seeds can be estimated manually in ImageJ using the same thresholding as in the macro.

  **! Changes in the allowed area size must be also introduced into downstream R germination QC R script to allow correct data filtering. For this, please change the variables `upper_area_threshold` and `lower_area_threshold` in `cleanup_germination_data.R`.**


**Root growth Assay**:
* Seed detection parameters i.e. area and circularity can be modified

  Application: see above in “Germination Assay”

* Overlay skeletons can be enabled

  Application: Lighting conditions may affect image capture and cause some roots to look translucent, which makes it difficult for the thresholding methods to distinguish roots from growth media. As the result, on some time frames detected roots might have gaps in their outlines. To overcome this, we introduced the “Overlay Skeletons” function which superimposes roots from one time point to the next, thus filling in potential gaps. However, this function might increase background noise.

* Non-essential intermediate output files will not be deleted at the end of the run.

  Application: If the results of root length macro do not make sense, the intermediate files are useful for troubleshooting root masking and root start coordinates.

<br/>



# SPIRO Assay Customizer
<img align="right" width="400" src="https://user-images.githubusercontent.com/6480370/86357062-ce289280-bc5c-11ea-816f-a656977b224c.png" alt="SPIRO Assay Customizer">


The [SPIRO Assay Customizer](https://github.com/jonasoh/spiro-assay-customizer) is a companion tool for SPIRO Assays, which enables a more user friendly handling data rearrangment while running SPIRO assays. Its use is optional but recommended. 

**The Customizer provides an intuitive user interface for**:
* merging data from several experiments
* relabeling samples or groups of samples
* removing samples or groups of samples from analysis
* reshuffling samples between groups

<br/>

# Troubleshooting

Some common errors and workarounds have been summarized in these tables:
* [Preprocessing troubleshooting](https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/Preprocessing%20troubleshooting.md)
* [Germination assay troubleshooting](https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/Germination%20assay%20troubleshooting.md)
* [Root growth assay troubleshooting](https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/Root%20growth%20assay%20troubleshooting.md)
