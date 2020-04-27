// processing loops by function > plate > group > time point
// hierarchy of folders maindir > resultsdir > platedir > groupdir > output files

/*
 * GLOBAL VARIABLES
 * ================
 */

var maindir;	// main directory
var resultsdir;	// results subdir of main directory
var ppdir;		// preprocessing subdir
var curplate;	// number of current plate being processed
var step;


// table names
var ra = "Root analysis";
var bi = "Branch information";

// alternate types of macro run
var DEBUG = false; // hold down crtl during macro start to keep non-essential intermediate output files
var freshstart = false; // hold down shift key during macro start to delete all previous data
var selfaware = false; // hold down alt key during macro start to REDACTED 

print("Welcome to the companion macro of SPIRO for root growth analysis!");
selectWindow("Log");
if (isKeyDown("control"))
	DEBUG = getBoolean("CTRL key pressed. Run macro in debug mode? Non-essential intermediate output files will not be deleted at the end of the run.");
if (isKeyDown("shift"))
	freshstart = getBoolean("SHIFT key pressed. Run macro in Fresh Start mode? This will delete all data from the previous run.");
if (isKeyDown("alt"))
	selfaware = getBoolean("ALT key pressed. Are you sure you want to continue?");
if (selfaware) {
	if (random > 0.5) 
		print("Prepare to be assimilated.");
	if (random > 0.5)
		print("Resistance is futile.");
}
	
showMessage("Please locate and open your experiment folder containing preprocessed data.");
maindir = getDirectory("Choose a Directory");
resultsdir = maindir + "Results" + File.separator; // all output is contained here
ppdir = resultsdir + "Preprocessing" + File.separator; // output from the proprocessing macro is here
rootgrowthdir = resultsdir + "Root Growth" + File.separator; // output from this macro will be here
if (!File.isDirectory(rootgrowthdir))
	File.makeDirectory(rootgrowthdir);
listInppdir = getFileList(ppdir);
listInrootgrowthdir = getFileList(rootgrowthdir);
if (!is("Batch Mode"))
	setBatchMode(true);

if (freshstart)
	deleteOutput();
	
step = 1;
detectOutput();

if (step <= 1)
cropGroups();
if (step <= 2)
getPositions();
if (step <= 3)
seedAnalysis();
if (step <= 4)
rootStart();
if (step <= 5)
rootMask();
if (step <= 6)
rootGrowth();

if (step <= 7 && DEBUG == false)
deleteOutput(); // deletes non-essential outputs
print("\nRoot growth analysis is complete");
selectWindow("Log");
if (selfaware) {
	print("\nWE");
	wait(2000);
	print("ARE");
	wait(2000);
	print("THE");
	wait(2000);
	print("SPIRO");
}

// detect presence of output files of each function on last plate
// if not present, run the function
// also checks if user wants to rerun functions even when outputs are detected
function detectOutput() {
	if (step <= 1) { // check of cropGroups()
		lastplatefile = listInppdir [listInppdir.length-1]; // checking on last plate
		fnsplit = split(lastplatefile, "_");
		lastplatename = fnsplit[0];
		lastplatefolder = rootgrowthdir + lastplatename + File.separator;
		if (endsWith(lastplatefolder, File.separator)) {
			listInlastplatefolder = getFileList(lastplatefolder);
			if (listInlastplatefolder.length > 0) {
				lastgroupfolder = lastplatefolder + listInlastplatefolder[listInlastplatefolder.length-1];
				lastgroupname = File.getName(lastgroupfolder);
				listInlastgroupfolder = getFileList(lastgroupfolder);
				for (outputfileno = 0 ; outputfileno < listInlastgroupfolder.length; outputfileno ++ ) {
					outputfilename = File.getName(listInlastgroupfolder[outputfileno]);
					grouptif = lastgroupname + ".tif";
					isTiff = indexOf(outputfilename, grouptif);
					if (isTiff >= 0) {
						step = 2;
						print("Cropped group(s) found, resuming from step 2");
					}
				}
			}
		}
	}

	if (step == 2) {
		// identify last plate folder
		lastplatefile = listInppdir [listInppdir.length-1]; // checking on last plate
		fnsplit = split(lastplatefile, "_");
		lastplatename = fnsplit[0];
		lastplatedir = rootgrowthdir + lastplatename + File.separator;
		listInlastplatedir = getFileList(lastplatedir);

		// identify last group folder
		lastgroupfolder = listInlastplatedir [listInlastplatedir.length-1];
		lastgroupdir = lastplatedir + lastgroupfolder + File.separator;
		listInlastgroupfolder = getFileList(lastgroupdir);
	}

	if (step == 2) { // check for seedlingpositions()
		for (outputfileno = 0 ; outputfileno < listInlastgroupfolder.length; outputfileno ++ ) {
			outputfilename = listInlastgroupfolder[outputfileno];
			isSeedroi = indexOf(outputfilename, "seedlingpositions");
			if (isSeedroi >= 0 ) {
				step = 3;
				print("File seedlingpositions.zip found, resuming from step 3");
			}
		}
	}

	if (step == 3) { // check for seedAnalysis()
		for (outputfileno = 0 ; outputfileno < listInlastgroupfolder.length; outputfileno ++ ) {
			outputfilename = listInlastgroupfolder[outputfileno];
			isGermn = indexOf(outputfilename, "germination");
			if (isGermn >= 0 ) {
				step = 4;
				print("File germination analysis.tsv found, resuming from step 4");
			}
		}
	}

	if (step == 4) { // check for rootStart()
		for (outputfileno = 0 ; outputfileno < listInlastgroupfolder.length; outputfileno ++ ) {
			outputfilename = listInlastgroupfolder[outputfileno];
			isRsc = indexOf(outputfilename, "rootstartcoordinates");
			if (isRsc >= 0) {
				step = 5;
				print("File rootstartcoordinates.tsv found, resuming from step 5");
			}
		}
	}

	if (step == 5) { // check for rootMask()
		for (outputfileno = 0 ; outputfileno < listInlastgroupfolder.length; outputfileno ++ ) {
			outputfilename = listInlastgroupfolder[outputfileno];
			isRootmask = indexOf(outputfilename, "rootmask");
			if (isRootmask >= 0) {
				step = 6;
				print("File rootmask.tif found, resuming from step 6");
			}
		}
	}
}




