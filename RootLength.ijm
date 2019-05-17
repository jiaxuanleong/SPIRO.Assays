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
	skel();	
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

//STEP 3 Skeletonize and analysis
function skel() {
	print("Analysing roots..");
	setBatchMode(true);
	outcrop = subdir + "/cropped/";
	croplist = getFileList(outcrop);
	skeleton = subdir + "/skeleton/";
	File.makeDirectory(skeleton);

	for (w = 0; w < croplist.length; w++) {
		open(outcrop+croplist[w]);
		filename = File.nameWithoutExtension;
		print("Analysing roots...");
		run("8-bit");
////////THIS PART IN PROGRESS////////////////////
//need a way for user defined run("Threshold...") and apply the same values to the next time point
		if (startsWith(filename, 1)==1 && indexOf(filename, "day")>-1) {
		setThreshold(161, 255);
		}
		if (startsWith(filename, 2)==1 && indexOf(filename, "day")>-1) {
		setThreshold(152, 255);
		}
		if (startsWith(filename, 3)==1 && indexOf(filename, "day")>-1) {
		setThreshold(123, 255);
		}
		if (startsWith(filename, 4)==1 && indexOf(filename, "day")>-1) {
		setThreshold(114, 255);
		}
		if (startsWith(filename, 1)==1 && indexOf(filename, "night")>-1) {
		setThreshold(91, 255);
		}
		if (startsWith(filename, 3)==1 && indexOf(filename, "night")>-1) {
		setThreshold(90, 255);
		}
		if (startsWith(filename, 3)==1 && indexOf(filename, "night")>-1) {
		setThreshold(85, 255);
		}
		if (startsWith(filename, 4)==1 && indexOf(filename, "night")>-1) {
		setThreshold(74, 255);
		}
		
		setOption("BlackBackground", false);
		run("Convert to Mask");
		run("Median...", "radius=3");
		run("Options...", "iterations=5 count=1 edm=8-bit do=Close");
		run("Skeletonize");	
///////////////////////////

		run("Analyze Skeleton (2D/3D)", "prune=none show display");

		selectWindow("Results");
		run("Close");
		IJ.renameResults("Branch information", "Results");

//refining results table to just get "Skeleton ID" and "Branch length"
//also extracts genotype from roi manager, date and time from file name

		nR = nResults ;
		skID = newArray(nR);
		skBL = newArray(nR);
		
		part = split(filename, "-");
		geno = part[0];
		date = part[2];
		time = part[3]; 
	
		
		for (v = 0; v <nR;v++) {
			skID[v] = getResult("Skeleton ID", v);
			skBL[v] = getResult("Branch length", v);
		}
		selectWindow("Results");
		run("Close");
		if (w>0) {
			IJ.renameResults("Skeleton Summary", "Results");
		}
		for (v = 0; v <nR;v++) {
			nRes = nResults;
			setResult("Label", nRes, filename);
			setResult("Skeleton ID", nRes, skID[v]);
			setResult("Branch length", nRes, skBL[v]);
			setResult("Genotype", nRes, geno); 
			setResult("Date", nRes, date);
			setResult("Time", nRes, time);
			}
		updateResults();
		IJ.renameResults("Results", "Skeleton Summary");
			
		selectImage("Tagged skeleton");
		close();
		selectImage(filename+"-labeled-skeletons");
		saveAs("Tiff", skeleton+filename+"labeledskel"+".txt");
		close();
		selectImage(File.name);
		saveAs("Tiff", skeleton+filename+".txt");
		close();		
	}
		selectWindow("Skeleton Summary");
		folder = list[i];
		slash = indexOf(folder, "/");
		foldername = substring(folder, 0, slash);
		saveAs("Text", subdir+"Skeleton Summary for "+foldername+".txt");
	}