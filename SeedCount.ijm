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
//run("Close");
print("All folders processed.")
}

//analyse files by first setting the scale (once), cropping plates then counting seeds
function processSub(subdir) {
	print("Processing "+ subdir+ "...");
	setBatchMode(false);
	run("Image Sequence...", "open=["+subdir+sublist[0]+"]+convert sort use");
	showMessage("Converting to 8-bit, please wait.");
	run("8-bit");
	platename = File.getName(subdir);
	stack1 = getTitle();
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
	if (i==0) {
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
	//run("Close");
	}
	//for cropping of images into a smaller area to allow faster processing
	xmid = (xpoints[1]+xpoints[0])/2;
	ymid = (ypoints[1]+ypoints[0])/2;
	makePoint(xmid, ymid);
	x1 = (xmid/length - 12.8)*length;
	y1 = (ymid/length - 11.5)*length;
	width = 14.1*length;
	height = 12.65*length;
	makeRectangle(x1, y1, width, height);
	run("Crop");
	run("Duplicate...", "duplicate");
	stack2 = getTitle();
	run("Subtract Background...", "rolling=30 stack");
	tfn = subdir+"/Transformation Matrices/";
	run("MultiStackReg", "stack_1="+stack2+" action_1=Align file_1="+tfn+" stack_2=None action_2=Ignore file_2=[] transformation=Translation save");
	close(stack2);
	run("MultiStackReg", "stack_1="+stack1+" action_1=[Load Transformation File] file_1="+tfn+" stack_2=None action_2=Ignore file_2=[] transformation=[Translation]");
	selectWindow(stack1);
	saveAs("Tiff", subdir+platename+"_registered.tif");
	run("Z Project...", "projection=[Standard Deviation]");
	zproj = getTitle();
	showMessageWithCancel("Click OK if images were registered accurately, the projection will look sharp. \n If images were not registered well the projection will look blurry, \n in which case please exit by clicking Cancel");
	close(zproj);
}

//prompts user to determine group/genotype positions
//crops are saved under a newly created subfolder "cropped"
//User ROI selection will be prompted at every subdirectory
function cropPlate() {
	run("ROI Manager...");
	setTool("Rectangle");
	//if (i==0)
	roiManager("reset");
	waitForUser("Select each group, and add to ROI manager. ROI names will be saved.");
	//if (i>0)
	//waitForUser("Modify ROI and names if needed.");
	while (roiManager("count") <= 0) {
		waitForUser("Select each group and add to ROI manager. ROI names will be saved.");
	};
	waitForUser(roiManager("count") + " lines have been selected. Press OK if correct. Edit now if incorrect.");
	run("Select None");

	//if (i==0) {
		//Table.create("Genotype/group ROI coordinates");
		//for (x=0; x<roiManager("count"); x++) {
		//	roiManager("select", x);
		//	getSelectionCoordinates(xpoints, ypoints);
		//	Table.setColumn("X"+x, xpoints);
		//	Table.setColumn("Y"+x, ypoints);
	//	}
//	} else { 
		//////////
//		makeSelection("polygon", xcoord, ycoord)
//	}

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
		roiManager("reset");
		run("Rotate 90 Degrees Right");
		setSlice(nSlices);
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

		for (x=0; x<nResults; x++) {
		area = getResult("Area", x);

		///////////AREA PROBLEM
			if (area<0.002) {
				roiManager("select", x);
				roiManager("delete");
			}
		}

		roiarray = newArray(roiManager("count"));
		for (x = 0; x<roiManager("count"); x++) {
			roiarray[x]=x;
		}
		///////////////COMBINE PROBLEM
		roiManager("select", roiarray);
		roiManager("combine");
		roiManager("add");
		roiManager("select", roiarray);
		roiManager("delete");
		
		setSlice(1);
		roiManager("select",0);
		run("Enlarge...", "enlarge=0.01");	
		run("Set Measurements...", "area perimeter shape display redirect=None decimal=3");
		run("Analyze Particles...", "size=0-Infinity show=Outlines display clear stack");
		outlinestack = getTitle();
		run("Rotate 90 Degrees Left");

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
		run("Combine...", "stack1=["+outlinestack+"] stack2=[Stack] combine");
		run("Combine...", "stack1=["+stack2+"] stack2=[Combined Stacks] combine");
		saveAs("Tiff", genodir+"_outline"+".tif");
		close();
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