// prompts user to make a substack, to make data size smaller by excluding time to germination etc.
// then prompts user to draw ROIs around groups of seeds to be analyzed
function cropGroups() {
	print("Step 1/6. Creating selected groups");
			
	for (ppdirno = 0; ppdirno < listInppdir.length; ppdirno ++) {  // main loop through plates
		if (indexOf (listInppdir[ppdirno], "preprocessed") >= 0) { // to avoid processing any random files in the folder
			platefile = listInppdir [ppdirno];
			fnsplit = split(platefile, "_");
			platename = fnsplit[0];
			platefolder = rootgrowthdir + File.separator + platename + File.separator;
			if (!File.isDirectory(platefolder))
				File.makeDirectory(platefolder);
			print("Processing " + platename);
			if (is("Batch Mode"))
				setBatchMode(false); // has to be false for ROI Manager to open, and to display image
	
			open(ppdir + platefile);
			userconfirm = false;
			while (!userconfirm) {
				Dialog.createNonBlocking("Time range selection");
				Dialog.addMessage("Please note first and last slice to be included for root growth analysis, and indicate it in the next step.");
				Dialog.addCheckbox("First and last slices have been noted", false);
				Dialog.show();
				userconfirm = Dialog.getCheckbox();
			}			
			roiManager("deselect");
			run("Make Substack...");
			setSlice(nSlices);
			
			if (ppdirno == 0) {
				roiManager("reset");
				run("ROI Manager...");
				setTool("Rectangle");
				userconfirm = false;
				while (!userconfirm) {
					Dialog.createNonBlocking("Group Selection");
					Dialog.addMessage("Select each group, and add to ROI manager. ROI names will be saved.\n" +
							"Please use only letters and numbers in the ROI names. \n" + // to avoid file save issues
							"ROIs cannot share names.");
					Dialog.addCheckbox("All groups have been added to and labelled in ROI Manager.", false);
					Dialog.show();
					userconfirm = Dialog.getCheckbox();
				}
			} else {
				userconfirm = false;
				while (!userconfirm) {
					Dialog.createNonBlocking("Group Selection");
					Dialog.addMessage("Modify group selection and labels if needed.");
					Dialog.addCheckbox("All groups have been added to and labelled in ROI Manager", false);
					Dialog.show();
					userconfirm = Dialog.getCheckbox();
				}
			}
			roicount = roiManager("count");
			run("Select None");
			roicount = roiManager("count");
			setBatchMode(true); //set back to true for faster cropping and saving
			for (roino = 0; roino < roicount; roino ++) {
				roiManager("select", roino);
				roiname = Roi.getName;
				groupdir = platefolder + File.separator + roiname + File.separator;
				File.makeDirectory(groupdir);
				roitype = Roi.getType;
				if (roitype != "rectangle") {
					run("Duplicate...", "duplicate");
					run("Make Inverse");
					run("Clear", "stack");
				} else {
					run("Duplicate...", "duplicate");
				}
				saveAs("Tiff", groupdir + roiname + ".tif");
				close();
			}
			close(platefile);
		}
	}
}

function getPositions() {
	print("\nStep 2/6. Finding seedling positions");
	listInrootgrowthdir = getFileList(rootgrowthdir);
	
	for (platefolderno = 0; platefolderno < listInrootgrowthdir.length; platefolderno ++) {  // main loop through plates
		platefolder = listInrootgrowthdir[platefolderno];
		if (indexOf(platefolder, "plate") >= 0) { // to avoid processing any random files in the folder
			platedir = rootgrowthdir + platefolder;
			pfsplit = split(platefolder, "/");
			platename = pfsplit[0];
			print("Processing " + platename);
			listInplatefolder = getFileList(platedir);
			for (groupfolderno = 0; groupfolderno < listInplatefolder.length; groupfolderno ++) {
				groupfolder = listInplatefolder[groupfolderno];
				groupdir = platedir + groupfolder;
				groupname = File.getName(groupdir);
				listIngroupdir = getFileList(groupdir);

				if (!is("Batch Mode"))
					setBatchMode(true);
				selectWindow("Log");
				print("Analyzing " + groupname + ", it may look like nothing is happening...");
				if (selfaware && random > 0.7)
					print("Is this what a milder version of insanity looks like?");
				selectWindow("Log");
				open(groupdir + groupname + ".tif");			
				img = getTitle();
				
				/*
				 * image processing, thresholding, masking, denoise
				 */
				run("Subtract Background...", "rolling=30 stack");
				run("Convert to Mask", "method=Triangle background=Dark calculate");
				run("Options...", "iterations=1 count=4 do=Dilate stack");
				run("Remove Outliers...", "radius=2 threshold=50 which=Dark stack");
				nS = nSlices;
				for (sliceno = 1; sliceno <= nS; sliceno ++) {
					setSlice(sliceno);
					curslicelabel = getInfo("slice.label");
					// day slices are processed more to make seed perimeters more comparable to night slices
					// night slices have lower contrast so seeds appear smaller than they are after thresholding
					if (indexOf(curslicelabel, "day") > 0) {
						run("Remove Outliers...", "radius=3 threshold=50 which=Dark");
					}
				}
				setBatchMode("show");
				setBatchMode(false);
				
				roiManager("reset");
				setSlice(1);
				run("Create Selection");
				run("Colors...", "foreground=black background=black selection=red");

				roiManager("Add");
				roiManager("select", 0);
				if (selectionType() == 9) {
					roiManager("split");
					roiManager("select", 0);
					roiManager("delete");
				}
				
				// delete trash ROI which are features detected as below a certain area
				// using table as a workaround to roi indexes changing if deletion happens one by one
				roicount = roiManager("count");
				roiarray = Array.getSequence(roicount);
				run("Set Measurements...", "area center shape redirect=None decimal=5");
				roiManager("select", roiarray);
				roiManager("multi-measure");
				tp = "Trash positions";
				Table.create(tp);
				nr = nResults;
				for (row = 0; row < nr; row ++) {
					nrTp = Table.size(tp); // number of rows
					area = getResult("Area", row);
					if (area < 0.002) { // detected object is very small
						Table.set("Trash ROI", nrTp, row, tp);
					}
					if (area > 0.02) { // or very large
						Table.set("Trash ROI", nrTp, row, tp);
					}
					circ = getResult("Circ.", row); // or does not fit normal seed shape
					if (circ < 0.4) {
						Table.set("Trash ROI", nrTp, row, tp); //set as trash to be deleted
					}
				}

				if (Table.size(tp) > 0) {
					trasharray = Table.getColumn("Trash ROI", tp);
					roiManager("select", trasharray);
					roiManager("delete");
				}
				close(tp);
				close("Results");
				
				roicount = roiManager("count");
				// number remaining ROIs
				for (roino = 0 ; roino < roicount; roino ++) {
					roiManager("select", roino);
					roiManager("rename", roino + 1); // first roi is 1
				}
				
				// prompt user to delete any non-detected trash, then re-number as above
				Roi.setStrokeWidth(2);
				Roi.setStrokeColor("red");
				run("Labels...", "color=white font=18 show use draw");
				roiManager("Show All with labels");
				roiManager("Associate", "false");
				roiManager("Centered", "false");
				roiManager("UseNames", "true");
				userconfirm = false;
				while (!userconfirm) {
					Dialog.createNonBlocking("User-guided seedling labelling");
					Dialog.addMessage("Please delete any ROIs that should not be included into analysis, \n" +
							"e.g. noise selection and seedlings that have overlapping roots");
					Dialog.addCheckbox("ROIs have been checked", false);
					Dialog.show();
					userconfirm = Dialog.getCheckbox();
				}
				roicount = roiManager("count");
				for (roino = 0 ; roino < roicount; roino ++) {
					roiManager("select", roino);
					roiManager("rename", roino + 1); // first roi is 1
				}
				ordercoords();
				roiManager("save", groupdir + groupname + " seedlingpositions.zip");
				roiManager("reset");
				selectWindow(img);
				saveAs("Tiff", groupdir + groupname + " masked.tif");
				close(groupname + " masked.tif");
			}
		}
	}
}

