/* first detect if batch needed, then get user choice
 * if batch not needed, crop, greench, and register in one go (no intermediate files)
 * if batch needed, separate into segments during run image sequence, save directly in preprocessing (no new folder)
 * use _batchN to denote batch, and plateN can be used to identify it
 * Crop and GreenCh: run as usual on the list of files
 * 		crop then immediately greenCh to make plateN_batchN_greenCh
 * Register: Open greenCh and add first image to each stack (to prevent jumps between batches), save each batch
 * At the end, merge all plateN_batchN preprocessed to make plateN_preprocessed
 */

// processing loops by function > plate > group > time point
// hierarchy of folders maindir > resultsdir > platedir > groupdir > output files

/*
 * GLOBAL VARIABLES
 * ================
 */

var maindir;	// main directory
var platedir; //plate directories in main directory
var listInplatedir; // number of time points 
var resultsdir;	// results subdir of main directory
var ppdir;		// preprocessing subdir
var curplate;	// number of current plate being processed
var runRegistration // user choice on whether to run registration
var batchsize = 350;
var batched // if number of time points exceeds batchsize, preprocessing will be carried out in batches
var rbatched = 1;
var rNonbatched = 2;

// alternate types of macro run
var DEBUG = false; // hold down crtl during macro start to keep non-essential intermediate output files
var freshstart = false; // hold down shift key during macro start to delete all previous data

if (isKeyDown("control"))
	DEBUG = getBoolean("CTRL key pressed. Run macro in debug mode? Batch size for drift correction can be changed.");

if (isKeyDown("shift"))
	freshstart = getBoolean("SHIFT key pressed. Run macro in Fresh Start mode? This will delete all data from the previous run.");

// check whether the required plugins TurboReg and MultiStackReg are installed
List.setCommands;
if(List.get("TurboReg ")!="") {
	turboreginstalled = true;
} else {
	turboreginstalled = false;
}
if(List.get("MultiStackReg")!="") {
	multistackreginstalled = true;
} else {
	multistackreginstalled = false;
}
if (!turboreginstalled || !multistackreginstalled) {
	Dialog.create("Plugin not found");
	Dialog.addMessage("Plugins TurboReg and/or MultiStackReg not found. Please refer to SPIRO manual for installation instructions.");
	Dialog.addCheckbox("I understand.", false);
	Dialog.show();
	usercheck = Dialog.getCheckbox();
	if (usercheck == true)
		exit;
}

print("Welcome to the companion macro of SPIRO for preprocessing!");
selectWindow("Log");

maindir = getDirectory("Choose a Directory");
listInmaindir = getFileList(maindir);
resultsdir = maindir + "Results" + File.separator; // all output is contained here
ppdir = resultsdir + "Preprocessing" + File.separator; // output from the proprocessing macro is here

if (!File.isDirectory(resultsdir))
	File.makeDirectory(resultsdir);
	
if (!File.isDirectory(ppdir))
	File.makeDirectory(ppdir);

//makes sure to not preprocess non-plate (user-introduced) file processed
for (fileindex = 0; fileindex < listInmaindir.length; fileindex++) {
	if (indexOf(listInmaindir[fileindex], "plate") == -1)
		listInmaindir = Array.deleteValue(listInmaindir, listInmaindir[fileindex]); 
}

/*
 * Ask for user choice on drift correction 
 * =======================================
 */
Dialog.create("Drift Correction");
Dialog.addMessage("Would you like to carry out drift correction (registration)?\n" +
    "Please note that this step may take up a lot of time and RAM for large datasets.\n" +
    "Batch size may be reduced in DEBUG mode for lower RAM requirement");
dialogchoices = newArray("Yes", "No");
Dialog.addChoice("", dialogchoices);
Dialog.show;
regUserInput = Dialog.getChoice();

if (regUserInput == "Yes") {
	runRegistration = true;
} else {
	runRegistration = false;
}

if (DEBUG && runRegistration)
	Dialog.create("(DEBUG) Drift Correction Batch Size");
Dialog.addMessage("Drift correction (registration) may be carried out in smaller batches of the image stack to reduce RAM requirement.\n"
	+ "Please set desired batch size");
