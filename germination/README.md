# Automatic germination assessment

This pipeline will automatically detect germination in a set of images
captured using [SPIRO](https://github.com/jonasoh/spiro).

## ImageJ macro

## R scripts

The R scripts consist of two parts: a quality control script
(`cleanup_germination_data.R`) and a script that runs the germination
determination algorithm and outputs some statistics and nice graphs.

To use the scripts, first install the required packages:

```
install.packages(c('dplyr', 'reshape2', 'devtools', 'zoo'))
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