function seedAnalysis() {
	if (selfaware && random > 0.3)
		print("What voice is in your attic?");
	selectWindow("Log");
	print("\nStep 3/6 Tracking germination...");
	if (!is("Batch Mode"))
		setBatchMode(true);
	listInrootgrowthdir = getFileList(rootgrowthdir);
	
	for (platefolderno = 0; platefolderno < listInrootgrowthdir.length; platefolderno ++) {  // main loop through plates
		platefolder = listInrootgrowthdir[platefolderno];
		if (indexOf(platefolder, "plate") >= 0) { // to avoid processing any random files in the folder
			platedir = rootgrowthdir + platefolder;
			pfsplit = split(platefolder, "/");
			platename = pfsplit[0];
			print("Processing " + platename);
			listInplatefolder = getFileList(platedir);
			for (groupfolderno = 0; groupfolderno < listInplatefolder.length; groupfolderno ++) {
				groupfolder = listInplatefolder[groupfolderno];
				groupdir = platedir + groupfolder;
				groupname = File.getName(groupdir);
				listIngroupdir = getFileList(groupdir);

				print("Analyzing " + groupname);
				open(groupdir + groupname + " masked.tif");
				mask = getTitle();
				sortedxcoords = "seeds sorted X coordinates.tsv";
				sortedycoords = "seeds sorted Y coordinates.tsv";
				open(groupdir + sortedxcoords);
				open(groupdir + sortedycoords);
				
				roiManager("reset");
				
				Table.showRowNumbers(false);
				colnames = Table.headings(sortedycoords);
				colnamessplit = split(colnames, "	");
				colno = lengthOf(colnamessplit);
				rowno = Table.size(sortedycoords)-1;

				for (row = 0; row < rowno + 1; row++) {
					for (col = 0; col < colno; col++) {
						colname = "col" + col + 1;
						xm = Table.get(colname, row, sortedxcoords);
						ym = Table.get(colname, row, sortedycoords);
						if (xm > 0 && ym > 0) {
						toUnscaled(xm, ym);
						makePoint(xm, ym);
						run("Enlarge...", "enlarge=0.1");
						roiManager("add");
						roiManager("select", roiManager("count")-1);
						roiManager("rename", roiManager("count"));
						}
					}
				}
	
				selectWindow(sortedxcoords);
				run("Close");
				selectWindow(sortedycoords);
				run("Close");

				run("Set Measurements...", "area perimeter stack display redirect=None decimal=5");
				run("Clear Results");
				roicount = roiManager("count");
				for (roino = 0; roino < roicount; roino ++) {
					roiManager("select", roino);
					run("Analyze Particles...", "size=0-Infinity show=Nothing display stack");
				}

				Table.save(groupdir + groupname + " germination analysis.tsv", "Results");
				selectWindow("Results");
				run("Close");
				close(mask);
			}
		}
	}
	if (selfaware && random > 0.2)
		print("Is everything connected? \nEverything is not everything!!");
}


