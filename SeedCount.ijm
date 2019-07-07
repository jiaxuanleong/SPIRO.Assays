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
			processSub1(subdir);
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
	}
selectWindow("ROI Manager");
//run("Close");
print("All folders processed.")
}

//prompts user to determine group/genotype positions
//crops are saved under a newly created subfolder "cropped"
//User ROI selection will be prompted at every subdirectory

function processSub1(subdir) {
	subset();
	cropGroup();
}

function subset() {
	Dialog.create("Germination analysis end point");
	Dialog.addString("Last time point", "20190101-000000");
	Dialog.show();
	tp = Dialog.getString();
	open(subdir+platename+"_registered.tif");	
	
	for (x = 1; x < nSlices; x++) {
		setSlice(x);
		slicelabel = getInfo("slice.label");
		
		if (indexOf(slicelabel, tp)>0) {
			lastsliceno = x;
			slicesdelete = nSlices-x;
			for (y=0; y<slicesdelete; y++) {
				run("Delete Slice");
			}
		}
	run("Next Slice [>]");
}
saveAs("Tiff", subdir+platename+"_subset.tif");
}
	
function cropGroup() {
	print("Cropping genotypes/groups..");
	setBatchMode(false);
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
	
	countSeeds();
	print(i+1 +"/"+list.length + " folders processed.");
};


function countSeeds() {
	
	for (y = 0; y < croplist.length; ++y) {
		print("Tracking germination of "+croplist[y]);
		setBatchMode(true);
		genodir = outcrop+"/"+croplist[y]+"/";
		genolist = getFileList(genodir);
		genoname = File.getName(genodir);
		open(genodir+genolist[0]);
		stack1 = getTitle();
		run("Duplicate...", "duplicate");
		stack2 = getTitle();

		selectWindow(stack1);
		seedMask();
		roiManager("reset");
		run("Rotate 90 Degrees Right");
		setSlice(nSlices);
		run("Create Selection");
		run("Enlarge...", "enlarge=0.02");
		roiManager("Add");
		roiManager("select", 0);
		roiManager("split");
		roiManager("select", 0);
		roiManager("delete");

		roiarray = newArray(roiManager("count"));
		for (x = 0; x<roiManager("count"); x++) {
			roiManager("select", x);
			roiManager("rename", x+1);
		}
		
		run("Set Measurements...", "area perimeter shape display redirect=None decimal=3");
		run("Clear Results");
		
		for (x=0; x<roiManager("count"); x++) {
		roiManager("select", x);
		run("Analyze Particles...", "size=0-Infinity show=Nothing display stack");
		}
		close(stack1);

		//Obtain slice labels (contains time point info)
		//Prints them on a new stack, then merges to outlinestack
		selectWindow(stack2);
		setSlice(1);
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
		run("Combine...", "stack1=["+stack2+"] stack2=[Stack] combine");
		saveAs("Tiff", genodir+"_labelled"+".tif");
		close();

		//run("Close");
		selectWindow("Results");
		resultPA();
		saveAs("Text", genodir+platename+" "+genoname+" individual seed analysis.txt");
		//run("Close");
}
}


//creates a binary mask and reduces noise
function seedMask() {
	run("8-bit");
	run("Subtract Background...", "rolling=30 stack");
	run("Median...", "radius=1 stack");
	setAutoThreshold("MaxEntropy dark");
	run("Convert to Mask", "method=MaxEntropy background=Dark");
	run("Options...", "iterations=1 count=4 do=Dilate stack");
    run("Remove Outliers...", "radius=3 threshold=50 which=Dark stack");
}


function resultPA() {
	Table.deleteColumn("Circ.");
	Table.deleteColumn("Solidity");
}

