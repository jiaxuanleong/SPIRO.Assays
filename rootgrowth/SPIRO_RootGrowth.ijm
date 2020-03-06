/*
 * GLOBAL VARIABLES
 * ================
 */

var maindir;	// main directory
var resultsdir;	// results subdir of main directory
var ppdir;		// preprocessing subdir
var curplate;	// number of current plate being processed

// table names
var ra = "Root analysis";
var bi = "Branch information";

//user selection of main directory
showMessage("Please locate and open your experiment folder containing preprocessed data.");
maindir = getDirectory("Choose a Directory");
resultsdir = maindir + "/Results/";
ppdir = resultsdir + "/Preprocessing/";
ppdirlist = getFileList(ppdir);

for (ppdirno = 0; ppdirno < ppdirlist.length; ppdirno ++) {  //main loop through plates
	if (indexOf (ppdirlist[ppdirno], "preprocessed") > 0) { //to avoid processing any random files in the folder
		platefile = ppdirlist [ppdirno];
		fnsplit = split(platefile, "_");
		platename = fnsplit[0];
		print("Processing "+platename);
		
		rootgrowthsubdir = resultsdir + "/" + platename + "/";
		if (!File.isDirectory(rootgrowthsubdir))
			File.makeDirectory(rootgrowthsubdir);
		detectOutput();	
		splitGreenCh();
		cropGroups();
	}
}
////////////////loop by function
function detectOutput() {
	

//splits RGB stack and only saves green channel
function splitGreenCh() {
	print("Saving green channel as separate file");
	if (is("Batch Mode"))
		setBatchMode(false);
	open(ppdir+platename+"_preprocessed.tif");
	ppstack = getTitle();
	stacksize = nSlices();  //total number of slices
	slicelabelsarray = newArray(stacksize); //an array to be filled with all slicelabels

	for (sliceno = 1; sliceno <= stacksize; sliceno ++) {
		setSlice(sliceno);
		slicelabel = getInfo("slice.label");
		slicelabelsarray[sliceno-1] = slicelabel;
	}

	run("Split Channels");
		
	imglist = getList("image.titles");
	for (img = 0; img < imglist.length; img ++) { 
		imgname = imglist[img]; 
		if (indexOf(imgname, "red") > 0 ) {
	    	selectWindow(imgname);				
	    	close();
	    }
	    if (indexOf(imgname, "green") > 0) {
			selectWindow(imgname);
			for (sliceno = 1; sliceno <= stacksize; sliceno ++) {
				setSlice(sliceno);
				slicelabel = slicelabelsarray[sliceno-1];
				setMetadata("Label", slicelabel);
			}
				selectWindow(imgname);
				saveAs("Tiff", rootgrowthsubdir + platename + "substackGreenOnly.tif");
	    }
		if (indexOf(imgname, "blue") > 0) {
			selectWindow(imgname);
			close(); 
		}
	}
}

//prompts user to make a substack, to make data size smaller by excluding time to germination etc.
//then prompts user to draw ROIs around groups of seeds to be analyzed
function cropGroups() {
	print("Cropping groups in "+ platename);
	if (is("Batch Mode"))
		setBatchMode(false);
	greensubstack = platename + "substackGreenOnly.tif";
	if (isOpen(platename + "substackGreenOnly.tif") == 0)
		open(rootgrowthsubdir + greensubstack);
	waitForUser("Create substack",
				"Please note first and last slice to be included for root growth analysis, and indicate it in the next step.");
	run("Make Substack...");
	
	run("ROI Manager...");
	setTool("Rectangle");
	roiManager("reset");
	roicount = roiManager("count"); 
	while (roicount == 0) {
		waitForUser("Select each group, and add to ROI manager. ROI names will be saved.\n" +
			"Please use only letters and numbers in the ROI names. \n" + //to avoid file save issues
			"ROIs cannot share names."); //shared roi names would combine both rois and any area between
		roicount = roiManager("count");
		} 
	}
	run("Select None");
	setBatchMode(true);
	
	for (roino = 0; roino < roicount; roino ++) {
		roiManager("select", roino);
		roiname = Roi.getName;
		groupdir = rootgrowthsubdir + "/"+roiname+"/";
		File.makeDirectory(groupdir);
		roitype = Roi.getType;
		if (roitype != "rectangle") {
			run("Duplicate...", "duplicate");
			run("Make Inverse");
			run("Clear", "stack");
		} else {
			run("Duplicate...", "duplicate");
		}
		saveAs("Tiff", groupdir + roiname + ".tif");
		close(roiname + "*");
	}
	close(greensubstack);
}