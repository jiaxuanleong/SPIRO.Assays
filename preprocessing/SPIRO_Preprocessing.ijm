//requirements for file organization
//main directory containing all images sorted by plate into subdirectories
//requirements for image naming
//plate1-date20190101-time000000-day

//user selection of main directory
showMessage("Please locate and open your experiment folder.");
maindir = getDirectory("Choose a Directory");
list = getFileList(maindir);

resultsdir = maindir + "/Results/";
if (!File.isDirectory(resultsdir)) {
	File.makeDirectory(resultsdir);
}
preprocessingmaindir = resultsdir + "/Preprocessing/";
if (!File.isDirectory(preprocessingmaindir)) {
	File.makeDirectory(preprocessingmaindir);
}
regq = getBoolean("Would you like to carry out drift correction (registration)?\n" +
    "Please note that this step may take up a lot of time and computer memory for large datasets.");

segmentsize = 350;
processMain1(maindir);

list = getList("window.titles");
for (i=0; i<list.length; i++) {
    winame = list[i];
    selectWindow(winame);
    run("Close");
}

///set up recursive processing of a main directory which contains multiple subdirectories   
function processMain1(maindir) {
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/") && !endsWith(list[i], "Results/")) {
			subdir = maindir + list[i];
			sublist = getFileList(subdir);
			platename = File.getName(subdir);
			if (sublist.length < segmentsize) {
			    processSubdir(subdir);
			} else {
				processSubdirSegmented(subdir);
			}
		}
	}
}

// process files in a subdirectory
function processSubdir(subdir) {
	print("Processing " + subdir + "...");
	preprocessingsubdir = preprocessingmaindir+ "/" + platename + "/";
	if (!File.isDirectory(preprocessingsubdir)) {
		File.makeDirectory(preprocessingsubdir);
	}
	setBatchMode(false);
	run("Image Sequence...", "open=[" + subdir + sublist[0] + "]+convert sort use");
	stack1 = getTitle();
	scale();
	crop();
	if (regq) {
	    // calling register with argument 'false' means non-segmented registration
        register(false);
        saveAs("Tiff", preprocessingsubdir + platename + "_preprocessed.tif");
        close(platename + "_preprocessed.tif");
	} else {
		selectWindow(stack1);
		saveAs("Tiff", preprocessingsubdir + platename + "_preprocessed.tif");
		close(platename + "_preprocessed.tif");
	}
}

// process files in a subdirectory, dividing images into separate batches
function processSubdirSegmented(subdir) {
	preprocessingsubdir = preprocessingmaindir+ "/" + platename + "/";
	tempdirsegmented = preprocessingsubdir + "/temp/";
	if (!File.isDirectory(preprocessingsubdir)) {
		File.makeDirectory(preprocessingsubdir);
	}
	if (!File.isDirectory(tempdirsegmented)) {
	    File.makeDirectory(tempdirsegmented);
	}
	setBatchMode(false);
	print("Processing " + subdir + "...");
	if (platename = "plate1") {
	    showMessage(sublist.length + " time points detected. Images will be preprocessed in batches of " +
	        segmentsize + " to reduce RAM requirement.");
	}
	numloops = sublist.length / segmentsize; // number of loops

	rnl = floor(numloops) + 1; //returns closest integer rounded down
	
	for (x=0; x<numloops; x++) {
		print("Processing batch " + x+1);
		initial = x*segmentsize;
		if (x == numloops-1) { //on last loop
			lastno = sublist.length - initial + 1; //open only the number of images left
			run("Image Sequence...", "open=[" + subdir + sublist[0] + "] number=" + lastno +
			    " starting=" + initial+1 + " convert sort use");
		} else {
		    run("Image Sequence...", "open=[" + subdir + sublist[0] + "] number=" + segmentsize +
		        " starting=" + initial+1 + " convert sort use");
		}
		stack1 = getTitle();
		if (x == 0) {
			scale();
		} else {
			length = Table.get("Length", 0, "Positions");
			run("Set Scale...", "distance=" + length + " known=1 unit=cm global");
		}
		crop();
		if (regq) {
		    // calling register() with argument 'true' runs it in segmented mode
			register(true);
		} else {
			selectWindow(stack1);
			saveAs("Tiff", tempdirsegmented + x);
		}
	}
	tempdirsegmentedlist = getFileList(tempdirsegmented);
	for (x=0; x<tempdirsegmentedlist.length-1; x++) {
		if (x == 0) {
		    run("Concatenate...", "  image1=[" + x + ".tif" + "] image2=[" + x+1 + ".tif" + "]");
		} else {
			run("Concatenate...", "  image1=[Untitled] image2=[" + x+1  + ".tif" + "]");
		}
	}
	selectWindow("Untitled");
	saveAs("Tiff", preprocessingsubdir + platename + "_preprocessed.tif");
	close(platename + "_preprocessed.tif");
	
	for (x=0; x<tempdirsegmentedlist.length; x++) {
		if (File.exists(tempdirsegmented+tempdirsegmentedlist[x])) {
			File.delete(tempdirsegmented+tempdirsegmentedlist[x]);
		}
	}
	File.delete(tempdirsegmented);
}

