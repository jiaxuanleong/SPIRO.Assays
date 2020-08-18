<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Hardware%20files/SPIRO%20logo.png?raw=true" height="50" title="SPIRO"><br>
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/SPIRO%20text%20logo.png?raw=true" width="200" title="SPIRO">
</p>

<p align="center">
    <b>S</b>mart <b>P</b>late <b>I</b>maging <b>Ro</b>bot semi-automated assays
</p>

<br>
<br>
The seed germination and root growth assays were developed for high-throughput analysis of data acquired by <a href="https://www.alyonaminina.org/spiro">SPIRO</a> and optimized for the typical plant model organism, <i>Arabidopsis thaliana</i>, but can be tuned for other species. 
<br>
<br>

Each assay comprises of three major steps. <b>Detailed information is provided in the corresponding folders of the repository</b>:
<ol>
 <li>Raw data preprocessing using the ImageJ macro <a href="https://github.com/jiaxuanleong/SPIRO.Assays/tree/master/preprocessing">SPIRO_Preprocessing</a></li>
<li>Image analysis using the ImageJ macro <a href="https://github.com/jiaxuanleong/SPIRO.Assays/tree/master/germination">SPIRO_Germination</a> or <a href="https://github.com/jiaxuanleong/SPIRO.Assays/tree/master/rootgrowth">SPIRO_RootGrowth</a></li>
<li>Quality control and anslysis of the quantitative data using the accompanying R scripts</li>
</ol> 
<br>
<br>
<p align="center">
  <img src="https://github.com/AlyonaMinina/Files_for_SPIRO_reps/blob/master/SPIRO.Assays%20files/spiro-assays-v1-resized.gif?raw=true" title="SPIRO">

<b>Figure1.</b> SPIRO semi-automated assays require preprocessing of the raw data to create 8-bit time-lapse stack files with scale set in cm. The preprocessed data can than be used either for seed germination or for root growth assay.


