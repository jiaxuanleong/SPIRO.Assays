
These two assays were developed for high-throughput analysis of data acquired by [SPIRO](https://www.alyonaminina.org/spiro), smart plate imaging robot. The assay were optimized for imaging <i>Arabidopsis thaliana</i> seeds and seedlings, but can be optimized for other species. 


Each assay comprises three major steps:
1. Image processing using ImageJ macro SPIRO_Registration
2. Image analysis using ImageJ macro SPIRO_Germination or SPIRO_RootGrowth
3. Data analysis using R scripts Germination or RootGrowth



[**SPIRO_Registration**](https://github.com/jiaxuanleong/spiro-IJmacros/blob/master/SPIRO_Registration) macro (ImageJ Macro Language):
This macro will process all four folders of a SPIRO experiment.

- combining separate images into one time-lapse stack file
- setting the scale
- resizing the stack by cropping off edges
- correcting for image drift


[**SPIRO_Germination**](https://github.com/jiaxuanleong/spiro-IJmacros/blob/master/SPIRO_Germination) macro (ImageJ Macro Language):
This macro will analyze all four folders of a SPIRO experiment using data processed by the SPIRO_Registration macro

- defining a range of time points that will be included into analysis
- selecting groups of seeds that will be analyzed together, e.g. the same genotype
- processing of images to identify seed positions 
- measurement of square and perimeter of each seed at each time point
- creating a time-lapse stack file illustrating quality of seed recognition for each group
- Results are saved as a tab-delimited text file to be processed using [R scripts Germination](https://github.com/jiaxuanleong/spiro-IJmacros/tree/master/germination).

[**R scripts_Germination**](https://github.com/jiaxuanleong/spiro-IJmacros/blob/master/SPIRO_Germination):
The script will analyze data from all four folders of a SPIRO experiment processed by the SPIRO_Germination macro

- quality control to remove any objects that were mistakingly recognized as seeds
- results are saved in tab-delimited output.txt file
- data processing to determine time of germination for each seed
- statistical analysis to determine the time at which 50% of seed germinated and to compare user-defined groups
- results are saved in tab-delimited text files


[**SPIRO_RootGrowth**](https://github.com/jiaxuanleong/spiro-IJmacros/blob/master/SPIRO_RootGrowth) macro (ImageJ Macro Language):
This macro will analyze all four folders of a SPIRO experiment using data processed by the SPIRO_Registration macro

- defining a range of time points that will be included into analysis
- selecting groups of seedlings that will be analyzed together, e.g. the same genotype
- processing of images to identify seedling positions 
- measurement of primary root length for each seed at each time point
- creating a time-lapse stack file illustrating quality of root recognition for each group
- Results are saved as a tab-delimited text file to be processed using [R scripts Germination](https://github.com/jiaxuanleong/spiro-IJmacros/tree/master/).

[**R scripts_RootGrowth**](https://github.com/jiaxuanleong/spiro-IJmacros/blob/master/):
The script will analyze data from all four folders of a SPIRO experiment processed by the SPIRO_RootGrowth macro

- quality control to remove any objects that were mistakingly recognized as primary roots
- results are saved in tab-delimited output.txt file
- data processing to determine root length for each seedling at each time point
- statistical analysis to determine the average rooth growth speed for each group
- results are saved in tab-delimited text files



<b>Installation</b>

To use maro:
- Download the macro (.ijm file)
- Open ImageJ
- Go to Plugins-> Macro-> Open->Find the downloded macro file

To use R scripts:
- Open Rstudio
- File-> NewProject -> Version Control -> Git-> repository URL: https://github.com/jiaxuanleong/spiro-IJmacros 



<b>Requirements</b>

- [ImageJ v1.52p](https://imagej.net/Fiji/Downloads)
- [MultiStackReg](http://bradbusse.net/sciencedownloads.html)
- RStudio v...
- R packages......