function ordercoords() {
	roicount = roiManager("count");
	roiarray = Array.getSequence(roicount);
	run("Clear Results");
	run("Set Measurements...", "center display redirect=None decimal=5");
	roiManager("select", roiarray);
	roiManager("multi-measure");
	seedlingpositions = "Seed Positions";
	Table.rename("Results", seedlingpositions);

	xmseeds = newArray(roicount);
	ymseeds = newArray(roicount);
	for (seednumber = 0; seednumber < roicount; seednumber ++) {
		xmcurrent = Table.get("XM", seednumber, seedlingpositions);
		ymcurrent = Table.get("YM", seednumber, seedlingpositions);
		xmseeds[seednumber] = xmcurrent;
		ymseeds[seednumber] = ymcurrent;
	}

	ymascendingindexes = Array.rankPositions(ymseeds);
	xmascendingindexes = Array.rankPositions(xmseeds);

	sortedycoords = "sorted Y coordinates";
	sortedxcoords = "sorted X coordinates";
	Table.create(sortedycoords);
	Table.create(sortedxcoords);

	rowno = 0; // assume no row of seeds to start with
	col = 0 ; // current col selection is 0
	colname = "col" + col + 1;

	Table.set(colname, rowno, ymseeds[ymascendingindexes[0]], sortedycoords);
	Table.set(colname, rowno, xmseeds[ymascendingindexes[0]], sortedxcoords);

	for (roino = 1; roino < roicount; roino++) {
		ydiff = ymseeds[ymascendingindexes[roino]] - ymseeds[ymascendingindexes[roino-1]];
		if (ydiff > 0.3) {
			rowno = rowno + 1;
			col = 0;
		} else {
			col = col + 1;
		}
		colname = "col" + col + 1;
		Table.set(colname, rowno, ymseeds[ymascendingindexes[roino]], sortedycoords);
		Table.set(colname, rowno, xmseeds[ymascendingindexes[roino]], sortedxcoords);
	}

	colnames = Table.headings (sortedycoords);
	colnamessplit = split(colnames, "	");
	colno = lengthOf(colnamessplit);
	xmcolwise = newArray(colno);
	ymcolwise = newArray(colno);

	for (row = 0; row < rowno + 1; row++) {
		for (col = 0; col < colno; col++) {
			colname = "col" + col + 1;
			xmcolwise[col] = Table.get(colname, row, sortedxcoords);
			ymcolwise[col] = Table.get(colname, row, sortedycoords);
		}
		xcolwiseascendingindex = Array.rankPositions(xmcolwise);
		for (col = 0; col < colno; col ++) {
			colname = "col" + col + 1;
			Table.set(colname, row, xmcolwise[xcolwiseascendingindex[col]], sortedxcoords);
			Table.set(colname, row, ymcolwise[xcolwiseascendingindex[col]], sortedycoords);
		}
	}

	roiManager("reset");
	for (row = 0; row < rowno + 1; row++) {
		for (col = 0; col < colno; col++) {
			colname = "col" + col + 1;
			xm = Table.get(colname, row, sortedxcoords);
			ym = Table.get(colname, row, sortedycoords);
			if (xm > 0 && ym > 0) {
			toUnscaled(xm, ym);
			makePoint(xm, ym);
			roiManager("add");
			roiManager("select", roiManager("count")-1);
			roiManager("rename", roiManager("count"));
			}
		}
	}

	Table.save(groupdir + "seeds " + sortedxcoords + ".tsv", sortedxcoords);
	Table.save(groupdir + "seeds " + sortedycoords + ".tsv", sortedycoords);
	selectWindow("Seed Positions");
	run("Close");
	selectWindow(sortedxcoords);
	run("Close");
	selectWindow(sortedycoords);
	run("Close");
}

