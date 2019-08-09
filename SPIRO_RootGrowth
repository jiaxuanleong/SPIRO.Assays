//requirements for file organization
//main directory containing all images sorted by plate into subdirectories
//requirements for image naming
//plate1-date20190101-time000000-day

//user selection of main directory
maindir = getDirectory("Choose a Directory ");
list = getFileList(maindir);
processMain1(maindir);
processMain2(maindir);


function processMain1(maindir) {
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/")) {
			subdir = maindir+list[i];
			sublist = getFileList(subdir);
			platename = File.getName(subdir);
			cropGroup(subdir);
		}
	}
}

function processMain2(maindir) {
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/")) {
			subdir = maindir+list[i];
			sublist = getFileList(subdir);
			processSub2(subdir);
		}
selectWindow("ROI Manager");
run("Close");
print("All folders processed.");
}

function cropGroup(subdir) {
	setBatchMode(false);
	open(subdir+platename+"_registered.tif");
	reg = getTitle();
	waitForUser("Create substack", "Please scroll to the last slice to be included for germination analysis.");	
	run("Make Substack...");
	saveAs("Tiff", subdir+platename+"_subset.tif");
	close(reg);
	open(subdir+platename+"_subset.tif");
	print("Cropping genotypes/groups..");
	run("ROI Manager...");
	setTool("Rectangle");
	if (i==0) {
	roiManager("reset");
	waitForUser("Select each group, and add to ROI manager. ROI names will be saved.");
	}
	if (i>0)
	waitForUser("Modify ROI and names if needed.");
	while (roiManager("count") <= 0) {
		waitForUser("Select each group and add to ROI manager. ROI names will be saved.");
	};
	run("Select None");

	outcrop = subdir + "/cropped/";
	File.makeDirectory(outcrop);

	setBatchMode(true);
	
	//loop enables cropping of ROI(s) followed by saving of cropped stacks
	//roi names cannot contain dashes due to split() to extract information from file name later on
	roicount = roiManager("count");
	for (x=0; x<roicount; ++x) {
    	roiManager("Select", x);
    	roiname = Roi.getName;
    	if (indexOf(roiname, "-") > 0) {
    		waitForUser("ROI names cannot contain dashes '-'! Modify now.");
    		roiname = Roi.getName;
    	}
    	genodir = outcrop + "/"+roiname+"/";
    	File.makeDirectory(genodir);	
		print("Cropping group "+x+1+"/"+roicount+" "+roiname+"...");
    	run("Duplicate...", "duplicate");
    	saveAs("Tiff", genodir+roiname+".tif");
    	close();
	};
close();
print(i+1 +"/"+list.length + " folders processed.");
}

function processSub2(subdir) {
	print("Processing "+ subdir+ "...");
	platename = File.getName(subdir);
	
	outcrop = subdir + "/cropped/";
	croplist = getFileList(outcrop);
	
	skel();
	print(i+1 +"/"+list.length + " folders processed.");
};


function rootlength() {
	
	for (y = 0; y < croplist.length; ++y) {
		print("Analysis root length of "+croplist[y]);
		setBatchMode(false);
		genodir = outcrop+"/"+croplist[y]+"/";
		genolist = getFileList(genodir);
		genoname = File.getName(genodir);
		open(genodir+genolist[0]);
		stack1 = getTitle();
		run("Duplicate...", "duplicate");
		stack2 = getTitle();

		selectWindow(stack1);
		skel();
		run("Analyze Skeleton (2D/3D)", "prune=none show display");
		close(stack1);
		run("Images to Stack");
		stack1 = getTitle();

		selectWindow(stack2);
		xmax = getWidth;
		
		for (x = 0; x < nSlices; x++) {
			slicelabel = getMetadata("Label");
			newImage("Slice label", "8-bit", xmax, 50, 1);
			setFont("SansSerif", 20, " antialiased");
			makeText(slicelabel, 0, 0);
			setForegroundColor(0, 0, 0);
			run("Draw", "slice");
			selectWindow(stack2);
			run("Next Slice [>]");
		}
		
		run("Images to Stack");
		run("RGB Color");
		label = getTitle();
		
		run("Combine...", "stack1=["+stack2+"] stack2=["+stack1+"] combine");
		run("Combine...", "stack1=[Combined Stacks] stack2=["+label+"] combine");
		
		saveAs("Tiff", genodir+platename+"_"+genoname+"_labelled.tif");
		close();
		selectWindow("Results");
		
		saveAs("Text", genodir+platename+" "+genoname+" root length analysis.txt");
		run("Close");
}
}


//creates a binary mask and reduces noise
function skel() {
	run("8-bit");
	run("Subtract Background...", "rolling=30 stack");
	setAutoThreshold("MaxEntropy dark");
	setOption("BlackBackground", false);
	run("Convert to Mask", "method=MaxEntropy background=Dark");
	run("Median...", "radius=1 stack");
	run("Median...", "radius=1 stack");
	run("Options...", "iterations=10 count=1 do=Close");
    run("Skeletonize");	
}