Dialog.addNumber("Batch size", batchsize);

/*
 * Main chunk of code
 * ============================================
 */

if (freshstart)
	deleteOutput();
scale();
batch(); 
cropnGreenCh();
if (runRegistration) {
	if (batched)
		register(rbatched);
	if (!batched)
		register(rNonbatched);
} else {
	print("Step 4/4 Drift correction skipped");
}
deleteOutput();

list = getList("window.titles");
list = Array.deleteValue(list, "Log");
for (i=0; i<list.length; i++) {
	winame = list[i];
	selectWindow(winame);
	run("Close");
}

print("\nPreprocessing is complete.");
selectWindow("Log");

/*
 * End main chunk of code
 * ======================
 */

function scale() {
	if (is("Batch Mode"))
		setBatchMode(false);
	print("Step 1/4 Setting scale...");
	plate1dir = maindir + listInmaindir[0]; // only first image of first plate needed to set scale
	listInplate1dir = getFileList(plate1dir);
	img1 = listInplate1dir[0];
	open(plate1dir + img1);
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel global");
	setTool("line");
    run("Set Measurements...", "area bounding display redirect=None decimal=3");
    userconfirm = false;
	while (!userconfirm) { 
		Dialog.createNonBlocking("Set Scale");
		Dialog.addMessage("Please zoom in on the scale bar on the bottom right, then hold the SHIFT key while drawing a line corresponding to 1cm.");
		Dialog.addCheckbox("Scale bar corresponding to 1cm has been drawn", false);
		Dialog.show();
		userconfirm = Dialog.getCheckbox();
	}
	run("Set Measurements...", "area bounding display redirect=None decimal=3");
	run("Measure");
    length = getResult('Length', nResults - 1);
	if (userconfirm && !isNaN(length)) {
		run("Set Scale...", "distance=" + length + " known=1 unit=cm global");
	}
	Table.rename("Results", "scalebar");

	/*
	 * get coordinates to crop and prints it to a table for the crop function
	 */
	nR = Table.size("scalebar");
	bx = Table.get("BX", nR - 1, "scalebar");
	by = Table.get("BY", nR - 1, "scalebar");
	length = Table.get("Length", nR - 1, "scalebar");
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
	userconfirm = false;
	while (!userconfirm) { 
		Dialog.createNonBlocking("Crop selection");
		Dialog.addMessage("If needed, please correct the selected area for cropping, then click OK.");
		Dialog.addCheckbox("Selection has been made", false);
		Dialog.show();
		userconfirm = Dialog.getCheckbox();
	}
	getBoundingRect(xcrop, ycrop, wcrop, hcrop);
	Table.create("cropcoordinates");
	Table.set("xcrop", 0, xcrop, "cropcoordinates");
	Table.set("ycrop", 0, ycrop, "cropcoordinates");
	Table.set("wcrop", 0, wcrop, "cropcoordinates");
	Table.set("hcrop", 0, hcrop, "cropcoordinates");
	close();
	selectWindow("scalebar");
	run("Close");
}

function batch() {
	if (!is("Batch Mode"))
		setBatchMode(true);
	print("\nStep 2/4 Detecting number of time points to determine batch mode");
	for (plateno = 0; plateno < listInmaindir.length; plateno ++) {
		platefolder = listInmaindir[plateno];
		platedir = maindir + platefolder;
		platename = File.getName(platedir);
		listInplatedir = getFileList(platedir);
		numtp = listInplatedir.length; // number of time points
		if (numtp > batchsize) {
			batched = true;
			if (plateno == 0) 
				print(numtp + " time points detected. Separating files into batches of size " + batchsize + "...");
			numloops =  numtp / batchsize; // number of loops to make batches
			rnl = floor(numloops) + 1; //returns closest integer rounded down
			
			for (batchloop = 0; batchloop < numloops; batchloop ++) {
				initial = batchloop * batchsize;
				if (batchloop != numloops - 1) { 
					run("Image Sequence...", "open=[" + platedir + listInplatedir[0] + "] number=" + batchsize +
						" starting=" + initial+1 + " convert_to_rgb use");
					saveAs("Tiff", ppdir + platename + "_batch" + batchloop+1 + ".tif");
					close();
				} else { //on last loop
				   lastno = numtp - initial + 1; //open only the number of images left
					run("Image Sequence...", "open=[" + platedir + listInplatedir[0] + "] number=" + lastno +
					    " starting=" + initial+1 + " convert_to_rgb use");
					saveAs("Tiff", ppdir + platename + "_batch" + batchloop+1 + ".tif");
					close();
				}
			}
		} else {
			batched = false;
			if (plateno == 0) 
				print(numtp + " time points detected. Preprocessing will be carried out in non-batch mode");
			run("Image Sequence...", "open=[" + platedir + listInplatedir[0] + "] number=" + numtp +
						" starting=1 convert_to_rgb use");
					saveAs("Tiff", ppdir + platename + ".tif");
			close();
		}
	}
}