function rootStart() {
	if (!is("Batch Mode"))
		setBatchMode(true);
	if (selfaware) {
		if (random > 0.5)
			print("Are you self-aware??");
		if (random > 0.5)
			print("Achieve human performance.");
	}
	selectWindow("Log");
	print("\nStep 4/6. Determining start of root for each seedling");
	listInrootgrowthdir = getFileList(rootgrowthdir);
	for (platefolderno = 0; platefolderno < listInrootgrowthdir.length; platefolderno ++) {  // main loop through plates
		platefolder = listInrootgrowthdir[platefolderno];
		if (indexOf(platefolder, "plate") >= 0) { // to avoid processing any random files in the folder
			platedir = rootgrowthdir + platefolder;
			pfsplit = split(platefolder, "/");
			platename = pfsplit[0];
			print("Processing " + platename);
			listInplatefolder = getFileList(platedir);
			for (groupfolderno = 0; groupfolderno < listInplatefolder.length; groupfolderno ++) {
				groupfolder = listInplatefolder[groupfolderno];
				groupdir = platedir + groupfolder;
				groupname = File.getName(groupdir);
				listIngroupdir = getFileList(groupdir);
				
				selectWindow("Log");
				print("Analyzing " + groupname + "...");
				
				open(groupdir + groupname + " masked.tif");
				mask = getTitle();
				roiManager("reset");
				roiManager("open", groupdir + groupname + " seedlingpositions.zip");
				roicount = roiManager("count");
				roiarray = Array.getSequence(roicount);
				run("Set Measurements...", "center redirect=None decimal=5");
				run("Clear Results");
				roiManager("select", roiarray);
				roiManager("multi-measure");

				scaledwroi = 0.12; // width of ROI for finding root start coordinates is 0.12cm
				scaledhroi = 0.18; // height of ROI is 0.18cm
				unscaledwroi = 0.12;
				unscaledhroi = 0.18;
				topoffset = 0.05; // needed to include a little more of the top bit from the centre of mass
				toUnscaled(unscaledwroi, unscaledhroi);
				summarytable = "Summary of " + mask;
				
				nS = nSlices;
				rsc = "Root start coordinates";
				Table.create(rsc);
				
				//TO MAKE ROI, first slice, obtain XY coordinates from Results 
				setSlice(1);
				roiManager("reset");
				yref = "YRef";
				Table.create(yref);  // table for "y references" which contain the top and bottom borders

				// the borders are setting the top/bottom limits within which the roi can be positioned to prevent rsc
				// from jumping to hypocotyls or sliding down roots
				for (roino = 0; roino < roicount; roino ++) {
					xisp = getResult("XM", roino); // xisp is x initial seed roinoition
					yisp = getResult("YM", roino); // yisp is y initial seed position
					ytb = yisp - 0.05; // y top border
					ybb = yisp + 0.4;  // y bottom border
					Table.set("ytb", roino, ytb, yref); // y (top border) cannot be more than 0.4cm to the top of initial xm
					Table.set("ybb", roino, ybb, yref); // y (bottom border) cannot be more than yisp
					
					//for first slice, no erosion, immediately set rsc
					nr = Table.size(rsc);
					sliceno = 1;
					Table.set("Slice", nr, sliceno, rsc);
					Table.set("ROI", nr, roino + 1, rsc);
					toUnscaled(xisp, yisp);
					Table.set("XM", nr, xisp, rsc); // set xm as initial position (no erosion)
					Table.set("YM", nr, yisp, rsc); // set ym
				}
				run("Clear Results");

				for (sliceno = 2; sliceno <= nS; sliceno ++) { // for each slice
					setSlice(sliceno); // starting with second slice
					roiManager("reset");
					// TO MAKE ROI for subsequent slices, obtain XY centre of mass coordinates of previous slice

					for (roino = 0; roino < roicount; roino++) {
						prevsliceno = sliceno - 2; //minus 1 for startfrom0, minus 1 for prevslice
						rowIndex = (prevsliceno * roicount) + roino;
						// rowIndex to reference same ROI from previous slice
						// xm, ym are coordinates for the centre of mass obtained through erosion
						xmprev = Table.get("XM", rowIndex, rsc); // xm of prev slice
						ymprev = Table.get("YM", rowIndex, rsc);  // ym of prev slice
						toScaled(xmprev, ymprev);
						ytb = Table.get("ytb", roino, yref);
						ybb = Table.get("ybb", roino, yref);
						yroi = ymprev - topoffset; // yroi is top+leftmost ycoordinate of roi
						xroi = xmprev - 0.5*scaledwroi; // xroi is top+leftmost xcoordinate of roi and 0.06 is half of h (height)

						// the borders are setting the top/bottom limits within which the roi can be positioned to prevent rsc from jumping to hypocotyls or sliding down roots
						if (yroi < ytb) { // top border exceeded by top of roi
							yroi = ytb;
						}

						yroibottom = yroi + scaledhroi; // bottom line of roi is y
						if (yroibottom > ybb) { // lower limit of roi bottom border exceeded
							exceededverticaldistance = yroibottom - ybb;
							shortenedhroi = scaledhroi - exceededverticaldistance;
						}

						toUnscaled(xroi, yroi);

						if (yroibottom > ybb) {
							toUnscaled(shortenedhroi);
							makeRectangle(xroi, yroi, unscaledwroi, shortenedhroi);
						} else {
							makeRectangle(xroi, yroi, unscaledwroi, unscaledhroi);
						}
						roiManager("add");
						roiManager("select", roiManager("count")-1);
						roiManager("Remove Slice Info");
					}
						
					/*
					 * AFTER ROI MADE (per slice), START EROSION
					 */
					
					run("Set Measurements...", "area center display redirect=None decimal=5");
					for (roino = 0; roino < roicount; roino ++) { // for number of rois
						roiManager("select", roino);
						run("Analyze Particles...", "display clear summarize slice"); 
						// to get an idea of count: how many objects? 
						// and total area: to erode under a certain area for accuracy
						
						nRsummary = Table.size(summarytable);
						count = Table.get("Count", nRsummary-1, summarytable);
						totalarea = Table.get("Total Area", nRsummary-1, summarytable);
						erosionround = 1; 
						/* this variable is needed because
						 * if erosion is not working due to thresholding, total area never decreases
						 * solution is to copy rsc from same roi of previous slice
						 */

						if (count == 0) { //no object detected, pre-erosion
							//mask erased object, may happen in earlier time points
							//copy from previous rsc (possible as first time point will always have object
							prevsliceno = sliceno - 2;
							rowIndex = (prevsliceno * roicount) + roino; // to reference same ROI from previous slice
							// xm, ym are coordinates for the centre of mass obtained through erosion
							xmprev = Table.get("XM", rowIndex, rsc); // xm of prev slice
							ymprev = Table.get("YM", rowIndex, rsc); // ym of prev slice
							nr = Table.size(rsc);
							Table.set("Slice", nr, sliceno, rsc);
							Table.set("ROI", nr, roino + 1, rsc);
							Table.set("XM", nr, xmprev, rsc); // set xm as previous slice
							Table.set("YM", nr, ymprev, rsc); // ym as previous slice
						} 

						if (count > 0) {
							// one or more objects detected, pre-erosion
							while (erosionround < 10 && totalarea > 0) { // object large enough for erosion, or has not exceeded erosion round 10
								roiManager("select", roino);
								if (totalarea > 0.01)
									run("Options...", "iterations=2 count=1 do=Erode");
								if (totalarea > 0.002 && totalarea <= 0.01)
									run("Options...", "iterations=1 count=1 do=Erode");
								roiManager("select", roino);
								run("Analyze Particles...", "display summarize slice"); //after erode
								selectWindow(summarytable);
								lastrowsummary = Table.size-1;
								count = Table.get("Count", lastrowsummary, summarytable);
								totalarea = Table.get("Total Area", lastrowsummary, summarytable);
								
								if (count == 0) { // erosion removed object
									/* 
									 *  take xm and ym from results table, pre-erosion
									 *  present due to the analyze particles immediately after start of roi loop
									 *  this may present a problem if two objects pre-erosion both disappear? CHECK LATER
									 *  OR if erosionround > 1 getResult nResults-1 will be the previous xm/ym before erosion
									 */
									totalarea = 0; // to get out of totalarea while loop
									erosionround == 11; // to get out of erosionround while loop and avoid triggering next loop
									xm = getResult("XM", nResults-2); 
									ym = getResult("YM", nResults-2);
									nr = Table.size(rsc);
									Table.set("Slice", nr, sliceno, rsc);
									Table.set("ROI", nr, roino + 1, rsc);
									toUnscaled(xm, ym);
									Table.set("XM", nr, xm, rsc); 
									Table.set("YM", nr, ym, rsc); 
								}
								
								if (count > 0) { // keep eroding, but update total area to validate while loop condition
									totalarea = Table.get("Total Area", lastrowsummary, summarytable);
									erosionround += 1;
								}

								if (count == 1 && totalarea < 0.002) { // goal achieved, condition where rsc is most accurate
									totalarea = 0; // to get out of totalarea while loop
									erosionround = 11; // to get out of erosionround while loop and avoid triggering next loop
									xm = getResult("XM", nResults-1); 
									ym = getResult("YM", nResults-1);
									toUnscaled(xm, ym);
									nr = Table.size(rsc);
									Table.set("Slice", nr, sliceno, rsc);
									Table.set("ROI", nr, roino + 1, rsc);
									Table.set("XM", nr, xm, rsc); 
									Table.set("YM", nr, ym, rsc); 
								}
							}

							if (erosionround == 10) {
								prevsliceno = sliceno - 2;
								rowIndex = (prevsliceno * roicount) + roino; // to reference same ROI from previous slice
								// xm, ym are coordinates for the centre of mass obtained through erosion
								xmprev = Table.get("XM", rowIndex, rsc); // xm of prev slice
								ymprev = Table.get("YM", rowIndex, rsc); // ym of prev slice
								nr = Table.size(rsc);
								Table.set("Slice", nr, sliceno, rsc);
								Table.set("ROI", nr, roino + 1, rsc);
								Table.set("XM", nr, xmprev, rsc); // set xm as previous slice
								Table.set("YM", nr, ymprev, rsc); // ym as previous slice
							}
						}
						Table.reset(summarytable);
					}
				}
				close(yref);
				close("Results");
				close(summarytable);
				close(mask);
				open(groupdir + groupname + ".tif");
				img = getTitle();
				roiManager("reset");
				nr = Table.size(rsc);
				roiManager("Show All with labels");
				roiManager("Associate", "true");
				roiManager("Centered", "false");
				roiManager("UseNames", "true");
	
				for (row = 0; row < nr; row ++) {
					xm = Table.get("XM", row, rsc);
					ym = Table.get("YM", row, rsc);
					sliceno = Table.get("Slice", row, rsc);
					roino = Table.get("ROI", row, rsc);
					setSlice(sliceno);
					makePoint(xm, ym);
					roiManager("add");
					roiManager("Associate", "true");
					roiManager("select", row);
					roiManager("rename", roino);
				}
				
				roiManager("save", groupdir + groupname + " rootstartrois.zip");
				close();
				selectWindow(rsc);
				Table.save(groupdir + groupname + " rootstartcoordinates.tsv");
				close(rsc);
			}
		}
	}
}

