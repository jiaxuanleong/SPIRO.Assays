//requirements for file organization
//main directory containing all images sorted by plate into subdirectories
//requirements for image naming
//plate1-date20190101-time000000-day

//user selection of main directory
showMessage("Please locate and open your experiment folder containing preprocessed data.");
maindir = getDirectory("Choose a Directory");
resultsdir = maindir + "/Results/";
preprocessingmaindir = resultsdir + "/Preprocessing/";

preprocessingmaindirlist = getFileList(preprocessingmaindir);
for (a=0; a<preprocessingmaindirlist.length; a++) {
	if (indexOf(preprocessingmaindirlist[a], "plate") < 0)
		preprocessingmaindirlist = Array.deleteValue(preprocessingmaindirlist, preprocessingmaindirlist[a]); //makes sure any non-plate folder isnt processed
}

germnmaindir = resultsdir + "/Germination assay/";
if (!File.isDirectory(germnmaindir)) {
	File.makeDirectory(germnmaindir);
}
processMain1();
processMain2();

list = getList("window.titles");
	for (i=0; i<list.length; i++){
	winame = list[i];
	selectWindow(winame);
	run("Close");
}

//PART1 crop groups/genotypes per plate
function processMain1() {
	for (i=0; i<preprocessingmaindirlist.length; i++) {
		plateanalysisno = i;
		platepreprocessedfile = preprocessingmaindirlist [i];
		preprocessedfilenameparts = split(platepreprocessedfile, "_");
		platename = preprocessedfilenameparts[0];
		cropGroup();
	}
}

//PART2 analyses seeds per genotype/group per plate
function processMain2() {
	for (i=0; i<preprocessingmaindirlist.length; i++) {
		platepreprocessedfile = preprocessingmaindirlist [i];
		preprocessedfilenameparts = split(platepreprocessedfile, "_");
		platename = preprocessedfilenameparts[0];
		processSub2();
	}
}

function processSub2() {
	germnsubdir = germnmaindir+ "/" + platename + "/";
	croplist = getFileList(germnsubdir);
	seedAnalysis();
}

//PART1 crops groups/genotypes
function cropGroup() {
	germnsubdir = germnmaindir+ "/" + platename + "/";
	if (!File.isDirectory(germnsubdir)) {
		File.makeDirectory(germnsubdir);
	}
	setBatchMode(false);
	open(preprocessingmaindir + platename + "_preprocessed.tif");
	oristack = getTitle();
	waitForUser("Create substack", "Please note first and last slice to be included for germination analysis, and indicate it in the next step.");	
	run("Make Substack...");
	saveAs("Tiff", germnsubdir + platename + "_germinationsubstack.tif");
	close(oristack);
	print("Cropping genotypes/groups of " + platename);
	run("ROI Manager...");
	setTool("Rectangle");

	if (plateanalysisno == 0) {
		roiManager("reset");
		waitForUser("Select each group, and add to ROI manager. ROI names will be saved.\n" +
		"Please do not use dashes in the ROI names or we will complain about it later.\n" +
		"ROIs cannot share names.");
	}

	if (plateanalysisno > 0) {
		waitForUser("Modify ROI and names if needed.");
	}

	while (roiManager("count") <= 0) {
		waitForUser("Select each group and add to ROI manager. ROI names will be saved.\n" +
		"Please do not use dashes in the ROI names or we will complain about it later\n" +
		"ROIs cannot share names.");
	};

	run("Select None");

	setBatchMode(true);
	
	//loop enables cropping of ROI(s) followed by saving of cropped stacks
	//roi names cannot contain dashes due to split() to extract information from file name later on
	roicount = roiManager("count");
	for (x=0; x<roicount; ++x) {
		roiManager("Select", x);
		roiname = Roi.getName;
		while (indexOf(roiname, "-") > 0) {
			waitForUser("ROI names cannot contain dashes '-'! Please modify the name, then click OK.");
			roiManager("Select", x);
			roiname = Roi.getName;
		}
		genodir = germnsubdir + "/" + roiname + "/";
		if (!File.isDirectory(genodir)) {
			File.makeDirectory(genodir);
		}
		File.makeDirectory(genodir);
		print("Cropping group "+x+1+"/"+roicount+" "+roiname+"...");
		roitype = Roi.getType;
		if (roitype != "rectangle") {
			run("Duplicate...", "duplicate");
			run("Make Inverse");
			run("Clear", "stack");
		} else {
			run("Duplicate...", "duplicate");
		}
		saveAs("Tiff", genodir+roiname+".tif");
		close();
	}
	close();
}

