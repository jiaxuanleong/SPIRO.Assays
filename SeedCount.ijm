//requirements for file organization
//main directory containing all images sorted by plate into subdirectories
//requirements for image naming
//plate1-date20190101-time000000-day

//user selection of main directory
maindir = getDirectory("Choose a Directory ");
list = getFileList(maindir);
processMain(maindir);

///set up recursive processing of a main directory which contains multiple subdirectories   
function processMain(maindir) {
	 
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/")) {
			subdir = maindir+list[i];
			sublist = getFileList(subdir);
			setBatchMode(false);
			open(subdir+sublist[0]);
			processSub(subdir);
		}
	}
}

//analyse files by first setting the scale (once), cropping plates then counting seeds
function processSub (subdir) {
	if (i==0) {
	scale();
	}
	cropPlate();
	countSeeds();
	print(subdir + " processed.");
};

//prompts user to draw a line to set scale globally
//then saves the scale as a text file
function scale () {
	print("Setting scale...");
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel global");
	setTool("line");
	waitForUser("Draw a line corresponding to 1cm. Zoom in on the scale bar and hold the SHIFT key down.");
	run("Measure");
	length = getResult('Length', nResults-1);
	while (length==0 || isNaN(length)) {
        waitForUser("Line selection required");
        run("Measure");
		length = getResult('Length', nResults-1);
	};
	waitForUser("1cm corresponds to " + length + " pixels. Click OK if correct.");
	run("Set Scale...","known=10 unit=mm global");
	print("\\Clear");
	print("Your scale is " + length + " pixels to 1cm.");
	selectWindow("Log");
	saveAs("Text", maindir+"Scale "+length);
	selectWindow("Results");
	run("Close");
};

//prompts user to determine line positions, then crops these out as individual tiffs
//crops are saved under a newly created subfolder "cropped"
function cropPlate () {
	if (i == 0) {
	run("ROI Manager...");
	setTool("Rectangle");
	linenos = roiManager("count");
	while (linenos <= 0) {
		waitForUser("Select each line and add to ROI manager. ROI names will be saved.");
		linenos = roiManager("count");
	}
	waitForUser(linenos + " lines have been selected. Press OK if correct. Edit now if incorrect.");
	run("Select None");
	
	}
	print("Cropping plates...");
 
	outcrop = subdir + "/cropped/";
	File.makeDirectory(outcrop);
	
	//first loop enables batch processing of all in subdirectory
	//if statement causes non-experiment files to be ignored
	//second loop enables cropping of ROI(s) followed by saving of cropped image
	//roi names cannot contain dashes due to split() to extract information from file name later on
	setBatchMode(true);
	close();
	for (y = 0; y < sublist.length; ++y) { 
	open(subdir+sublist[y]);
		if (indexOf(getTitle(), "plate")>=0) {		
			for (x=0; x<linenos; ++x) {
    			run("Duplicate..."," ");
    			roiManager("Select", x);
    			roinamecheck = Roi.getName;
    			if (indexOf(roinamecheck, "-") > 0) {
    				waitForUser("ROI names cannot contain dashes '-'!");
    				roinamecheck = Roi.getName;
    			}
    			roiname = Roi.getName+"-";
    			linefolder = outcrop + "/"+roiname+"/";
    			if (y==0){
    				File.makeDirectory(linefolder);
    				}
    			run("Crop");
    			saveAs("Tiff", linefolder+roiname+File.nameWithoutExtension+".tif");
    			close();
			};
			close();
		};
	};
};
//processes images then runs particle analysis 
//counted outlines are saved as an image under a newly created folder "outline"
//output data is saved as a text file
function countSeeds () {;
		linenos = roiManager("count");
		outcrop = subdir + "/cropped/";
		for (y=0; y<linenos; y++) { 
			croplist = getFileList(outcrop);
			linedir = outcrop+croplist[y];
			linedirlist = getFileList(linedir);
			
			print("Counting seeds for "+croplist[y]+"...");
	
			for (z=0; z<linedirlist.length; z++) {
				open(linedir+linedirlist[z]);
				seedMask();
				multiMeasure();
				close();
				close();
				}
			selectWindow("Round Summary");
			folder = croplist[y];
			slash = indexOf(folder, "/");
			foldername = substring(folder, 0, slash);
			saveAs("Text", linedir+"Round Summary for "+foldername+".txt");
	}
}

//creates a binary mask and reduces noise
function seedMask() {
	run("Subtract Background...", "rolling=30 sliding");
	run("8-bit");
	setAutoThreshold("Minimum dark");
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Set Measurements...", "  redirect=None decimal=3");
	run("Analyze Particles...", "size=0.1-Infinity circularity=0-1.00 show=Masks summarize");
	selectWindow("Summary");
	run("Close");
	}

function multiMeasure() {
	run("Rotate 90 Degrees Right");
	if (roiManager("count")>0) {
	roiManager("Deselect");
	roiManager("Delete");
	}
	run("Create Selection");
	roiManager("Add");
	roiManager("Select", 0);
	roiManager("Split");
	roiManager("Select", 0);
	roiManager("Delete");
	roicount = roiManager("count");
	roiarray = newArray(roicount);
	for (x=0; x<roicount; x++) {
	roiarray[x] = x;
	}
	roiManager("Select", roiarray);
	run("Set Measurements...", "area shape redirect=None decimal=3");
	roiManager("multi-measure measure_all");
	roiManager("Deselect");
	columnName="T"+z;
	selectWindow("Results");
	array=Table.getColumn("Round");

	if (z == 0) {
		Table.create("Round Summary");
	}	else {
	selectWindow("Round Summary");
	}	
	Table.setColumn(columnName, array);
	Table.update;
}

//reduces resuls of particle analysis to just "Count"
//adds Genotype, Date, Time to results table based on file name
function extractLabel() {
	geno = newArray(nR);
	date = newArray(nR);
	time = newArray(nR);

	for (y=0; y<nR; y++){
	label = Table.getString("Label", y)
	part = split(label, "-");
	geno = part[1];
	date = part[3];
	time = part[4]; 
	Table.set("Genotype", y);
	Table.set("Date", y);
	Table.set("Time", y);
	}
}
	
