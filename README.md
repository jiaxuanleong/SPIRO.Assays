ImageJ macros for the analysis of data acquired by [SPIRO](https://github.com/jonasoh/spiro), an imaging platform for biological samples.

**SPIRO_Registration**
The images acquired through SPIRO is converted into a stack. User is prompted to set scale using the scale bar in the image. The stack is
then cropped to remove irrelevant background for faster processing. Once this is done registration using [MultiStackReg](http://bradbusse.net/sciencedownloads.html) is done to reduce any drift during acquisition of images. A Z-projection is created to allow 
easy validation of registration.

**SPIRO_Germination**
This macro allows measurement of germination rate of seeds. User is prompted to select the range of images to analyze, as image acquisition 
in some experiments could include time points past germination of all seeds. A substack is made from this range of images and saved in the
same subfolder. User is prompted to select and name the lines/genotypes of seeds using ROI selection. These will be cropped and saved under 
named folders for easy analysis.

The images are thresholded and made binary, and some processing is done to remove background noise. Seed positions are determined and the 
"Analyze Particles" command used to measure seed characteristics. The original and processed stacks are merged, together with annotated file
name containing plate, date and time info. Results are saved as a tab-delimited text file. This will be processed in R.

**SPIRO_RootGrowth**
This macro allows measurement of root growth. User is prompted to select the range of images to analyze, as image acquisition in some 
experiments could include time points before germination of seed occurs. A substack is made from this range of images and saved in the
same subfolder. User is prompted to select and name the lines/genotypes of seeds using ROI selection. These will be cropped and saved under 
named folders for easy analysis.

The images are thresholded and made binary, and some processing is done to remove background noise. The roots are skeletonized and the
"Analyze Skeleton (2D/3D)" command is used to measure root length. The original and processed stacks are merged, together with annotated file
name containing plate, date and time info. Results are saved as a tab-delimited text file. This will be processed in R.
