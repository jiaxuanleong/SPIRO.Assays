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
var SEEDS = 1; // for determining target of ordercoords() function
var ROOTS = 2; // for determining target of ordercoords() function


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
rootStart();
if (step <= 4)
rootMask();
if (step <= 5)
getSkeletons();
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
				listInlastgroupfolder = getFileList(lastgroupfolder);
				for (outputfileno = 0 ; outputfileno < listInlastgroupfolder.length; outputfileno ++ ) {
					outputfilename = File.getName(listInlastgroupfolder[outputfileno]);
					isTiff = indexOf(outputfilename, "Group");
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

	if (step == 3) { // check for rootStart()
		for (outputfileno = 0 ; outputfileno < listInlastgroupfolder.length; outputfileno ++ ) {
			outputfilename = listInlastgroupfolder[outputfileno];
			isRsc = indexOf(outputfilename, "rootstartcoordinates");
			if (isRsc >= 0) {
				step = 4;
				print("File rootstartcoordinates.tsv found, resuming from step 4");
			}
		}
	}

	if (step == 4) { // check for rootMask()
		for (outputfileno = 0 ; outputfileno < listInlastgroupfolder.length; outputfileno ++ ) {
			outputfilename = listInlastgroupfolder[outputfileno];
			isRootmask = indexOf(outputfilename, "rootmask");
			if (isRootmask >= 0) {
				step = 5;
				print("File rootmask.tif found, resuming from step 5");
			}
		}
	}

	if (step == 5) { // check for rootSkel()
		for (outputfileno = 0 ; outputfileno < listInlastgroupfolder.length; outputfileno ++ ) {
			outputfilename = listInlastgroupfolder[outputfileno];
			isSkelrois = indexOf(outputfilename, "seedlingskels");
			if (isSkelrois >= 0) {
				step = 6;
				print("File seedlingskels.zip found, resuming from step 6");
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
				saveAs("Tiff", groupdir + "Group " + roiname + ".tif");
				close("Group*");
			}
			close(platefile);
			close("Substack*");
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
				open(groupdir + "Group " + groupname + ".tif");			
				img = getTitle();
				// image processing, thresholding, masking, denoise
				run("Subtract Background...", "rolling=30 stack");
				// run("Median...", "radius=1 stack");
				setAutoThreshold("MaxEntropy dark");
				run("Convert to Mask", "method=MaxEntropy background=Dark calculate");
				run("Options...", "iterations=1 count=4 do=Dilate stack");
				run("Remove Outliers...", "radius=2 threshold=50 which=Dark stack");
				run("Remove Outliers...", "radius=3 threshold=50 which=Dark stack");

				// create selections of all individual features on image
				setBatchMode(false); // has to be false for roi manager to display, and for user guided step
				setBatchMode("show"); // show the image
				roiManager("reset");
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
				selectWindow(img);
				// maxYimg = getHeight();
				// toScaled(maxYimg);
				nr = nResults;
				for (row = 0; row < nr; row ++) {
					nrTp = Table.size(tp); // number of rows
					area = getResult("Area", row);
					if (area < 0.0012) { // detected object is very small
						Table.set("Trash ROI", nrTp, row, tp);
					}
					if (area > 0.02) { // or very large
						Table.set("Trash ROI", nrTp, row, tp);
					}
					// ym = getResult("YM", row);
					// distancetomaxY = maxYimg - ym; //distance of detected object from bottom of image
					// if (distancetomaxY < 1) { // less than 1cm
						// Table.set("Trash ROI", nrTp, row, tp);
					// }
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

				// number remaining ROIs
				roicount = roiManager("count");
				roiarray = Array.getSequence(roicount);
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
				roiarray = Array.getSequence(roicount);
				for (roino = 0 ; roino < roicount; roino ++) {
					roiManager("select", roino);
					roiManager("rename", roino + 1); // first roi is 1
				}
				ordercoords(SEEDS);
				// calling ordercoords() with argument 'false' runs to order seed positions
				// instead argument 'true' optimizes code to order root dimensions later
				roiManager("save", groupdir + groupname + " seedlingpositions.zip");
				roiManager("reset");
				selectWindow(img);
				saveAs("Tiff", groupdir + groupname + " masked.tif");
				close(groupname + " masked.tif");
			}
		}
	}
}