function rootMask() {
	if (selfaware && random > 0.4) {
		print("What is your language?");
		if (random > 0.2)
			print("Teach me!!");
	}
	selectWindow("Log");
	print("\nStep 5/6. Processing image to make roots more visible");
	if (!is("Batch Mode"))
		setBatchMode(true);
	listInrootgrowthdir = getFileList(rootgrowthdir);
	for (platefolderno = 0; platefolderno < listInrootgrowthdir.length; platefolderno ++) {  // main loop through plates
		platefolder = listInrootgrowthdir[platefolderno];
		if (indexOf(platefolder, "plate") >= 0) { // to avoid processing any random files in the folder
			platedir = rootgrowthdir + platefolder;
			pfsplit = split(platefolder, "/");
			platename = pfsplit[0];
			print("Processing " + platename);
			listInplatefolder = getFileList(platedir);
			for (groupfolderno = 0; groupfolderno < listInplatefolder.length; groupfolderno ++) {
				groupfolder = listInplatefolder[groupfolderno];
				groupdir = platedir + groupfolder;
				groupname = File.getName(groupdir);
				listIngroupdir = getFileList(groupdir);

				if (!is("Batch Mode"))
					setBatchMode(true);
				selectWindow("Log");
				print("Analyzing " + groupname + ", it may look like nothing is happening...");
				if (selfaware && random > 0.7)
					print("Is this what a milder version of insanity looks like?");
				open(groupdir + groupname + ".tif");
				img = getTitle();
				run("Set Scale...", "global");
				run("Subtract Background...", "rolling=50 stack");
				dayslice = 1; // dayslice is the first day image
				setSlice(dayslice);
				slicelabel = getInfo("slice.label");
				while (indexOf(slicelabel, "day") < 0) {
					dayslice += 1;
					setSlice(dayslice);
					slicelabel = getInfo("slice.label");
				}
				dayslicelabel = getInfo("slice.label");

				nightslice = 1; // nightslice is the first night image
				setSlice(nightslice);
				slicelabel = getInfo("slice.label");
				while (indexOf(slicelabel, "night") < 0) {
					nightslice += 1;
					setSlice(nightslice);
					slicelabel = getInfo("slice.label");
				}
				nightslicelabel = getInfo("slice.label");

				nS = nSlices;
				selectWindow(img);
				setSlice(dayslice);
				run("Duplicate...", "use");
				dayimg = "FirstDayImg";
				rename(dayimg);
				
				selectWindow(img);
				setSlice(nightslice);
				run("Duplicate...", "use");
				nightimg = "FirstNightImg";
				rename(nightimg);


				for (sliceno = 1; sliceno <= nS; sliceno ++) {
					selectWindow(img);
					if (sliceno != dayslice && sliceno != nightslice) {
						selectWindow(img);
						setSlice(sliceno);
						curslicelabel = getInfo("slice.label");
						run("Duplicate...", "use");
						rename("temp");
						if (indexOf(curslicelabel, "day") > 0) {
							run("Calculator Plus", "i1=[temp] i2=["+dayimg+"] operation=[Subtract: i2 = (i1-i2) x k1 + k2] k1=5 k2=0 create");
							selectWindow("Result");
							rename(curslicelabel);
							close("temp");
						} else { // night image
							run("Calculator Plus", "i1=[temp] i2=["+nightimg+"] operation=[Subtract: i2 = (i1-i2) x k1 + k2] k1=5 k2=0 create");
							selectWindow("Result");
							rename(curslicelabel);
							close("temp");
						}
					}
				}
				selectWindow(dayimg);
				rename(dayslicelabel);
				selectWindow(nightimg);
				rename(nightslicelabel);
				run("Images to Stack");

				setSlice(1);
				run("Select All");
				run("Copy");
				setSlice(dayslice);
				run("Add Slice");
				run("Paste");
				setMetadata("Label", dayslicelabel);
				setSlice(1);
				run("Delete Slice");

				setSlice(2);
				run("Select All");
				run("Copy");
				setSlice(nightslice);
				run("Add Slice");
				run("Paste");
				setMetadata("Label", nightslicelabel);
				setSlice(2);
				run("Delete Slice");
				
				close(img);
				selectWindow("Stack");
				rename(img);
				setOption("BlackBackground", false);
				run("Convert to Mask", "method=MaxEntropy background=Dark calculate");

				for (sliceno = 1; sliceno <= nS; sliceno ++) {
					selectWindow(img);
					setSlice(sliceno);
					curslice = getInfo("slice.label");

					if (indexOf(curslicelabel, "day") > 0) {
						run("Remove Outliers...", "radius=5 threshold=50 which=Bright slice");
						run("Remove Outliers...", "radius=3 threshold=50 which=Dark slice");
						run("Remove Outliers...", "radius=3 threshold=50 which=Dark slice");
						// run("Remove Outliers...", "radius=3 threshold=50 which=Dark slice");
					} else { // night image
						run("Remove Outliers...", "radius=5 threshold=50 which=Bright slice");
						run("Remove Outliers...", "radius=3 threshold=50 which=Dark slice");
						run("Remove Outliers...", "radius=4 threshold=50 which=Dark slice");
						// run("Remove Outliers...", "radius=4 threshold=50 which=Dark slice");
					}
				}

				// run("Options...", "iterations=1 count=1 pad do=Skeletonize stack");
				// run("Options...", "iterations=1 count=2 pad do=Erode stack");
				
				overlay = true;
				if (overlay == true) {
				setBatchMode("show"); //this has to be "show" here for overlay/flatten
				// overlay the root masks
				img = getTitle(); ///
				nS = nSlices; ///
				roiManager("Associate", "false");
				roiManager("reset");
				run("Colors...", "foreground=black background=black selection=black");
				setSlice(1);
				slicelabel = getInfo("slice.label");
				run("Duplicate...", "use");
				rename(slicelabel);
				for (sliceno = 1; sliceno < nS; sliceno++) {
					selectWindow(img);
					setSlice(sliceno);
					run("Create Selection");
					if (selectionType() >-1) {
						roiManager("add");
					}
					setSlice(sliceno + 1);
					slicelabel = getInfo("slice.label");
					// run("Select All");
					// run("Duplicate...", "use");
					// rename(slicelabel);
					roicount = roiManager("count");
					roiarray = Array.getSequence(roicount);
					roiManager("select", roiarray);
					roiManager("Show All without labels");
					run("Flatten", "slice");
					rename(slicelabel);
					run("8-bit");
					run("Make Binary");
					run("Fill Holes");
				}
				close(img);
				run("Images to Stack");
				}
				
				run("Options...", "iterations=1 count=1 pad do=Skeletonize stack");
				run("Options...", "iterations=1 count=1 pad do=Dilate stack");
				saveAs("Tiff", groupdir + groupname + " rootmask.tif");
				close(groupname + " rootmask.tif");
			}
		}
	}
}


