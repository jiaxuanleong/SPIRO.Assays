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
			processSub(subdir);
		}
	}
}

//analyse files by first setting the scale (once), cropping plates then counting seeds
function processSub (subdir) {
	setBatchMode(false);
	run("Image Sequence...", "open=["+subdir+sublist[0]+"]+convert sort use");
	filename = sublist[0];
	part = split(filename, "-");
	plateno = part[0];
	saveAs("Tiff", subdir+plateno+".tif");
	if (i==0);
	scale();
	cropPlate();
	countSeeds();
	print(subdir + " processed.");
};

//prompts user to draw a line to set scale globally
//then saves the scale as a text file
function scale() {
	print("Setting scale...");
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel global");
	makeLine(2712, 2171, 2886, 2171);
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
}

//prompts user to determine line positions, then crops these out as individual tiffs
//crops are saved under a newly created subfolder "cropped"
function cropPlate () {
	run("ROI Manager...");
	setTool("Rectangle");
	waitForUser("Select each group and add to ROI manager. ROI names will be saved.");
	if (roiManager("count")>0) {
	roiManager("deselect");
	roiManager("delete");
	}
	makeRectangle(716, 465, 963, 96);
	roiManager("add");
	roiManager("Select", 0);
	roiManager("Rename", "A");
	makeRectangle(704, 942, 963, 96);
	roiManager("add");
	roiManager("Select", 1);
	roiManager("Rename", "B");
	makeRectangle(749, 1443, 963, 96);
	roiManager("add");
	roiManager("Select", 2);
	roiManager("Rename", "C");
	waitForUser("Select each group and add to ROI manager. ROI names will be saved.");
	while (roiManager("count") <= 0) {
		waitForUser("Select each group and add to ROI manager. ROI names will be saved.");
	};
	waitForUser(roiManager("count") + " lines have been selected. Press OK if correct. Edit now if incorrect.");
	run("Select None");
	
	print("Cropping plates...");

	outcrop = subdir + "/cropped/";
	File.makeDirectory(outcrop);

	setBatchMode(true);
	
	
	//loop enables cropping of ROI(s) followed by saving of cropped stacks
	//roi names cannot contain dashes due to split() to extract information from file name later on

			for (x=0; x<roiManager("count"); ++x) {
    		
    			roiManager("Select", x);
    			
    			roiname = Roi.getName;
    			if (indexOf(roiname, "-") > 0) {
    				waitForUser("ROI names cannot contain dashes '-'! Modify now.");
    				roiname = Roi.getName;
    			}
    			genodir = outcrop + "/"+roiname+"/";
    			File.makeDirectory(genodir);
    			
    			run("Duplicate...", "duplicate");
    			saveAs("Tiff", genodir+roiname+".tif");
    			close();
	};
close();
}

//processes images then runs particle analysis 
//counted outlines are saved as an image under a newly created folder "outline"
//output data is saved as a text file
function countSeeds () {
	print("Counting seeds...");
	outcrop = subdir + "/cropped/";
	croplist = getFileList(outcrop);

	for (y = 0; y < croplist.length; ++y) {
		setBatchMode(false);
		genodir = outcrop+"/"+croplist[y]+"/";
		genolist = getFileList(genodir);
		genoname = File.getName(genodir);
		open(genodir+genolist[0]);
		stack1 = getTitle();
		orifile = File.name;
		run("Duplicate...", "duplicate");
		stack2 = getTitle();
		selectWindow(stack1);
		seedMask();
		run("Rotate 90 Degrees Right");
		run("Set Measurements...", "area shape redirect=None decimal=3");
		run("Analyze Particles...", "size=0.004-0.008 circularity=0.60-1.00 show=Outlines display clear summarize stack");
		outlinestack = getTitle();
		run("Rotate 90 Degrees Left");
		run("RGB Color");
		run("Combine...", "stack1=["+stack2+"] stack2=["+outlinestack+"] combine");
		saveAs("Tiff", genodir+"_outline"+".tif");
		close();
		close();
		//save summary of particle analysis
		summaryPA();
		saveAs("Text", genodir+"Seed count summary "+genoname+".txt");
		run("Close");
		resultPA();
		saveAs("Text", genodir+"Individual seed analysis "+genoname+".txt.");
		run("Close");
};

//creates a binary mask and reduces noise
function seedMask() {
	run("8-bit");
	run("Subtract Background...", "rolling=30 stack");
	run("Median...", "radius=1 stack");
	setAutoThreshold("MaxEntropy dark");
	run("Convert to Mask", "method=MaxEntropy background=Dark");
}

//reduces summary of particle analysis to just "Count"
//adds Genotype, Date, Time to results table based on file name
function summaryPA() {
	selectWindow("Summary of "+orifile);
	Table.deleteColumn("Circ.");
	Table.deleteColumn("Solidity");
	Table.deleteColumn("Total Area");
	Table.deleteColumn("Average Size");
	Table.deleteColumn("%Area");
	Table.update;
	
	nR = Table.size;
	
	for (v=0; v<nR;v++) {
		resLabel = Table.getString("Slice", v);
		part = split(resLabel, "-");
		date = part[1];
		time = part[2]; 
		Table.set("Genotype", v, genoname);
		Table.set("Date", v, date);
		Table.set("Time", v, time);
	}
	Table.update;
}

function resultPA() {
	selectWindow("Results");
	Table.deleteColumn("Solidity");
}