//PART2 analyses seeds per genotype/group 
function seedAnalysis() {
	for (y = 0; y < croplist.length; ++y) {
		if (indexOf(croplist[y], "substack")<0) {
			print("Tracking germination of " + croplist[y]);
			setBatchMode(false);
			genodir = germnsubdir + "/" + croplist[y] + "/";
			genolist = getFileList(genodir);
			genoname = File.getName(genodir);
			open(genodir + genolist[0]);
			stack1 = getTitle();
			run("Duplicate...", "duplicate");
			stack2 = getTitle();

			selectWindow(stack1);
			run("Select None");
			seedMask();
			roiManager("reset");
			run("Rotate 90 Degrees Right");
			setSlice(1);

			run("Create Selection");
			run("Colors...", "foreground=black background=black selection=red");

			roiManager("Add");
			roiManager("select", 0);
			roiManager("split");
			roiManager("select", 0);
			roiManager("delete");

			roiarray = newArray(roiManager("count"));
			for (x = 0; x<roiManager("count"); x++) {
				roiarray[x]=x;
			}
			roiManager("select", roiarray);
			roiManager("multi-measure");
			roiManager("deselect");
			tp = "Trash positions";
			Table.create(tp);
			selectWindow("Results");

			for (x=0; x<nResults; x++) {
				selectWindow("Results");
				area = getResult("Area", x);
				if (area < 0.0012) {
					Table.set("Trash ROI", Table.size(tp), x);
				}
			}

			selectWindow("Trash positions");
			if (Table.size(tp) > 0) {
				trasharray = Table.getColumn("Trash ROI", tp);
				roiManager("select", trasharray);
				roiManager("delete");

				roiarray = newArray(roiManager("count"));
			}
			close(tp);
			for (x = 0; x<roiManager("count"); x++) {
				roiManager("select", x);
				run("Enlarge...", "enlarge=0.08");
				roiManager("update");
				roiManager("rename", x+1);
			}

			run("Set Measurements...", "area perimeter stack display redirect=None decimal=3");
			run("Clear Results");

			for (x=0; x<roiManager("count"); x++) {
				roiManager("select", x);
				run("Analyze Particles...", "size=0-Infinity show=Nothing display stack");
			}

			//Visualize detected seed positions on the first time point of the binary masks stack 
			selectWindow(stack1);
			roiManager("Associate", "false");
			roiManager("Centered", "false");
			roiManager("UseNames", "false");
			roiManager("Show All");
			roiManager("Show All with labels");
			run("Labels...", "color=white font=18 show use draw");
			run("Flatten", "stack");
			run("Rotate 90 Degrees Left");

			selectWindow(stack2);
			run("RGB Color");
			setBatchMode(true);

			//Determine the cropped frame proportions to orient combining stacks horizontally or vertically
			xmax = getWidth;
			ymax = getHeight;
			frameproportions=xmax/ymax; 

			//Add label to each slice (time point). The window width for label is determined by frame proportions 
			for (x = 0; x < nSlices; x++) {
				slicelabel = getMetadata("Label");
				if (frameproportions > 1) {
					newImage("Slice label", "RGB Color", xmax, 50, 1);
					setFont("SansSerif", 20, " antialiased");
					makeText(slicelabel, 0, 0);
					setForegroundColor(0, 0, 0);
					run("Draw", "slice");
					selectWindow(stack2);
					run("Next Slice [>]");
				}
				if (frameproportions < 1) {
					newImage("Slice label", "RGB Color", 2*xmax, 50, 1);
					setFont("SansSerif", 20, " antialiased");
					makeText(slicelabel, 0, 0);
					setForegroundColor(0, 0, 0);
					run("Draw", "slice");
					selectWindow(stack2);
					run("Next Slice [>]");
				}
			}

			//Combine the cropped photos and masks with labels into one time-lapse stack. Combine vertically or horizontally depending on the frame proportions
			run("Images to Stack");
			label = getTitle();
			if (frameproportions > 1) {
				run("Combine...", "stack1=[" + stack2 + "] stack2=[" + stack1 + "] combine");
				run("Combine...", "stack1=[Combined Stacks] stack2=[" + label + "] combine");
			}
			if (frameproportions < 1) {
				run("Combine...", "stack1=[" + stack2 + "] stack2=[" + stack1 + "]");
				run("Combine...", "stack1=[Combined Stacks] stack2=["+label+"] combine");
			}

			saveAs("Tiff", genodir + platename + "_" + genoname + "_germination.tif");
			close();
			selectWindow("Results");
			saveAs("Results", genodir + platename + " " + genoname + " seed germination analysis.tsv");
			run("Close");
		}
	}
}

//creates a binary mask and reduces noise
function seedMask() {
	run("8-bit");
	//run("Subtract Background...", "rolling=30 stack");
	run("Enhance Contrast...", "saturated=0.2 normalize process_all");
	run("Median...", "radius=1 stack");
	setAutoThreshold("MaxEntropy dark");
	run("Convert to Mask", "method=MaxEntropy background=Dark calculate");
	run("Options...", "iterations=1 count=4 do=Dilate stack");
	run("Remove Outliers...", "radius=3 threshold=50 which=Dark stack");
	run("Remove Outliers...", "radius=5 threshold=50 which=Dark stack");
}
