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
selectWindow("ROI Manager");
run("Close");
print("All folders processed.")
}

//analyse files by first setting the scale (once), cropping plates then counting seeds
function processSub(subdir) {
	print("Processing "+ subdir+ "...");
	setBatchMode(false);
	run("Image Sequence...", "open=["+subdir+sublist[0]+"]+convert sort use");
	platename = File.getName(subdir);
	open();
	showMessage(sublist.length + " images will now be saved as a stack. This may take some minutes, please go have a cup of coffee.");
	saveAs("Tiff", subdir+platename+".tif");
	if (i==0)
	scale();
	cropPlate();
	countSeeds();
	print(i+1 +"/"+list.length + " folders processed.");
};

//prompts user to draw a line to set scale globally
//then saves the scale as a text file
//only run at the first subdirectory as distance of camera from plates is assumed to be equal
function scale() {
	print("Setting scale...");
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel global");
	setTool("line");
	waitForUser("Setting the scale. Please zoom in on the scale bar and hold the SHIFT key while drawing a line corresponding to 1cm.");
	getSelectionCoordinates(xpoints, ypoints);	//to find out area to crop later
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
	//for cropping of images into a smaller area to accomodate computers with low RAM
	xmid = (xpoints[1]+xpoints[0])/2;
	ymid = (ypoints[1]+ypoints[0])/2;
	makePoint(xmid, ymid);
	x1 = (xmid/length - 12.8)*length;
	y1 = (ymid/length - 11.5)*length;
	width = 14.1*length;
	height = 12.65*length;
	makeRectangle(x1, y1, width, height);
	run("Crop");
}

//prompts user to determine group/genotype positions
//crops are saved under a newly created subfolder "cropped"
//User ROI selection will be prompted at every subdirectory
function cropPlate() {
	run("Z Project...", "projection=[Max Intensity]");
	maxproj = getTitle();
	run("ROI Manager...");
	setTool("Rectangle");
	if (i==0)
	waitForUser("Select each group on Max Intensity Projection image, and add to ROI manager. ROI names will be saved.");
	if (i>0)
	waitForUser("Modify ROI and names if needed.");
	while (roiManager("count") <= 0) {
		waitForUser("Select each group and add to ROI manager. ROI names will be saved.");
	};
	waitForUser(roiManager("count") + " lines have been selected. Press OK if correct. Edit now if incorrect.");
	close(maxproj);
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
}

//processes images then runs particle analysis 
//counted outlines are saved as an image under a newly created folder "outline"
//output data is saved as a text file


function countSeeds() {
	outcrop = subdir + "/cropped/";
	croplist = getFileList(outcrop);

	for (y = 0; y < croplist.length; ++y) {
		print("Tracking germination of "+croplist[y]);
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
		run("Set Measurements...", "area perimeter shape display redirect=None decimal=3");
		run("Analyze Particles...", "size=0.002-0.02 circularity=0.3-1.00 show=Outlines display clear summarize stack");
		outlinestack = getTitle();
		run("Rotate 90 Degrees Left");
		run("RGB Color");

		//Obtain slice labels (contains time point info)
		//Prints them on a new stack, then merges to outlinestack
		selectWindow(stack2);
		setSlice(1);
		xmax = getWidth;
		
		for (x = 0; x < nSlices; x++) {
			slicelabel = getMetadata("Label");
			newImage("Slice label", "RGB white", xmax, 50, 1);
			setFont("SansSerif", 20, " antialiased");
			makeText(slicelabel, 0, 0);
			setForegroundColor(0, 0, 0);
			run("Draw", "slice");
			selectWindow(stack2);
			run("Next Slice [>]");
		}
		
		run("Images to Stack");
		run("Combine...", "stack1=["+outlinestack+"] stack2=[Stack] combine");
		run("Combine...", "stack1=["+stack2+"] stack2=[Combined Stacks] combine");
		saveAs("Tiff", genodir+"_outline"+".tif");
		close();
		close();

		//save output of particle analysis
		selectWindow("Summary of "+orifile);
		summaryPA();
		platename = File.getName(subdir);
		saveAs("Text", genodir+platename+" "+genoname+" seed count summary.txt");
		run("Close");
		selectWindow("Results");
		resultPA();
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
	run("Options...", "iterations=1 count=4 do=Dilate stack");
    run("Remove Outliers...", "radius=3 threshold=50 which=Dark stack");
}

//reduces summary of particle analysis to just "Count"
//adds Genotype, Date, Time to results table based on file name
function summaryPA() {
	Table.deleteColumn("Total Area");
	Table.deleteColumn("Average Size");
	Table.deleteColumn("%Area");
	Table.deleteColumn("Perim.");
	Table.deleteColumn("Solidity");
	Table.deleteColumn("Circ.");
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

	for (v=0; v<nR; v++) {
		inicount = Table.get("Count", 0);
		count = Table.get("Count", v);
		label = Table.get("Slice", v);

		if (v==0)
		errorcount = 0;
		
		if (count != inicount)
			errorcount=errorcount+1;
	}
	
		if (errorcount > 0)
			print("Warning! Number of seeds detected were not equal between time points.");
}

function resultPA() {
	Table.deleteColumn("Circ.");
	Table.deleteColumn("Solidity");
}


