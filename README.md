<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/SPIRO%20text%20logo.png?raw=true" title="SPIRO Assays">
</p>

This repository contains automated high-throughput analysis pipelines for seed germination and root growth, optimized for the typical plant model organism *Arabidopsis thaliana*. The pipelines were developed for use with [SPIRO](https://github.com/jonasoh/spiro). 

Each assay comprises three major steps:
* Raw data preprocessing (ImageJ macro)
* Image analysis (ImageJ macro)
* Quality control and statistical analysis (R scripts)

An overview of the separate analysis steps is provided below. A detailed manual will be provided soon.

# Image preprocessing

The first step in either of the SPIRO assays is preprocessing of the raw data. It is used for:
* Creating a time-lapse file for each analysed Petri plate
* Setting scale in cm
* Reducing file size by cropping off unnecessary background in images
* Converting images to 8-bit to facilitate further segmentation
* If needed, correcting for accidental drift during cube rotation

# Seed germination assay

<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/germination%20v1-resized.gif?raw=true" title="Germination assay overview">
</p>

The seed germination assay was designed for analysis of *Arabidopsis thaliana* germination, although it can be tweaked for use with other species. Germination detection is accomplished through measuring the perimeter of each seed over time, and groups are compared using the Kaplan–Meier test. Complete details will be available in the assay manual.

# Root growth assay

<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/root-grwoth-v1-resized.gif?raw=true" title="Root growth overview">
</p>

The root growth assay measures primarily root length, and uses a mixed model to assess differences between groups. Complete details will be available in the assay manual.

# SPIRO Assay Customizer

<p align="center">
  <img src="https://user-images.githubusercontent.com/6480370/86357062-ce289280-bc5c-11ea-816f-a656977b224c.png" alt="SPIRO Assay Customizer" width=602>
</p>

The [SPIRO Assay Customizer](https://github.com/jonasoh/spiro-assay-customizer) is a companion tool for SPIRO Assays, which allows customizing assays in several ways (e.g., merging experiments, rearranging groups, etc). Its use is optional but recommended. 

# Troubleshooting

Some common errors and workarounds have been summarized in these tables:
* [Preprocessing troubleshooting](https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/Preprocessing%20troubleshooting.md)
* [Germination assay troubleshooting](https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/Germination%20assay%20troubleshooting.md)
* [Root growth assay troubleshooting](https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/Root%20growth%20assay%20troubleshooting.md)
