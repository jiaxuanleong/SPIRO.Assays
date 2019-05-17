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
	run("Set Scale...","known=1 unit=cm global");
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
	while (roiManager("count") <= 0) {
		waitForUser("Select each line and add to ROI manager. ROI names will be saved.");
	};
	waitForUser(roiManager("count") + " lines have been selected. Press OK if correct. Edit now if incorrect.");
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
	for (y = 0; y < sublist.length; ++y) { 

		if (indexOf(getTitle(), "plate")>=0) {		
			for (x=0; x<roiManager("count"); ++x) {
    			run("Duplicate..."," ");
    			roiManager("Select", x);
    			roinamecheck = Roi.getName;
    			if (indexOf(roinamecheck, "-") > 0) {
    				waitForUser("ROI names cannot contain dashes '-'!");
    				roinamecheck = Roi.getName;
    			}
    			roiname = Roi.getName+"-";
    			run("Crop");
    			saveAs("Tiff", outcrop+roiname+File.nameWithoutExtension+"_cropped"+".tif");
    			close();
			};
		};
	run("Open Next");
	};
close();
};

//processes images then runs particle analysis 
//counted outlines are saved as an image under a newly created folder "outline"
//output data is saved as a text file
function countSeeds () {;
	print("Counting seeds...");
	outcrop = subdir + "/cropped/" ;
	croplist = getFileList(outcrop);
	open(outcrop+croplist[0]);
	outline = subdir + "/outline/";
	File.makeDirectory(outline); 

	setBatchMode(true);
	for (y = 0; y < croplist.length; ++y) {
		seedMask();
		run("Set Measurements...", "  redirect=None decimal=3");
		run("Analyze Particles...", "size=0.001-0.008 circularity=0.8-1.00 show=Outlines summarize");
		saveAs("Tiff", outline+File.nameWithoutExtension+"_outline"+".tif");
		close();
		close();
		run("Open Next");
		};
	setBatchMode(false);
	close();
	//save summary of particle analysis
	resultPA();
	folder = list[i];
	slash = indexOf(folder, "/");
	foldername = substring(folder, 0, slash);
	saveAs("Text", subdir+"Seed Count for "+foldername+".txt");
	run("Close");
};

//creates a binary mask and reduces noise
function seedMask() {
	run("Duplicate..."," ");		
	run("8-bit");
	setAutoThreshold("MaxEntropy dark");
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Median...", "radius=4");
	run("Open");
	run("Close-");
}

//reduces resuls of particle analysis to just "Count"
//adds Genotype, Date, Time to results table based on file name
function resultPA() {
	IJ.renameResults("Summary", "Results");
	Table.deleteColumn("Total Area");
	Table.deleteColumn("Average Size");
	Table.deleteColumn("%Area");
	Table.update;
	
	nR = nResults;
	geno = newArray(nR);
	date = newArray(nR);
	time = newArray(nR);
	
	for (v=0; v<nR;v++) {
		resLabel = getResultString("Slice", v);
		part = split(resLabel, "-");
		geno = part[0];
		date = part[2];
		time = part[3]; 
		setResult("Genotype", v, geno); 
		setResult("Date", v, date);
		setResult("Time", v, time);
	}
	updateResults();
}

