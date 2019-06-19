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
function processSub(subdir) {
	setBatchMode(false);
	run("Image Sequence...", "open=["+subdir+sublist[0]+"]+convert sort use");
	platename = File.getName(subdir);
	saveAs("Tiff", subdir+platename+".tif");
	if (i==0)
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
function cropPlate() {
	run("ROI Manager...");
	setTool("Rectangle");
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
function countSeeds() {
	print("Counting seeds...");
	outcrop = subdir + "/cropped/";
	croplist = getFileList(outcrop);

	for (y = 0; y < croplist.length; ++y) {
		setBatchMode(true);
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

		for (x = 0; x < nSlices; x++) {
		run("Duplicate...", "use");
		temp = getTitle();
		run("Set Measurements...", "area shape display redirect=None decimal=3");
		//////////////////MODIFY HERE FOR CHANGED ROUND/AR
		run("Extended Particle Analyzer", "  round=0.5-1.00 show=Outlines redirect=None keep=None display summarize");
		close(temp);
		selectWindow(stack1);
		run("Next Slice [>]");
		}

		run("Images to Stack", "name=["+genoname+"outline"+"] title=[] use");
		run("Rotate 90 Degrees Left");
		outlinestack = getTitle();
		run("RGB Color");
		run("Combine...", "stack1=["+stack2+"] stack2=["+outlinestack+"] combine");
		saveAs("Tiff", genodir+"_outline"+".tif");
		close();
		close();
		//save summary of particle analysis
		selectWindow("Summary");
		//summaryPA();
		saveAs("Text", genodir+platename+" "+genoname+" seed count summary.txt");
		run("Close");
		selectWindow("Results");
		///resultPA();
		saveAs("Text", genodir+platename+" "+genoname+" individual seed analysis.txt");
		run("Close");
}
}

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
	Table.deleteColumn("Solidity");
}