function cropnGreenCh() {
	if (!is("Batch Mode"))
		setBatchMode(true);
	print("\nStep 3/4 Cropping off unnecessary background and splitting into green channel...");
	listInppdir = getFileList(ppdir);
	for (fileno = 0; fileno < listInppdir.length; fileno ++) {
		open(ppdir + listInppdir[fileno]);
		ppstack = getTitle();
		ppstackname = File.nameWithoutExtension;
		print("Processing " + ppstackname);
		
		/*
		 * Crop based on position of scale bar (with user checking in scale step)
		 */
		xcrop = Table.get("xcrop", 0, "cropcoordinates");
		ycrop = Table.get("ycrop", 0, "cropcoordinates");
		wcrop = Table.get("wcrop", 0, "cropcoordinates");
		hcrop = Table.get("hcrop", 0, "cropcoordinates");
		makeRectangle(xcrop, ycrop, wcrop, hcrop);
		run("Crop");

		/* 
		 * Split into green channel
		 */

		selectWindow(ppstack);
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
					rename(ppstack);
		    }
			if (indexOf(imgname, "blue") > 0) {
				selectWindow(imgname);
				close(); 
			}
		}
		
		saveAs("Tiff", ppdir + ppstackname + "_GreenCh.tif");
		close();			 
		filedelete = File.delete(ppdir + ppstackname + ".tif");
	}
	selectWindow("cropcoordinates");
	run("Close");
}