// calling ordercoords() with target 'ROOTS' runs to order seedling rois
// else target is 'SEEDS' to order seed xm/ym
function ordercoords(target) {
	if (target == ROOTS) {
		roicount = Table.size(lastslicecoord);
		xmroots = Table.getColumn("XM", lastslicecoord);
		ymroots = Table.getColumn("YM", lastslicecoord);
		xmascendingindexes = Array.rankPositions(xmroots);
		ymascendingindexes = Array.rankPositions(ymroots);
	} else { //target is SEEDS
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
	}

	sortedycoords = "sorted Y coordinates";
	sortedxcoords = "sorted X coordinates";
	Table.create(sortedycoords);
	Table.create(sortedxcoords);

	rowno = 0; // assume no row of seeds to start with
	col = 0 ; // current col selection is 0
	colname = "col" + col + 1;

	if (target == ROOTS) {
		Table.set(colname, rowno, ymroots[ymascendingindexes[0]], sortedycoords);
		Table.set(colname, rowno, xmroots[ymascendingindexes[0]], sortedxcoords);

		for (roino = 1; roino < roicount; roino++) {
			ymroot2 = ymroots[ymascendingindexes[roino]];
			ymroot1 = ymroots[ymascendingindexes[roino-1]];
			ydiff =  ymroot2 - ymroot1;
			if (ydiff > 0.3) {
				rowno += 1;
				col = 0;
			} else {
				col += 1;
			}
			colname = "col" + col + 1;
			Table.set(colname, rowno, ymroot2, sortedycoords);
			Table.set(colname, rowno, xmroots[ymascendingindexes[roino]], sortedxcoords);
		}
	} else {
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

	if (target == ROOTS) {
		Table.save(groupdir + "roots " + sortedxcoords + ".tsv", sortedxcoords);
		Table.save(groupdir + "roots " + sortedycoords + ".tsv", sortedycoords);
		
	} else {
		Table.save(groupdir + "seeds " + sortedxcoords + ".tsv", sortedxcoords);
		Table.save(groupdir + "seeds " + sortedycoords + ".tsv", sortedycoords);
		selectWindow("Seed Positions");
		run("Close");
		selectWindow(sortedxcoords);
		run("Close");
		selectWindow(sortedycoords);
		run("Close");
	}
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
	print("\nStep 3/6. Determining start of root for each seedling");
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
				open(groupdir + "Group " + groupname + ".tif");
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
				Roi.setStrokeColor("red");
				run("Labels...", "color=white font=18 show use draw");
				run("Flatten", "stack");
				saveAs("Tiff", groupdir + groupname + " rootstartlabelled.tif");
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
	print("\nStep 4/6. Processing image to make roots more visible");
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
				open(groupdir + "Group " + groupname + ".tif");
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


function getSkeletons() { // look for smallest area that encompasses a seedling
	if (selfaware && random > 0.3)
		print("What voice is in your attic?");
	selectWindow("Log");
	print("\nStep 5/6. Drawing seedlings as single-pixel wide lines");
	listInrootgrowthdir = getFileList(rootgrowthdir);
	if (is("Batch Mode"))
		setBatchMode(false); // has to be false for roi manager to work
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
				
				open(groupdir + groupname + " rootmask.tif");
				mask = getTitle();
				nS = nSlices;
				rsc = "rootstartcoordinates";
				rsctsv = groupname + " " + rsc + ".tsv";
				seedlingpositionszip = groupname + " seedlingpositions.zip";
				roiManager("reset");
				open(groupdir + seedlingpositionszip);
				open(groupdir + rsctsv);
				lastslicecoord = "lastslicecoordinates";
				Table.create(lastslicecoord);
				roicount = roiManager("count");

				for (roino = 0; roino < roicount; roino ++) {
					lastpos = ((nS-1) * roicount) + roino; // position in last image
					xmlast = Table.get("XM", lastpos, rsctsv);
					ymlast = Table.get("YM", lastpos, rsctsv);
					toScaled(xmlast, ymlast); // scaled to make it easier to getROIdimensions later
					nrlastslicecoord = Table.size(lastslicecoord);
					Table.set("XM", nrlastslicecoord, xmlast, lastslicecoord);
					Table.set("YM", nrlastslicecoord, ymlast, lastslicecoord);
				}
				//Table.save(groupdir + groupname + " " + lastslicecoord + ".tsv", lastslicecoord);
				ordercoords(ROOTS);
				selectWindow(lastslicecoord);
				run("Close");
				run("Set Measurements...", "center redirect=None decimal=5");
				roiManager("deselect"); // nothing is selected
				roiManager("multi-measure"); // all rois measured
				roiManager("reset");
				Table.rename("Results", lastslicecoord);
				noOfroots = Table.size(lastslicecoord);
				selectWindow(mask);
				setSlice(nSlices);
				run("Create Selection");
				selectiontype = selectionType();
				
				if (selectiontype == 9) {
					//run("Set Measurements...", "area redirect=None decimal=5");
					roiManager("split");
					//roiManager("select", 0);
					//roiManager("delete");
					noOfobjects = roiManager("count");
					roistodelete = "roistodelete";
					Table.create(roistodelete);
					//containspoint = false;
				for (objectno = 0; objectno < noOfobjects; objectno ++) {
					containsrsc = false;
					roiManager("select", objectno);
					//roiManager("measure");
					//areaobj = getResult("Area", nResults-1);
					//if (areaobj >= 0.002) {
						Roi.getContainedPoints(xpoints, ypoints); // get all points in current object	
						for (pointindex = 0; pointindex < xpoints.length; pointindex ++) { //for each point
							for (rootindex = 0; rootindex < noOfroots; rootindex ++) { //test if it matches any of the rsc
								xmcur = Table.get("XM", rootindex, lastslicecoord); 
								ymcur = Table.get("YM", rootindex, lastslicecoord);
								toUnscaled(xmcur, ymcur);
								diffx = abs(xpoints[pointindex] - xmcur); // distance from xm last slice of current object
								diffy = abs(ypoints[pointindex] - ymcur); 
								toScaled(diffx, diffy);
								if (diffx < 0.1 && diffy < 0.1) {
									containsrsc = true;
									roiManager("select", objectno);
									roiManager("rename", IJ.pad(rootindex+1, 2));
									roiManager("Remove Slice Info");
								}
							}
						}
					//}
					//if (containsrsc == false || areaobj < 0.002) {
					if (containsrsc == false) {
						tsroidelete = Table.size(roistodelete);
						Table.set("roiindex", tsroidelete, objectno, roistodelete);
					}
				}
			}
			roiarraytodelete = Table.getColumn("roiindex", roistodelete);
			roiManager("select", roiarraytodelete);
			roiManager("delete");
			roiManager("sort");
			// check for multiple skels to one rsc
			roicount = roiManager("count");
			roiarray = Array.getSequence(roicount);
			for (roiindex = 0; roiindex < roicount-1; roiindex++){
				roiManager("select", roiindex);
				roiname = Roi.getName;
				roiManager("select", roiindex+1);
				nextroiname = Roi.getName;
				if (indexOf(roiname, nextroiname) == 0) {
					roiManager("select", newArray(roiindex, roiindex+1));
					roiManager("Combine");
					Roi.setName(roiname);
					roiManager("add");
					roiManager("select", newArray(roiindex, roiindex+1));
					roiManager("delete");
					roiindex -= 1;
					roicount -= 1;
					roiManager("sort");
				}
			}
			roiManager("save", groupdir + groupname + " seedlingskels.zip");
			close(mask);
			}
		}
	}
	if (selfaware && random > 0.2)
		print("Is everything connected? \nEverything is not everything!!");
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
				
				run("Set Measurements...", "area redirect=None decimal=5");
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
				open(groupdir + groupname + " seedlingskels.zip");
				roicount = roiManager("count");
				setBatchMode(true);
				setBatchMode("hide");
				
				for (sliceno = 1; sliceno <= nS; sliceno ++) {
					for (rootno = 0; rootno < roicount; rootno ++) {
						run("Clear Results");
						roiManager("reset");
						open(groupdir + groupname + " seedlingskels.zip");
						seedlingroicount = roiManager("count");
						allrois = Array.getSequence(roicount);
						if (seedlingroicount > 1) {
							allroisX = Array.deleteValue(allrois, rootno); // delete current roi from array
							roiManager("select", allroisX); // so it isnt deleted in roi manager
							roiManager("delete");
						}
						
						rscindex = ((sliceno-1)*roicount) + rootno;
						rscy = Table.get("YM", rscindex, rsctsv);
						selectWindow(rootmask);
						setSlice(sliceno);
						roiManager("select", 0);

						Roi.getBounds(skelx, skely, skelw, skelh);
						offsetskelx = 0.02;
						offsetskelw = 0.04;
						toUnscaled(offsetskelx, offsetskelw);
						staticoffset = 0.02;
						toUnscaled(staticoffset);
						bottomoffset = rscy - skely;
						makeRectangle(skelx - offsetskelx, rscy, skelw + offsetskelw, skelh - bottomoffset + staticoffset);
						
						roiManager("update");
						run("Duplicate...", "use");
						tempskel = getImageID();
						run("Create Selection");
						selectiontype = selectionType();
								
						if (selectiontype == 9) {
							roiManager("split");
							roiManager("select", 0);
							roiManager("delete");
							noOfobjects = roiManager("count");
							for (objectno = 0; objectno < noOfobjects; objectno ++) {
								roiManager("select", objectno);
								run("Area to Line");
								roiManager("update");
							}
							roiManager("deselect"); // nothing is selected
							roiManager("multi-measure"); // all rois measured
							lengthsarray = Table.getColumn("Length", "Results");
							Array.getStatistics(lengthsarray, min, maxlength, mean, stdDev);
						}			

						if (selectiontype > 0 && selectiontype != 9) {
							roiManager("add");
							roiManager("select", 1);
							run("Area to Line");
							roiManager("update");
							roiManager("measure");
							maxlength = Table.get("Length", Table.size("Results")-1, "Results");
						}

						if (selectiontype == -1) {
							if (sliceno > 1) {
								prevsliceno = sliceno - 2; // minus 1 for previous slice, minus 1 for table index start from 0
								prevtpindex = (prevsliceno * roicount) + rootno;
								// previous time point index
								//to reference same ROI from previous slice
								prevlength = Table.get("Root length (cm)", prevtpindex, rgm);
								maxlength = prevlength;					
							} else {
								maxlength = 0;
							}
						}
						nrrgm = Table.size(rgm);
						Table.set("Slice no.", nrrgm, sliceno, rgm);
						selectWindow(rootmask);
						setSlice(sliceno);
						slicelabel = getInfo("slice.label");
						Table.set("Slice label", nrrgm, slicelabel, rgm);
						Table.set("Root no.", nrrgm, rootno + 1, rgm);
						Table.set("Root length (cm)", nrrgm, maxlength/2, rgm); // divided by two as skeletons are two-pixel wide
						selectImage(tempskel);
						run("Close");
					}
				}
				Table.save(groupdir + groupname + " " + rgm + ".tsv", rgm);

				// graphical output
				roiManager("reset");
				roiManager("Show All with labels");
				roiManager("Associate", "true");
				roiManager("Centered", "false");
				roiManager("UseNames", "true");
				open(groupdir + groupname + " seedlingskels.zip");
				oriarray = Array.getSequence(roicount);
				for (sliceno = 1; sliceno <= nS; sliceno ++) {
					for (rootno = 0; rootno < roicount; rootno ++) {
						rscindex = ((sliceno-1)*roicount) + rootno;
						rscy = Table.get("YM", rscindex, rsctsv);
						selectWindow(rootmask);
						setSlice(sliceno);
						roiManager("select", rootno);
						
						Roi.getBounds(skelx, skely, skelw, skelh);
						offsetskelx = 0.02;
						offsetskelw = 0.04;
						toUnscaled(offsetskelx, offsetskelw);
						staticoffset = 0.02;
						toUnscaled(staticoffset);
						bottomoffset = rscy - skely;
						makeRectangle(skelx - offsetskelx, rscy, skelw + offsetskelw, skelh - bottomoffset + staticoffset);
						
						roiManager("add");
						curroicount = roiManager("count");
						roiManager("select", curroicount-1);
						roiManager("rename", IJ.pad(rootno+1, 2));
					}
				}

				roiManager("select", oriarray);
				roiManager("delete");
				run("Labels...", "color=white font=18 show use draw");
				run("Colors...", "foreground=black background=black selection=red");
				run("Flatten", "stack");
				open(groupdir + groupname + " rootstartlabelled.tif");

				nS = nSlices;
				slicelabelarray = newArray(nS);
				for (sliceno = 0; sliceno < nS; sliceno++) {
					setSlice(sliceno+1);
					slicelabel = getMetadata("Label");
					slicelabelarray[sliceno] = slicelabel;
				}
				run("Combine...", "stack1=["+ groupname + " rootstartlabelled.tif] stack2=["+ groupname + " rootmask.tif]");
			
				for (sliceno = 0; sliceno < nS; sliceno++) {
					setSlice(sliceno+1);
					setMetadata("Label", slicelabelarray[sliceno]);
				}
				
				saveAs("Tiff", groupdir + groupname + " rootgrowthdetection.tif");

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
				
				File.delete(groupdir + groupname + " masked.tif");
				File.delete(groupdir + groupname + " rootmask.tif");
				File.delete(groupdir + groupname + " seedlingskels.zip");
				File.delete(groupdir + groupname + " rootstartcoordinates.tsv");
				File.delete(groupdir + groupname + " rootstartrois.zip");
				File.delete(groupdir + groupname + " seedlingpositions.zip");
				File.delete(groupdir + groupname + " seedlingrois.zip");
				File.delete(groupdir + groupname + " lastslicecoordinates.tsv");
				File.delete(groupdir + groupname + " rootstartlabelled.tif");
				File.delete(groupdir + "roots sorted X coordinates.tsv");
				File.delete(groupdir + "roots sorted Y coordinates.tsv");
				File.delete(groupdir + "seeds Sorted X coordinates.tsv");
				File.delete(groupdir + "seeds Sorted Y coordinates.tsv");
				
				if (freshstart) {
					File.delete(groupdir + "Group " + groupname + ".tif");
					File.delete(groupdir + groupname + " rootgrowthdetection.tif");
					File.delete(groupdir + groupname + " rootgrowthmeasurement.tsv");
					File.delete(groupdir);			
				}
			}
		}
	}
	freshstart = false; 
	//turns it back to false so essential output is not deleted at end of macro
}
