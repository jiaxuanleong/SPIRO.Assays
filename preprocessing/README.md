<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Hardware%20files/SPIRO%20logo.jpg?raw=true" height="50" title="SPIRO">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/SPIRO%20text%20logo.png?raw=true" width="200" title="SPIRO">
</p>

## Preprocessing</b>
<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/preprocessing-v2-reduced-size.gif?raw=true" height="200" title="SPIRO">
<br>

The first step in either of the SPIRO assays is preprocessing of the raw data. It is used for:
- Creating a time-lapse file for each analysed Petri plate
- Setting scale in cm
- Reducing file size by cropping off unnecessary background in images
- Converting images to 8-bit to facilitate further segmentation
- If needed, correcting for accidental drift during cube rotation

The preprocessed data for each Petri plate will be saved in the experiment folder: <p>
  Experiment name/Results/Preprocessing/plate<i>n</i>/plate<i>n</i>_preprocessed.tiff




## Requirements

- [Fiji](https://imagej.net/Fiji/Downloads) = ImageJ + default plugins. The macro was developed using v1.52p
- [TurboReg](http://bigwww.epfl.ch/thevenaz/turboreg/)
- [MultiStackReg](http://bradbusse.net/downloads.html)
- Raw imaging data acquired using <a href="https://www.alyonaminina.org/spiro">SPIRO</a>

## Implementation

- Download and install Fiji and two plugins listed above
- Download or clone the <a href="https://github.com/jiaxuanleong/SPIRO.Assays">SPIRO.Assays</a> repository 
- Open Fiji
- In the top menu find Plugins-> Macro-> Open -> locate and open the downloded SPIRO_Preprocessing.ijm file
- Follow the instructions provided by the macro
- To reduce RAM requirement we implement a batch mode, meaning that only a subset of images is processed at each step, macro will eventually process all images present in the experiment folder. The default size of batch is set to 350 images, but can be adjusted to accomodate for shitty or super fast computers (for more info see the troubleshooting <a href="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/Preprocessing%20troubleshooting.md">table</a>).

## Troubleshooting
- For troubleshooting please refer to this <a href="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/Preprocessing%20troubleshooting.md">table</a>
- If you encounter an error not listed in the table, please submit a report as a github issue. We will address it ASAP.