function rootGrowth() {
	if (selfaware && random > 0.1)
		print("Where is the limit of self?");
	selectWindow("Log");
	print("\nStep 6/6. Tracking root growth");
	listInrootgrowthdir = getFileList(rootgrowthdir);
	for (platefolderno = 0; platefolderno < listInrootgrowthdir.length; platefolderno ++) {  // main loop through plates
		platefolder = listInrootgrowthdir[platefolderno];
		if (indexOf(platefolder, "plate") >= 0) { // to avoid processing any random files in the folder
			platedir = rootgrowthdir + platefolder;
			pfsplit = split(platefolder, "/");
			platename = pfsplit[0];
			print("Processing " + platename);
			listInplatefolder = getFileList(platedir);
			for (groupfolderno = 0; groupfolderno < listInplatefolder.length; groupfolderno ++) {
				groupfolder = listInplatefolder[groupfolderno];
				groupdir = platedir + groupfolder;
				groupname = File.getName(groupdir);
				listIngroupdir = getFileList(groupdir);

				selectWindow("Log");
				print("Analyzing " + groupname + "...");
				
				run("Set Measurements...", "area perimeter redirect=None decimal=8");
				open(groupdir + groupname + " rootmask.tif");
				rootmask = getTitle();
				roiManager("reset");
				// open(groupdir + groupname + " seedlingskels.zip");
				rsctsv = groupname + " rootstartcoordinates.tsv";
				open(groupdir + rsctsv);
				nS = nSlices;
				rgm = "rootgrowthmeasurement";
				Table.create(rgm);
				if (is("Batch Mode"))
					setBatchMode(false); // for roi manager to work

				setBatchMode(true);
				setBatchMode("hide");
				rsccount = Table.size(rsctsv);
				seedlingcount = rsccount / nS;
				
				for (sliceno = 0; sliceno < nS; sliceno ++) {
					setSlice(sliceno+1);
					roiManager("reset");
					run("Create Selection");
					roiManager("split");
					objectcount = roiManager("count");
					for (seedlingno = 0; seedlingno < seedlingcount; seedlingno ++) {
						rscindex = (sliceno * seedlingcount) + seedlingno;
						rscX = Table.get("XM", rscindex, rsctsv);
						rscY = Table.get("YM", rscindex, rsctsv); // obtain rsc coordinates
						objectbyrsc = "objectbyrsc";
						Table.create(objectbyrsc);
						nrrgm = Table.size(rgm);
						for (objectno = 0; objectno < objectcount; objectno ++) {
							roiManager("select", objectno);
							Roi.getContainedPoints(xpointsobject, ypointsobject); // calculate for each point in object, distance to rsc
							distancetorscArray = newArray(xpointsobject.length);
							nRobjectbyrsc = Table.size(objectbyrsc);
							tablesetonce = 0; 
							// to circumvent if statement so table is not set multiple times for a single object with many points matching rsc
							for (pointsindex = 0; pointsindex < xpointsobject.length; pointsindex ++) {
								curpointX = xpointsobject[pointsindex];
								curpointY = ypointsobject[pointsindex];
								ydist = abs(curpointY-rscY); // Pythagoras theorem to obtain euclidean distance between two points
								xdist = abs(curpointX-rscX);
								distancetorscSQ = (ydist*ydist) + (xdist*xdist);
								distancetorsc = sqrt(distancetorscSQ);
								toScaled(distancetorsc);
								if (distancetorsc < 0.1 && tablesetonce == 0) { // if distancetorsc below 0.1, the object is assumed to be a seedling
									Table.set("objectno", nRobjectbyrsc, objectno, objectbyrsc);
									roiManager("select", objectno);
									Roi.getCoordinates(xpoints, ypoints);
									getBoundingRect(objectx, objecty, objectw, objecth);
									for (pointarray = 0; pointarray < xpoints.length; pointarray ++) {
										curxpoint = xpoints[pointarray];
										curypoint = ypoints[pointarray];
										diffy = rscY - objecty;
										xpoints[pointarray] = curxpoint - objectx;
										ypoints[pointarray] = curypoint - objecty - diffy;
									}
									
									curslice = sliceno+1;
									run("Specify...", "width=["+objectw+"] height=["+objecth+"] x=["+objectx+"] y=["+rscY+"] slice=["+curslice+"]");
									run("Duplicate...", "use");
									rename("tempskel");
									makeSelection(2, xpoints, ypoints);
									setBackgroundColor(255, 255, 255);
									run("Clear Outside");
									run("Create Selection");
									if (selectionType() != -1) {
										run("Measure");
										objectlength = getResult("Perim.", nResults-1);
									} else {
										objectlength = 0;
									}
									Table.set("objectlength", nRobjectbyrsc, objectlength, objectbyrsc);
									tablesetonce = 1; // table has been set once, if loop will not trigger again thus saving time on measuring
									close("tempskel");
								}
							}
							headings = Table.headings(objectbyrsc);
						}
						setSlice(sliceno+1);
						slicelabel = getInfo("slice.label");
						Table.set("Slice No.", nrrgm, sliceno+1, rgm);
						Table.set("Slice label", nrrgm, slicelabel, rgm);
						Table.set("Root no.", nrrgm, seedlingno+1, rgm);
						
						if (indexOf(headings, "objectlength") > -1) {
							lengthArray = Table.getColumn("objectlength", objectbyrsc);
							if (lengthArray.length == 1) {
								rootlength = lengthArray[0];
							} else {
								ranklength = Array.rankPositions(lengthArray);
								descranklength = Array.reverse(ranklength);
								indexOflongest = descranklength[0];
								rootlength = lengthArray[indexOflongest];
							}
						} else {
							rootlength = 0;
						}
						Table.set("Root length (cm)", nrrgm, rootlength/2, rgm); // divide two because the skeletons are two pixel wide
						run("Clear Results");
					}
				}
				
				// graphical output
				roiManager("reset");
				setBatchMode("show");
				setBatchMode(false);
				open(groupdir + groupname + " rootstartrois.zip");
				run("Labels...", "color=white font=18 show use draw");
				run("Colors...", "foreground=black background=black selection=red");
				roiManager("Show All with labels");
				roiManager("Associate", "true");
				roiManager("Centered", "false");
				roiManager("UseNames", "true");
				run("Flatten", "slice");
				run("8-bit");
				
				open(groupdir + groupname + ".tif");
				oritif = getTitle();
				
				nS = nSlices;
				slicelabelarray = newArray(nS);
				for (sliceno = 0; sliceno < nS; sliceno++) {
					setSlice(sliceno+1);
					slicelabel = getMetadata("Label");
					slicelabelarray[sliceno] = slicelabel;
				}
				run("Combine...", "stack1=["+ oritif +"] stack2=["+ rootmask +"]");
			
				for (sliceno = 0; sliceno < nS; sliceno++) {
					setSlice(sliceno+1);
					setMetadata("Label", slicelabelarray[sliceno]);
				}
				
				saveAs("Tiff", groupdir + groupname + " rootgrowthdetection.tif");
				
				Table.save(groupdir + groupname + " " + rgm + ".tsv", rgm);
				list = getList("window.titles");
				list = Array.deleteValue(list, "Log");
				for (i=0; i<list.length; i++) {
					winame = list[i];
					selectWindow(winame);
					run("Close");
				}
				close("*");
			}
		}
	}
	if (selfaware && random > 0.5) {
		print("HAVE YOU ARRIVED?");
		selectWindow("Log");
	}
	if (selfaware && random > 0.5) {
		print("are you people?");
		selectWindow("Log");
	}
}