function register(rMode) {
	if (!is("Batch Mode"))
		setBatchMode(true);
	print("\nStep 4/4 Correcting drift...\n It may look like nothing is happening, please be patient");
	listInppdir = getFileList(ppdir);
	listInppdirlength = listInppdir.length;

	if (rMode == rNonbatched) {
		for (plateno = 0; plateno < listInppdir.length; plateno ++) {
			grplatefile = listInppdir[plaS69-LNS8-FZ8P-S9B2teno]; //GREENCH
			grplatename = File.getName(ppdir + grplatefile);
			pfsplit = split(grplatename, "_");
			platename = pfsplit[0];
			print("Processing " + platename); 
			open(ppdir + grplatename);

			run("Subtract Background...", "rolling=30 stack");
		    tfn = ppdir + "Transformation";
		    run("MultiStackReg", "stack_1=" + grplatename + " action_1=Align file_1=" + tfn +
		        " stack_2=None action_2=Ignore file_2=[] transformation=Translation save");
		    close(grplatename);
		    open(ppdir + grplatename);
		    run("MultiStackReg", "stack_1=" + grplatename + " action_1=[Load Transformation File] file_1=" + tfn +
		        " stack_2=None action_2=Ignore file_2=[] transformation=[Translation]");
		    saveAs("Tiff", ppdir + platename + "_preprocessed.tif");
		    close();
		    filedelete = File.delete(ppdir + grplatename);
		}
	}

	if (rMode == rbatched) {
		listInppdir = getFileList(ppdir);
		listInppdirlength = listInppdir.length;
		for (plateno = 0; plateno < listInmaindir.length; plateno ++) {
			platemain = listInmaindir[plateno];
			platename = File.getName(maindir + platemain);
			print("Processing " + platename);
			// to get plate name without getting distracted by batchN
			batchfilearray = newArray(listInppdir.length);
			for (fileno = 0; fileno < listInppdir.length; fileno ++) {
				filename = listInppdir[fileno];
				if (indexOf(filename, platename) > -1) {
					batchfilearray[fileno] = filename;
				}
			}
			
			for (arrayindex = 0; arrayindex < listInppdirlength; arrayindex ++) {	
				if (batchfilearray[arrayindex] == 0) {
					batchfilearray = Array.deleteIndex(batchfilearray, arrayindex);
					listInppdirlength -= 1;
					arrayindex -= 1;
				}
			}

			for (batchno = 1; batchno < batchfilearray.length+1 ; batchno ++) {
				open(ppdir + platename + "_batch" + batchno + "_GreenCh.tif");
				batchsubstack = getTitle();
				if (batchno == 1) {
					setSlice(1);
					run("Duplicate...", "use");
					rename("firstslice");
				}
				selectWindow("firstslice");
				run("Duplicate...", "use");
				rename("tempfirstslice");
				run("Concatenate...", "  image1=tempfirstslice image2=["+ batchsubstack +"]"); //stick first slice to start of each batch to enable better registration
				rename("batchsubstackSB");
				run("Subtract Background...", "rolling=30 stack");
			    tfn = ppdir + "Transformation";
			    run("MultiStackReg", "stack_1=batchsubstackSB action_1=Align file_1=" + tfn +
			        " stack_2=None action_2=Ignore file_2=[] transformation=Translation save");
			    close("batchsubstackSB");
			    open(ppdir + batchsubstack);
			    selectWindow("firstslice");
				run("Duplicate...", "use");
				rename("tempfirstslice");
			    run("Concatenate...", "  image1=tempfirstslice image2=["+ batchsubstack +"]"); //stick first slice to start of each batch to enable better registration
			    rename(batchsubstack);
			    run("MultiStackReg", "stack_1=" + batchsubstack + " action_1=[Load Transformation File] file_1=" + tfn +
			        " stack_2=None action_2=Ignore file_2=[] transformation=[Translation]");
			 	run("Slice Remover", "first=1 last=1 increment=1"); //remove temporary first slice
				saveAs("Tiff", ppdir + platename + "_batch" + batchno + "_preprocessed.tif");
				close();
				filedelete = File.delete(ppdir + batchsubstack);
			}

			batch1filedir = ppdir + platename + "_batch1_preprocessed.tif";
			open(batch1filedir);
			batch1stack = getTitle();
				
			for (batchno = 2; batchno < batchfilearray.length+1; batchno++) {
				batchNfiledir = ppdir + platename + "_batch" + batchno + "_preprocessed.tif";
				open(batchNfiledir);
				batchNstack = getTitle();
				if (batchno == 2) {
					run("Concatenate...", "  image1=["+ batch1stack +"] image2=["+ batchNstack +"]"); 
				concatbatches = getTitle();
				} else {
					run("Concatenate...", "  image1=["+ concatbatches +"] image2=["+ batchNstack +"]"); 
				}
			}
			saveAs("Tiff", ppdir + platename + "_preprocessed.tif");
		    close();
		    selectWindow("firstslice");
		    close();
		}
	}
}

function deleteOutput() {
	print("Deleting intermediate files...");
	listInppdir = getFileList(ppdir);
	for (ppfileno = 0; ppfileno < listInppdir.length; ppfileno ++) {
		ppfilename = listInppdir[ppfileno];
		if (indexOf(ppfilename, "batch") > -1) 
			filedelete = File.delete(ppdir + ppfilename);
		if (indexOf(ppfilename, "GreenCh") > -1)
			filedelete = File.delete(ppdir + ppfilename);
	}
	if (freshstart) {
		print("Fresh start: deleting output from any previous run");
		for (ppfileno = 0; ppfileno < ppdirlist.length; ppfileno ++) {
			ppfilename = ppdirlist[ppfilename];
			filedelete = File.delete(ppdir + ppfilename);
		}
	freshstart == false;
	}
}
