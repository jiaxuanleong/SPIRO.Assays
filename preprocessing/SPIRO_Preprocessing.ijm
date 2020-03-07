//requirements for file organization
//main directory containing all images sorted by plate into subdirectories
//requirements for image naming
//plate1-date20190101-time000000-day
//this macro requires that TurboReg (EPFL) and MultiStackReg (Brad Busse) macros are installed

//user selection of main directory
setBatchMode(false);
showMessage("Please locate and open your experiment folder.");
maindir = getDirectory("Choose a Directory");
list = getFileList(maindir);
for (a=0; a<list.length; a++) {
	if (indexOf(list[a], "plate") < 0)
		list = Array.deleteValue(list, list[a]); //makes sure any non-plate folder isnt processed
}
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

scale();
getCropCoordinates();
processMain1();

list = getList("window.titles");
for (i=0; i<list.length; i++) {
    winame = list[i];
    selectWindow(winame);
    run("Close");
}

///set up recursive processing of a main directory which contains multiple subdirectories   
function processMain1() {
	for (i=0; i<list.length; i++) {
		plateanalysisno = i;
		subdir = maindir + list[i];
		sublist = getFileList(subdir);
		platename = File.getName(subdir);
		if (sublist.length < segmentsize) {
			processSubdir();
		} else {
			if (plateanalysisno == 0) {
			   showMessage(sublist.length + " time points detected. Images will be preprocessed in batches of " +
			   segmentsize + " to reduce RAM requirement.");
			}
			processSubdirSegmented();
		}
	}
}

function scale() {
	print("Setting scale...");
	for (i=0; i<list.length; i++) {
		plateanalysisno = i;
		subdir = maindir + list[i];
		sublist = getFileList(subdir);
		platename = File.getName(subdir);
		open(subdir + sublist[0]);
		
		if (plateanalysisno == 0) {
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
	            waitForUser("Line must not be at an angle! Please correct then click OK.");
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
	    close();
	}
}

function getCropCoordinates() {
	print("Getting crop coordinates...");
	for (i=0; i<list.length; i++) {
		plateanalysisno = i;
		subdir = maindir + list[i];
		sublist = getFileList(subdir);
		platename = File.getName(subdir);
		open(subdir+sublist[0]);
		//automatically calculates the relevant area of SPIRO-acquired images, based on the position of scale bar drawn

		if (plateanalysisno == 0) {
		nR = Table.size("Positions");
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
		} else {
			makeRectangle(x1, y1, width, height);
		}
		waitForUser("If needed, please correct the selected area for crop, then click OK.");
		if (plateanalysisno == 0) {
			cropcoord = "Crop Coordinates";
			Table.create(cropcoord);
		}
		roibounds = Roi.getBounds(roiboundx, roiboundy, roiboundwidth, roiboundheight);
		nr = plateanalysisno;
		Table.set("X", nr, roiboundx, cropcoord);
		Table.set("Y", nr, roiboundy, cropcoord);
		Table.set("Width", nr, roiboundwidth, cropcoord);
		Table.set("Height", nr, roiboundheight, cropcoord);
		close();
	}
}


function crop() {
		nr = plateanalysisno;
		cropcoord = "Crop Coordinates";
		roiboundx = Table.get("X", nr, cropcoord);
		roiboundy = Table.get("Y", nr, cropcoord);
		roiboundwidth = Table.get("Width", nr, cropcoord);
		roiboundheight = Table.get("Height", nr, cropcoord);
		makeRectangle(roiboundx, roiboundy, roiboundwidth, roiboundheight);
		run("Crop");
}


// process files in a subdirectory
function processSubdir() {
	print("Processing " + platename + "...");
	run("Image Sequence...", "open=[" + subdir + sublist[0] + "]+convert sort use");
	stack1 = getTitle();
	crop();
	if (regq) {
	    // calling register with argument 'false' means non-segmented registration
        register(false);
        saveAs("Tiff", preprocessingmaindir + platename + "_preprocessed.tif");
        close(platename + "_preprocessed.tif");
	} else {
		selectWindow(stack1);
		saveAs("Tiff", preprocessingmaindir + platename + "_preprocessed.tif");
		close(platename + "_preprocessed.tif");
	}
}

// process files in a subdirectory, dividing images into separate batches
function processSubdirSegmented() {
	tempdirsegmented = preprocessingmaindir + "/temp/";
	if (!File.isDirectory(tempdirsegmented)) {
	    File.makeDirectory(tempdirsegmented);
	}
	setBatchMode(false);
	print("Processing " + subdir + "...");
	
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
	saveAs("Tiff", preprocessingmaindir + platename + "_preprocessed.tif");
	close(platename + "_preprocessed.tif");
	
	for (x=0; x<tempdirsegmentedlist.length; x++) {
		if (File.exists(tempdirsegmented+tempdirsegmentedlist[x])) {
			File.delete(tempdirsegmented+tempdirsegmentedlist[x]);
		}
	}
	File.delete(tempdirsegmented);
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
    tfn = preprocessingmaindir + "Transformation";
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


//splits RGB stack and only saves green channel
function splitGreenCh() {
	print("Saving green channel as separate file");
	for (ppdirno = 0; ppdirno < ppdirlist.length; ppdirno ++) {  //main loop through plates
		if (indexOf (ppdirlist[ppdirno], "preprocessed") > 0) { //to avoid processing any random files in the folder
			platefile = ppdirlist [ppdirno];
			fnsplit = split(platefile, "_");
			platename = fnsplit[0];
			platedir = resultsdir + "/" + platename + "/";
			if (!File.isDirectory(platedir))
				File.makeDirectory(platedir);
			print("Processing "+platename);
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
						saveAs("Tiff", platedir + platename + "substackGreenOnly.tif");
			    }
				if (indexOf(imgname, "blue") > 0) {
					selectWindow(imgname);
					close(); 
				}
			}
		}
	}
}