function scale() {
	print("Setting scale...");
	if (platename == "plate1") {
		run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel global");
		setTool("line");
        run("Set Measurements...", "area bounding display redirect=None decimal=3");
        waitForUser("Setting the scale." +
            "Please zoom in on the scale bar and hold the SHIFT key while drawing a line corresponding to 1cm.");
        run("Measure");
        length = getResult('Length', nResults - 1);
        while (length == 0 || isNaN(length)) {
            waitForUser("Line selection required.");
            run("Measure");
            length = getResult('Length', nResults - 1);
        }
        angle  = getResult('Angle', nResults - 1);
        while (angle != 0 && angle != 180) {
            waitForUser("Line must not be at an angle.");
            run("Measure");
            angle  = getResult('Angle', nResults - 1);
        }
        Table.rename("Results", "Positions");
        waitForUser("1 cm corresponds to " + length + " pixels. Click OK if correct.");
        run("Set Scale...", "distance=" + length + " known=1 unit=cm global");
    } else {
        length = Table.get("Length", 0, "Positions");
        run("Set Scale...","distance=" + length + " known=1 unit=cm global");
    }
}

//for cropping of images into a smaller area to allow faster processing
function crop() {
	print("Cropping...");
	nR = Table.size;
	bx = Table.get("BX", nR - 1, "Positions");
	by = Table.get("BY", nR - 1, "Positions");
	length = Table.get("Length", nR - 1, "Positions");
	xmid = (bx + length/2);
	dx = 13;
	dy = 10.5;
	toUnscaled(dx, dy);
	x1 = xmid - dx;
	y1 = by - dy;
	width = 14;
	height = 12.5;
	toUnscaled(width, height);
	makeRectangle(x1, y1, width, height);
	run("Crop");
}

function register(segmented) {
    print("Registering...");
    if (segmented) {
        open(subdir + sublist[0]); //open first time point
        crop();
        run("8-bit");
        tempini = getTitle();
        //stick first time point to stack, to enable more accurate registration for later time points
        run("Concatenate...", "  image1=[" + tempini + "] image2=[" + stack1 + "]");
        stack1 = getTitle();
    }
    run("8-bit");
    run("Duplicate...", "duplicate");
    stack2 = getTitle();
    run("Subtract Background...", "rolling=30 stack");
    tfn = preprocessingsubdir + "Transformation";
    run("MultiStackReg", "stack_1=" + stack2 + " action_1=Align file_1=" + tfn +
        " stack_2=None action_2=Ignore file_2=[] transformation=Translation save");
    close(stack2);
    run("MultiStackReg", "stack_1=" + stack1 + " action_1=[Load Transformation File] file_1=" + tfn +
        " stack_2=None action_2=Ignore file_2=[] transformation=[Translation]");
    File.delete(tfn);
    selectWindow(stack1);
    if (segmented) {
        run("Slice Remover", "first=1 last=1 increment=1"); //remove temporary first slice
        saveAs("Tiff", tempdirsegmented + x + ".tif");
    }
}