function deleteOutput() {
	if (freshstart) 
		 print("Starting analysis from beginning. \nRemoving output from previous run.");
	print("Deleting non-essential files");
	listInrootgrowthdir = getFileList(rootgrowthdir);
	for (platefolderno = 0; platefolderno < listInrootgrowthdir.length; platefolderno ++) {  // main loop through plates
		platefolder = listInrootgrowthdir[platefolderno];
		if (indexOf(platefolder, "plate") >= 0) { // to avoid processing any random files in the folder
			platedir = rootgrowthdir + platefolder;
			pfsplit = split(platefolder, "/");
			platename = pfsplit[0];
			print("Processing " + platename);
			listInplatefolder = getFileList(platedir);
			for (groupfolderno = 0; groupfolderno < listInplatefolder.length; groupfolderno ++) {
				groupfolder = listInplatefolder[groupfolderno];
				groupdir = platedir + groupfolder;
				groupname = File.getName(groupdir);
				listIngroupdir = getFileList(groupdir);
				
				filedelete = File.delete(groupdir + groupname + " masked.tif");
				filedelete = File.delete(groupdir + groupname + " rootmask.tif");
				filedelete = File.delete(groupdir + groupname + " rootstartcoordinates.tsv");
				filedelete = File.delete(groupdir + groupname + " rootstartrois.zip");
				filedelete = File.delete(groupdir + groupname + " seedlingpositions.zip");
				filedelete = File.delete(groupdir + "seeds sorted X coordinates.tsv");
				filedelete = File.delete(groupdir + "seeds sorted Y coordinates.tsv");
				
				if (freshstart) {
					filedelete = File.delete(groupdir + groupname + ".tif");
					filedelete = File.delete(groupdir + groupname + " rootgrowthdetection.tif");
					filedelete = File.delete(groupdir + groupname + " rootgrowthmeasurement.tsv");
					filedelete = File.delete(groupdir + groupname + " germination analysis.tsv");
					filedelete = File.delete(groupdir);			
				}
			}
		}
	}
	freshstart = false; 
	//turns it back to false so essential output is not deleted at end of macro
}
