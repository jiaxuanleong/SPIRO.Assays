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

var DEBUG = true; //set this to true to keep non-essential intermediate output files

showMessage("Please locate and open your experiment folder containing preprocessed data.");
maindir = getDirectory("Choose a Directory");
resultsdir = maindir + "Results" + File.separator; // all output is contained here
ppdir = resultsdir + "Preprocessing" + File.separator; // output from the proprocessing macro is here
rootgrowthdir = resultsdir + "Root Growth" + File.separator; // output from this macro will be here
if (!File.isDirectory(rootgrowthdir))
	File.makeDirectory(rootgrowthdir);
listInppdir = getFileList(ppdir);
listInrootgrowthdir = getFileList(rootgrowthdir);

step = 0;
detectOutput();

if (step <= 0)
cropGroups();
if (step <= 1)
seedPositions();
if (step <= 2)
rootStart();
if (step <= 3)
rootMask();
if (step <= 4)
rootSkel();
if (step <= 5)
rootGrowth();
if (step <= 6 && DEBUG == false)
deleteOutputs(); // deletes non-essential outputs
print("Macro complete");
selectWindow("Log");


// detect presence of output files of each function on last plate
// if not present, run the function
// also checks if user wants to rerun functions even when outputs are detected
function detectOutput() {
	if (step <= 0) { // check of cropGroups()
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
					isTiff = indexOf(outputfilename, ".tif");
					if (isTiff >= 0)
						step = 1;
				}
			}
		}
	}

	if (step == 1) {
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

	if (step == 1) { // check for seedPositions()
		for (outputfileno = 0 ; outputfileno < listInlastgroupfolder.length; outputfileno ++ ) {
			outputfilename = listInlastgroupfolder[outputfileno];
			isSeedroi = indexOf(outputfilename, "seedpositions");
			if (isSeedroi >= 0 )
				step = 2;
		}
	}

	if (step == 2) { // check for rootStart()
		for (outputfileno = 0 ; outputfileno < listInlastgroupfolder.length; outputfileno ++ ) {
			outputfilename = listInlastgroupfolder[outputfileno];
			isRsc = indexOf(outputfilename, "rootstartcoordinates");
			if (isRsc >= 0)
				step = 3;
		}
	}

	if (step == 3) { // check for rootMask()
		for (outputfileno = 0 ; outputfileno < listInlastgroupfolder.length; outputfileno ++ ) {
			outputfilename = listInlastgroupfolder[outputfileno];
			isRootmask = indexOf(outputfilename, "rootmask");
			if (isRootmask >= 0)
				step = 4;
		}
	}

	if (step == 4) { // check for rootSkel()
		for (outputfileno = 0 ; outputfileno < listInlastgroupfolder.length; outputfileno ++ ) {
			outputfilename = listInlastgroupfolder[outputfileno];
			isSkelrois = indexOf(outputfilename, "seedlingskels");
			if (isSkelrois >= 0)
				step = 5;
		}
	}

	if (step == 5) { // check for rootGrowth()
		for (outputfileno = 0 ; outputfileno < listInlastgroupfolder.length; outputfileno ++ ) {
			outputfilename = listInlastgroupfolder[outputfileno];
			isRgm = indexOf(outputfilename, "rootgrowthmeasurement");
			if (isRgm >= 0)
				step = 6;
		}
	}
}



// prompts user to make a substack, to make data size smaller by excluding time to germination etc.
// then prompts user to draw ROIs around groups of seeds to be analyzed
function cropGroups() {
	print("Cropping groups");

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
				setBatchMode(false);

			open(ppdir + platefile);
			waitForUser("Create substack",
						"Please note first and last slice to be included for root growth analysis, and indicate it in the next step.");
						roiManager("deselect");
						run("Make Substack...");
						setSlice(nSlices);
			if (ppdirno == 0) {
				roiManager("reset");
				run("ROI Manager...");
				setTool("Rectangle");
				roicount = roiManager("count");	
				while (roicount == 0) {
					waitForUser("Select each group, and add to ROI manager. ROI names will be saved.\n" +
						"Please use only letters and numbers in the ROI names. \n" + // to avoid file save issues
						"ROIs cannot share names."); // shared roi names would combine both rois and any area between
					roicount = roiManager("count");
				}
			} else {
				waitForUser("Modify ROIs and names if needed.");
			}

			run("Select None");
			setBatchMode(true);
			roicount = roiManager("count");

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

function seedPositions() {
	print("Finding seed positions");
	listInrootgrowthdir = getFileList(rootgrowthdir);
	for (platefolderno = 0; platefolderno < listInrootgrowthdir.length; platefolderno ++) {  // main loop through plates
		platefolder = listInrootgrowthdir[platefolderno];
		if (indexOf(platefolder, "plate") >= 0) { // to avoid processing any random files in the folder
			platedir = rootgrowthdir + platefolder;
			print("Processing " + platefolder);
			listInplatefolder = getFileList(platedir);
			for (groupfolderno = 0; groupfolderno < listInplatefolder.length; groupfolderno ++) {
				groupfolder = listInplatefolder[groupfolderno];
				groupdir = platedir + groupfolder;
				listIngroupdir = getFileList(groupdir);
				for (outputfileno = 0; outputfileno < listIngroupdir.length; outputfileno ++) {
					if (indexOf(listIngroupdir[outputfileno], "Group") >= 0) {
						open(groupdir + listIngroupdir[outputfileno]);
						filename = File.nameWithoutExtension;
						indexofgroup = indexOf(filename, "Group");
						groupname = substring(filename, indexofgroup + 6); //to find out group name, +6 because of the letters and a space
						close(listIngroupdir[outputfileno]);
					}
				}
				setBatchMode(false);
				open(groupdir + "Group " + groupname + ".tif");
				img = getTitle();
				// image processing, thresholding, masking, denoise
				run("Subtract Background...", "rolling=30 stack");
				run("Median...", "radius=1 stack");
				setAutoThreshold("MaxEntropy dark");
				run("Convert to Mask", "method=MaxEntropy background=Dark calculate");
				run("Options...", "iterations=1 count=4 do=Dilate stack");
				run("Remove Outliers...", "radius=2 threshold=50 which=Dark stack");
				run("Remove Outliers...", "radius=3 threshold=50 which=Dark stack");

				// create selections of all individual features on image
				roiManager("reset");
				run("Create Selection");
				run("Colors...", "foreground=black background=black selection=red");
				roiManager("Add");
				roiManager("select", 0);
				if (selectionType() == 9) {
					roiManager("split");
					roiManager("select", 0);
					roiManager("delete");

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
					maxYimg = getHeight();
					toScaled(maxYimg);
					nr = nResults;
					for (row = 0; row < nr; row ++) {
						nrTp = Table.size(tp); // number of rows
						area = getResult("Area", row);
						if (area < 0.0005) { // detected object is very small
							Table.set("Trash ROI", nrTp, row, tp);
						}
						if (area > 0.01) { // or very large
							Table.set("Trash ROI", nrTp, row, tp);
						}
						ym = getResult("YM", row);
						distancetomaxY = maxYimg - ym; //distance of detected object from bottom of image
						if (distancetomaxY < 1) { // less than 1cm 
							Table.set("Trash ROI", nrTp, row, tp);
						}
						circ = getResult("Circ.", row); // or does not fit normal seed shape
						if (circ < 0.5) {
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
				}
				// prompt user to delete any non-detected trash, then re-number as above
				Roi.setStrokeWidth(2);
				roiManager("Show All with labels");
				roiManager("Associate", "false");
				roiManager("Centered", "false");
				roiManager("UseNames", "true");
				waitForUser("Please delete any ROIs that should not be included into analysis, \n" +
							"e.g. noise selection and seedlings that have overlapping roots");
				roicount = roiManager("count");
				roiarray = Array.getSequence(roicount);
				for (roino = 0 ; roino < roicount; roino ++) {
					roiManager("select", roino);
					roiManager("rename", roino + 1); // first roi is 1
				}
				ordercoords(false);
				// calling ordercoords() with argument 'false' runs to order seed positions
				// instead argument 'true' optimizes code to order root dimensions later
				roiManager("save", groupdir + groupname + " seedpositions.zip");
				roiManager("reset");
				selectWindow(img);
				saveAs("Tiff", groupdir + groupname + " masked.tif");
				close(groupname + " masked.tif");
			}
		}
	}
}

// calling ordercoords() with argument 'true' runs to order seed positions
// otherwise done to order root dimensions later
function ordercoords(roots) {
	if (roots) {
		roicount = Table.size(lastslicecoord);
		xmroots = Table.getColumn("XM", lastslicecoord);
		ymroots = Table.getColumn("YM", lastslicecoord);
		xmascendingindexes = Array.rankPositions(xmroots);
		ymascendingindexes = Array.rankPositions(ymroots);
	} else {
		roicount = roiManager("count");
		roiarray = Array.getSequence(roicount);
		run("Clear Results");
		run("Set Measurements...", "center display redirect=None decimal=5");
		roiManager("select", roiarray);
		roiManager("multi-measure");
		seedpositions = "Seed Positions";
		Table.rename("Results", seedpositions);

		xmseeds = newArray(roicount);
		ymseeds = newArray(roicount);
		for (seednumber = 0; seednumber < roicount; seednumber ++) {
			xmcurrent = Table.get("XM", seednumber, seedpositions);
			ymcurrent = Table.get("YM", seednumber, seedpositions);
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

	rowno = 0; //assume no row of seeds to start with
	col = 0 ; //current col selection is 0
	colname = "col" + col + 1;

	if (roots) {
		Table.set(colname, rowno, ymroots[ymascendingindexes[0]], sortedycoords);
		Table.set(colname, rowno, xmroots[ymascendingindexes[0]], sortedxcoords);

		for (roino = 1; roino < roicount; roino++) {
			ymroot2 = ymroots[ymascendingindexes[roino]];
			ymroot1 = ymroots[ymascendingindexes[roino-1]];
			//toScaled(ymroot2, ymroot1);
			ydiff =  ymroot2 - ymroot1;
			if (ydiff > 1) {
				rowno += 1;
				col = 0;
			} else {
				col += 1;
			}
			colname = "col" + col + 1;
			//toUnscaled(ymroot2);
			Table.set(colname, rowno, ymroot2, sortedycoords);
			Table.set(colname, rowno, xmroots[ymascendingindexes[roino]], sortedxcoords);
		}
	} else {
		Table.set(colname, rowno, ymseeds[ymascendingindexes[0]], sortedycoords);
		Table.set(colname, rowno, xmseeds[ymascendingindexes[0]], sortedxcoords);

		for (roino = 1; roino < roicount; roino++) {
			ydiff = ymseeds[ymascendingindexes[roino]] - ymseeds[ymascendingindexes[roino-1]];
			if (ydiff > 1) {
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

	if (roots) {
		Table.save(groupdir + "roots " + sortedxcoords + ".tsv", sortedxcoords);
		Table.save(groupdir + "roots " + sortedycoords + ".tsv", sortedycoords);
		selectWindow(sortedxcoords);
		run("Close");
		selectWindow(sortedycoords);
		run("Close");
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
	print("Finding root starts");
	listInrootgrowthdir = getFileList(rootgrowthdir);
	setBatchMode(true); //this should be set to true for faster processing!
	for (platefolderno = 0; platefolderno < listInrootgrowthdir.length; platefolderno ++) {  // main loop through plates
		platefolder = listInrootgrowthdir[platefolderno];
		if (indexOf(platefolder, "plate") >= 0) { // to avoid processing any random files in the folder
			platedir = rootgrowthdir + platefolder;
			print("Processing " + platefolder);
			listInplatefolder = getFileList(platedir);
			for (groupfolderno = 0; groupfolderno < listInplatefolder.length; groupfolderno ++) {
				groupfolder = listInplatefolder[groupfolderno];
				groupdir = platedir + groupfolder;
				listIngroupdir = getFileList(groupdir);
				for (outputfileno = 0; outputfileno < listIngroupdir.length; outputfileno ++) {
					if (indexOf(listIngroupdir[outputfileno], "Group") >= 0) {
						open(groupdir + listIngroupdir[outputfileno]);
						filename = File.nameWithoutExtension;
						indexofgroup = indexOf(filename, "Group");
						groupname = substring(filename, indexofgroup + 6); //to find out group name, +6 because of the letters and a space
						close(listIngroupdir[outputfileno]);
					}
				}

				open(groupdir + groupname + " masked.tif");
				mask = getTitle();
				roiManager("reset");
				roiManager("open", groupdir + groupname + " seedpositions.zip");
				roicount = roiManager("count");
				roiarray = Array.getSequence(roicount);
				run("Set Measurements...", "center redirect=None decimal=5");
				run("Clear Results");
				roiManager("select", roiarray);
				roiManager("multi-measure");

				scaledwroi = 0.12; //width of ROI for finding root start coordinates is 0.12cm
				scaledhroi = 0.18; //height of ROI is 0.18cm
				unscaledwroi = 0.12;
				unscaledhroi = 0.18;
				toUnscaled(unscaledwroi, unscaledhroi);

				nS = nSlices;
				rsc = "Root start coordinates";
				Table.create(rsc);

				for (sliceno = 1; sliceno <= nS; sliceno ++) { //for each slice
					setSlice(sliceno); //starting with first slice
					if (sliceno == 1) { //if first slice, obtain XY coordinates from Results to make ROI
						roiManager("reset");
						yref = "YRef";
						Table.create(yref);  //table for "y references" which contain the top and bottom borders

						//the borders are setting the top/bottom limits within which the roi can be positioned to prevent rsc
						// from jumping to hypocotyls or sliding down roots
						for (roino = 0; roino < roicount; roino ++) {
							xisp = getResult("XM", roino); //xisp is x initial seed roinoition
							yisp = getResult("YM", roino); //yisp is y initial seed position
							ytb = yisp - 0.05; //y top border
							ybb = yisp + 0.4;  //y bottom border
							Table.set("ytb", roino, ytb, yref); //y (top border) cannot be more than 0.4cm to the top of initial xm
							Table.set("ybb", roino, ybb, yref); //y (bottom border) cannot be more than yisp
							topoffset = 0.05; //needed to include a little more of the top bit from the centre of mass

							//imagej takes top + leftmost coordinate to make rois
							yroi = yisp - topoffset; //yroi is top+leftmost ycoordinate of roi
							xroi = xisp - 0.5*scaledwroi; //xroi is top+leftmost xcoordinate of roi
							toUnscaled(xroi, yroi);
							makeRectangle(xroi, yroi, unscaledwroi, unscaledhroi);
							roiManager("add");
							Table.save(groupdir + "yref.tsv", yref);
						}
						selectWindow("Results");
						run("Close");
					} else {
						//for subsequent slices, obtain XY centre of mass coordinates of previous slice
						roiManager("reset");
						prevsliceno = sliceno - 2;

						for (roino = 0; roino < roicount; roino++) {
							rowIndex = (prevsliceno * roicount) + roino;
							//rowIndex to reference same ROI from previous slice
							//xm, ym are coordinates for the centre of mass obtained through erosion
							xmprev = Table.get("XM", rowIndex, rsc); //xm of prev slice
							ymprev = Table.get("YM", rowIndex, rsc);  //ym of prev slice
							toScaled(xmprev, ymprev);
							ytb = Table.get("ytb", roino, yref);
							ybb = Table.get("ybb", roino, yref);
							yroi = ymprev - topoffset; //yroi is top+leftmost ycoordinate of roi
							xroi = xmprev - 0.5*scaledwroi; //xroi is top+leftmost xcoordinate of roi and 0.06 is half of h (height)

							//the borders are setting the top/bottom limits within which the roi can be positioned to prevent rsc from jumping to hypocotyls or sliding down roots
							if (yroi < ytb) { //top border exceeded by top of roi
								yroi = ytb;
							}

							yroibottom = yroi + scaledhroi; //bottom line of roi is y
							if (yroibottom > ybb) { //lower limit of roi bottom border exceeded
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
						}
					}

					run("Set Measurements...", "area center display redirect=None decimal=5");
					for (roino = 0; roino < roicount; roino ++) { //for number of rois
						roiManager("select", roino);
						run("Analyze Particles...", "display clear summarize slice");

						count = Table.get("Count", Table.size("Summary of " + mask) - 1, "Summary of " + mask);
						totalarea = Table.get("Total Area", Table.size("Summary of "+ mask ) - 1, "Summary of " + mask);
						if (count == 0) { //no object detected, masking erased seed due to seed too small - copy xm/ym from previous slice
							// don't do this for the first slice
							rowIndex = (prevsliceno*roicount) + roino; //to reference same ROI from previous slice
							//xm, ym are coordinates for the centre of mass obtained through erosion
							xmprev = Table.get("XM", rowIndex, rsc); //xm of prev slice
							ymprev = Table.get("YM", rowIndex, rsc); //ym of prev slice
							nr = Table.size(rsc);
							Table.set("Slice", nr, sliceno, rsc);
							Table.set("ROI", nr, roino + 1, rsc);
							Table.set("XM", nr, xmprev, rsc); //set xm as previous slice
							Table.set("YM", nr, ymprev, rsc); //ym as previous slice
							Table.update;
						} else { //object detected, erode then analyse particles for xm/ym
							erosionround = 1;
							while (totalarea > 0.002 && erosionround < 15) {
								//if erosion is not working due to bad thresholding, total area never decreases, rsc is copied from previous slice
								roiManager("select", roino);
								run("Options...", "iterations=1 count=1 do=Erode");
								roiManager("select", roino);
								run("Analyze Particles...", "display summarize slice");

								count = Table.get("Count", Table.size - 1, "Summary of " + mask);
								if (count == 0) { //erode went too far, particle disappeared
									totalarea = 0; //to get out of the while loop
								} else {
									totalarea = Table.get("Total Area", Table.size - 1, "Summary of " + mask);
								}
								erosionround += 1;
							}
							if (erosionround < 15) {
								while (totalarea > 0.012) {
									roiManager("select", roino);
									run("Options...", "iterations=1 count=3 do=Erode");
									roiManager("select", roino);
									run("Analyze Particles...", "display clear summarize slice");

									count = Table.get("Count", Table.size - 1, "Summary of "+mask);
									if (count == 0) { //erode went too far, particle disappeared
										totalarea = 0; //to get out of the while loop
									} else {
										totalarea = Table.get("Total Area", Table.size-1, "Summary of "+mask);
									}
								}

								if (count > 1) {
									area = newArray(count);
									for (resultrow = 0; resultrow < count; resultrow ++) {
										area[resultrow] = getResult("Area", nResults-(resultrow + 1));
									}
									areaasc = Array.rankPositions(area);
									areadesc = Array.invert(areaasc);
									maxarea = areadesc[0];

									xm = getResult("XM", nResults - (maxarea + 1));
									ym = getResult("YM", nResults - (maxarea + 1));
								} else {
									xm = getResult("XM", nResults - 1);
									ym = getResult("YM", nResults - 1);
								}

								toUnscaled(xm, ym);

								nr = Table.size(rsc);
								Table.set("Slice", nr, sliceno, rsc);
								Table.set("ROI", nr, roino + 1, rsc);
								Table.set("XM", nr, xm, rsc);
								Table.set("YM", nr, ym, rsc);
								Table.update;
							}

							if (erosionround == 15) {
								rowIndex = (prevsliceno * roicount) + roino; //to reference same ROI from previous slice
								//xm, ym are coordinates for the centre of mass obtained through erosion
								xmprev = Table.get("XM", rowIndex, rsc); //xm of prev slice
								ymprev = Table.get("YM", rowIndex, rsc); //ym of prev slice
								nr = Table.size(rsc);
								Table.set("Slice", nr, sliceno, rsc);
								Table.set("ROI", nr, roino + 1, rsc);
								Table.set("XM", nr, xmprev, rsc); //set xm as previous slice
								Table.set("YM", nr, ymprev, rsc); //ym as previous slice
								Table.update;
							}
						}
					}
				}
				close(yref);
				close("Results");
				close("Summary of "+mask);
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
					roiManager("select", row);
					roiManager("rename", roino);
				}
				roiManager("save", groupdir + groupname + " rootstartrois.zip");

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
	print("Masking roots");
	setBatchMode(true);
	listInrootgrowthdir = getFileList(rootgrowthdir);
	for (platefolderno = 0; platefolderno < listInrootgrowthdir.length; platefolderno ++) {  // main loop through plates
		platefolder = listInrootgrowthdir[platefolderno];
		if (indexOf(platefolder, "plate") >= 0) { // to avoid processing any random files in the folder
			platedir = rootgrowthdir + platefolder;
			print("Processing " + platefolder);
			listInplatefolder = getFileList(platedir);
			for (groupfolderno = 0; groupfolderno < listInplatefolder.length; groupfolderno ++) {
				groupfolder = listInplatefolder[groupfolderno];
				groupdir = platedir + groupfolder;
				listIngroupdir = getFileList(groupdir);
				for (outputfileno = 0; outputfileno < listIngroupdir.length; outputfileno ++) {
					if (indexOf(listIngroupdir[outputfileno], "Group") >= 0) {
						open(groupdir + listIngroupdir[outputfileno]);
						filename = File.nameWithoutExtension;
						indexofgroup = indexOf(filename, "Group");
						groupname = substring(filename, indexofgroup + 6); //to find out group name, +6 because of the letters and a space
						close(listIngroupdir[outputfileno]);
					}
				}
				open(groupdir + "Group " + groupname + ".tif");
				///!
				/// setBatchMode(false);
				setBatchMode(true); // this can be true
				img = getTitle();
				run("Set Scale...", "global");
				run("Subtract Background...", "rolling=50 stack");
				dayslice = 1; //dayslice is the first day image
				setSlice(dayslice);
				slicelabel = getInfo("slice.label");
				while (indexOf(slicelabel, "day") < 0) {
					dayslice += 1;
					setSlice(dayslice);
					slicelabel = getInfo("slice.label");
				}
				dayslicelabel = getInfo("slice.label");

				nightslice = 1; //nightslice is the first night image
				setSlice(nightslice);
				slicelabel = getInfo("slice.label");
				while (indexOf(slicelabel, "night") < 0) {
					nightslice += 1;
					setSlice(nightslice);
					slicelabel = getInfo("slice.label");
				}
				nightslicelabel = getInfo("slice.label");

				nS = nSlices;
				setSlice(nightslice);
				run("Duplicate...", "use");
				nightimg = "FirstNightImg";
				rename(nightimg);
				selectWindow(img);
				setSlice(dayslice);
				run("Duplicate...", "use");
				dayimg = "FirstDayImg";
				rename(dayimg);


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
						} else { //night image
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
				close(img);
				selectWindow("Stack");
				rename(img);
				 setBatchMode("show");
				setOption("BlackBackground", false);
				run("Convert to Mask", "method=MaxEntropy background=Dark calculate");

				for (sliceno = 1; sliceno <= nS; sliceno ++) {
					selectWindow(img);
					setSlice(sliceno);
					curslicelabel = getInfo("slice.label");

					if (indexOf(curslicelabel, "day") > 0) {
						run("Remove Outliers...", "radius=5 threshold=50 which=Bright slice");
						run("Remove Outliers...", "radius=3 threshold=50 which=Dark slice");
						run("Remove Outliers...", "radius=3 threshold=50 which=Dark slice");
						// run("Remove Outliers...", "radius=3 threshold=50 which=Dark slice");
					} else { //night image
						run("Remove Outliers...", "radius=5 threshold=50 which=Bright slice");
						run("Remove Outliers...", "radius=3 threshold=50 which=Dark slice");
						run("Remove Outliers...", "radius=4 threshold=50 which=Dark slice");
						// run("Remove Outliers...", "radius=4 threshold=50 which=Dark slice");
					}
				}

				// run("Options...", "iterations=1 count=1 pad do=Skeletonize stack");
				// run("Options...", "iterations=1 count=2 pad do=Erode stack");
				setBatchMode("show"); //this has to be "show" here!
				setBatchMode(true);
				overlay = true;

				if (overlay == true) {
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
					//rename(slicelabel);
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
				// run("Options...", "iterations=2 count=1 pad do=Dilate stack");
				run("Options...", "iterations=1 count=1 pad do=Skeletonize stack");
				saveAs("Tiff", groupdir + groupname + " rootmask.tif");
				close(groupname + " rootmask.tif");
			}
		}
	}
}


function rootSkel() { //look for smallest area that encompasses a seedling
	setBatchMode(false);
	print("Finding seedling skeletons");
	listInrootgrowthdir = getFileList(rootgrowthdir);
	for (platefolderno = 0; platefolderno < listInrootgrowthdir.length; platefolderno ++) {  // main loop through plates
		platefolder = listInrootgrowthdir[platefolderno];
		if (indexOf(platefolder, "plate") >= 0) { // to avoid processing any random files in the folder
			platedir = rootgrowthdir + platefolder;
			print("Processing " + platefolder);
			listInplatefolder = getFileList(platedir);
			for (groupfolderno = 0; groupfolderno < listInplatefolder.length; groupfolderno ++) {
				groupfolder = listInplatefolder[groupfolderno];
				groupdir = platedir + groupfolder;
				listIngroupdir = getFileList(groupdir);
				for (outputfileno = 0; outputfileno < listIngroupdir.length; outputfileno ++) {
					if (indexOf(listIngroupdir[outputfileno], "Group") >= 0) {
						open(groupdir + listIngroupdir[outputfileno]);
						filename = File.nameWithoutExtension;
						indexofgroup = indexOf(filename, "Group");
						groupname = substring(filename, indexofgroup + 6); //to find out group name, +6 because of the letters and a space
						close(listIngroupdir[outputfileno]);
					}
				}
				open(groupdir + groupname + " rootmask.tif");
				mask = getTitle();
				nS = nSlices;
				rsc = "rootstartcoordinates";
				rsctsv = groupname + " " + rsc + ".tsv";
				seedpositionszip = groupname + " seedpositions.zip";
				roiManager("reset");
				open(groupdir + rsctsv);
				open(groupdir + seedpositionszip);
				lastslicecoord = "lastslicecoordinates";
				Table.create(lastslicecoord);
				roicount = roiManager("count");

				for (roino = 0; roino < roicount; roino ++) {
					lastpos = ((nS-1) * roicount) + roino; //position in last image
					xmlast = Table.get("XM", lastpos, rsctsv);
					ymlast = Table.get("YM", lastpos, rsctsv);
					toScaled(xmlast, ymlast); //scaled to make it easier to getROIdimensions later
					nrlastslicecoord = Table.size(lastslicecoord);
					Table.set("XM", nrlastslicecoord, xmlast, lastslicecoord);
					Table.set("YM", nrlastslicecoord, ymlast, lastslicecoord);
				}
				Table.save(groupdir + groupname + " " + lastslicecoord + ".tsv", lastslicecoord);
				ordercoords(true);

				/////here to get ROI dimensions
				sortedxcoords = "roots sorted X coordinates";
				sortedxcoordstsv = sortedxcoords + ".tsv";
				open(groupdir + sortedxcoordstsv);
				colnames = Table.headings(sortedxcoordstsv);
				colnamessplit = split(colnames, "	");
				colno = lengthOf(colnamessplit);

				if (colno > 1) {
					getcol = 1;
					getcolname = "col" + getcol;
					//columns might have zeroes at the beginning due to uneven number of columns, and these values need to be skipped
					xfirstcol = Table.get(getcolname, 0, sortedxcoordstsv);
					while (xfirstcol <= 0) {
						getcol = getcol + 1;
						getcolname = "col" + getcol;
						xfirstcol = Table.get(getcolname, 0, sortedxcoordstsv);
						}

				getcol2 = getcol + 1;
				getcol2name = "col" + getcol2;
				xsecondcol = Table.get(getcol2name, 0, sortedxcoordstsv);
				//xfirstcol and xsecondcol are names for the first two non-zero columns
				xdiff = xsecondcol - xfirstcol;
				roiwidth = 1.5*xdiff;
				} else {
					xfirstcol = Table.get("col1", 0, sortedxcoordstsv);
					roiwidth = getWidth(stack1);
				}
				sortedycoords = "roots sorted Y coordinates";
				sortedycoordstsv = sortedycoords + ".tsv";
				open(groupdir + sortedycoordstsv);
				rowno = Table.size (sortedycoordstsv) - 1;
				if (rowno >= 1) {
					//getcolname already defines the first non-zero column, as obtained above
					nyrow = 0;
					yfirstrow = Table.get(getcolname, nyrow, sortedycoordstsv);
					ysecondrow = Table.get(getcolname, nyrow+1, sortedycoordstsv);
					while (ysecondrow <= 0) {
						getcol += 1;
						getcolname = "col" + getcol;
						ysecondrow = Table.get(getcolname, nyrow+1, sortedycoordstsv);
					}
					ydiff = ysecondrow - yfirstrow;
					roiheight = ydiff - 0.2; //cuts off bottom of roi so it doesnt cut into next row
				} else {
					yfirstrow = Table.get("col1", 0, sortedycoordstsv);
					roiheight = getHeight() - yfirstrow;
				}

				groupwidth = getWidth();
				nrlastslicecoord = Table.size(lastslicecoord);
				roiManager("reset"); //resets the points made in ordercoords()

				setSlice(nS);
				for (row = 0; row < rowno + 1; row ++) {
					for (col = 0; col < colno; col ++) {
						colname = "col" + col + 1;
						xm = Table.get(colname, row, sortedxcoordstsv);
						ym = Table.get(colname, row, sortedycoordstsv);
						if (xm > 0 && ym > 0) {
							roiytopleft = ym - 0.4; //offset at the top because cotyledons shift downwards comparing first slice to LNI
							roixtopleft = xm - (0.5*roiwidth);
							toUnscaled(roixtopleft, roiytopleft);
							toUnscaled(roiwidth, roiheight);
							if (roixtopleft < 0)
							roixtopleft = 0;
							if (roiytopleft < 0)
							roiytopleft = 0;
							makeRectangle(roixtopleft, roiytopleft, roiwidth, roiheight);
							roiManager("add");
							roiManager("select", roiManager("count")-1);
							roiManager("rename", roiManager("count"));
							roiManager("select", roiManager("count")-1);
							roiManager("Remove Slice Info");
							toScaled(roiwidth, roiheight); //revert so it can be recalculated
						}
					}
				}
				roiManager("save", groupdir + groupname + " seedlingrois.zip");

				setSlice(nS);
				run("Clear Results");
				rootroicount = roiManager("count");
				roiarraysdling = Array.getSequence(rootroicount);

				for (rootno = 0; rootno < rootroicount; rootno ++) {
					if (rootno > 0) {
					roiManager("reset");
					roiManager("open", groupdir + groupname + " seedlingrois.zip");
					}
					roiarraysdlingX = Array.deleteValue(roiarraysdling, rootno); //delete current roi from array
					roiManager("select", roiarraysdlingX); //so it isnt deleted in roi manager
					roiManager("delete");
					roiManager("select", 0);
					Roi.getBounds(rootboundx, rootboundy, rootboundw, rootboundh);

					run("Duplicate...", "use");
					tempmultipleskel = getTitle();
					/*
					roitopy = 0;
					roimidx = getWidth()/2;
					toScaled(roitopy, roimidx);
					*/
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
						roiManager("deselect"); //nothing is selected
						roiManager("measure"); //all rois measured
						lengthsarray = Table.getColumn("Length", "Results");
						// xmarray = Table.getColumn("XM", "Results");
						// ymarray = Table.getColumn("YM", "Results");
						lengthspositions = Array.rankPositions(lengthsarray);
						Array.reverse(lengthspositions);

						lastpos = ((nS-1) * roicount) + rootno; //position in last image
						xmlast = Table.get("XM", lastpos, rsctsv);
						ymlast = Table.get("YM", lastpos, rsctsv);
						containsrsc = false;
						testindex = -1;
						pointindex = -1;
						containspoint = false;
						while (containsrsc == false) {
							testindex += 1;
							if (testindex == lengthspositions.length-1) {
									testindex = 0;
									containsrsc = true;
									containspoint = true;
								}
							maxlengthindex = lengthspositions[testindex];
							roiManager("select", maxlengthindex);
							Roi.getContainedPoints(xpoints, ypoints);
							exitloop = false;
							pointindex = -1;
							while (containspoint == false && exitloop == false) {
								pointindex += 1;
								if (pointindex == xpoints.length-1 ) {
									exitloop = true;
								}
								diffx = abs(xpoints[pointindex] - xmlast);
								diffy = abs(ypoints[pointindex] - ymlast);
								toScaled(diffx, diffy);
								if (diffx < 0.1 || diffy < 0.1) {
									containspoint = true;
								}
							}
						}

						lengthspositionsX = Array.deleteIndex(lengthspositions, testindex); //remove index of longest length
						roiManager("select", lengthspositionsX);
						roiManager("delete"); //so it is not deleted here
						roiManager("select", 0);
						Roi.getBounds(rootx, rooty, rootw, rooth);
						close("Results");
					}
					if (selectiontype < 9 && selectiontype != -1) {
						roiManager("add");
						Roi.getBounds(rootx, rooty, rootw, rooth);
						 roiManager("select", 0);
						 roiManager("delete");
					}

					if (selectiontype > -1) {
					selectWindow(mask);
					roiManager("select", 0);
					Roi.move(rootboundx+rootx, rootboundy+rooty);
					roiManager("update");
					}
					roiManager("select", 0);
					roiManager("rename", IJ.pad(rootno+1, 2)); //names roi according to seed number
					roiManager("Remove Slice Info");
					if (rootno > 0) {
						roiManager("open", groupdir + groupname + " seedlingskels.zip");
					}
					roiManager("save", groupdir + groupname + " seedlingskels.zip");
					close(tempmultipleskel);
				}
				roiManager("sort");
				roiManager("save", groupdir + groupname + " seedlingskels.zip");
				close(mask);
			}
		}
	}
}

function rootGrowth() {
	print("Tracking root growth");
	listInrootgrowthdir = getFileList(rootgrowthdir);
	for (platefolderno = 0; platefolderno < listInrootgrowthdir.length; platefolderno ++) {  // main loop through plates
		platefolder = listInrootgrowthdir[platefolderno];
		if (indexOf(platefolder, "plate") >= 0) { // to avoid processing any random files in the folder
			platedir = rootgrowthdir + platefolder;
			print("Processing " + platefolder);
			listInplatefolder = getFileList(platedir);
			for (groupfolderno = 0; groupfolderno < listInplatefolder.length; groupfolderno ++) {
				groupfolder = listInplatefolder[groupfolderno];
				groupdir = platedir + groupfolder;
				listIngroupdir = getFileList(groupdir);
				for (outputfileno = 0; outputfileno < listIngroupdir.length; outputfileno ++) {
					if (indexOf(listIngroupdir[outputfileno], "Group") >= 0) {
						open(groupdir + listIngroupdir[outputfileno]);
						filename = File.nameWithoutExtension;
						indexofgroup = indexOf(filename, "Group");
						groupname = substring(filename, indexofgroup + 6); //to find out group name, +6 because of the letters and a space
						close(listIngroupdir[outputfileno]);
					}
				}
				setBatchMode(false);
				open(groupdir + groupname + " rootmask.tif");
				rootmask = getTitle();
				roiManager("reset");
				// open(groupdir + groupname + " seedlingskels.zip");
				rsctsv = groupname + " rootstartcoordinates.tsv";
				open(groupdir + rsctsv);
				nS = nSlices;
				rgm = "rootgrowthmeasurement";
				Table.create(rgm);
				setBatchMode(true);
				open(groupdir + groupname + " seedlingskels.zip");
				roicount = roiManager("count");
				for (sliceno = 1; sliceno <= nS; sliceno ++) {
					for (rootno = 0; rootno < roicount; rootno ++) {
						run("Clear Results");
						roiManager("reset");
						open(groupdir + groupname + " seedlingskels.zip");
						allrois = Array.getSequence(roicount);
						allroisX = Array.deleteValue(allrois, rootno); //delete current roi from array
						roiManager("select", allroisX); //so it isnt deleted in roi manager
						roiManager("delete");

						rscindex = ((sliceno-1)*roicount) + rootno;
						rscy = Table.get("YM", rscindex, rsctsv);
						selectWindow(rootmask);
						setSlice(sliceno);
						roiManager("select", 0);
						Roi.getBounds(skelx, skely, skelw, skelh);
						makeRectangle(skelx, rscy, skelw, skelh);
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
							roiManager("deselect"); //nothing is selected
							roiManager("multi-measure"); //all rois measured
							lengthsarray = Table.getColumn("Length", "Results");
							Array.getStatistics(lengthsarray, min, maxlength, mean, stdDev);
						}

						if (selectiontype > 0 && selectiontype != 9) {
							roiManager("add");
							roiManager("select", 1);
							run("Area to Line");
							roiManager("update");
							roiManager("measure");
							maxlength = Table.get("Length", 0, "Results");
						}

						if (selectiontype == -1) {
							if (sliceno > 1) {
								prevlength = Table.get("Root length", nrrgm-1, rgm);
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
							Table.set("Root length", nrrgm, maxlength, rgm);
							selectImage(tempskel);
							run("Close");
					}
				}

				Table.save(groupdir + groupname + " " + rgm + ".tsv", rgm);
				

				// graphical output
				setBatchMode("hide");
				setBatchMode(true);
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
						selectWindow(rootmask);
						roiManager("select", rootno);
						Roi.getBounds(skelx, skely, skelw, skelh);
						rscy = Table.get("YM", rscindex, rsctsv);
						selectWindow(rootmask);
						setSlice(sliceno);
						makeRectangle(skelx, rscy, skelw, skelh);
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
				run("Combine...", "stack1=["+ groupname + " rootstartlabelled.tif] stack2=["+ groupname + " rootmask.tif]");
				saveAs("Tiff", groupdir + groupname + " rootgrowthdetection.tif");				
				
				list = getList("window.titles");
				Array.deleteValue(list, "Log");
				for (i=0; i<list.length; i++) {
					winame = list[i];
					selectWindow(winame);
					run("Close");
				}
				close("*");
			}
		}
	}
}

function deleteOutputs() {
	print("Deleting non-essential files");
	listInrootgrowthdir = getFileList(rootgrowthdir);
	for (platefolderno = 0; platefolderno < listInrootgrowthdir.length; platefolderno ++) {  // main loop through plates
		platefolder = listInrootgrowthdir[platefolderno];
		if (indexOf(platefolder, "plate") >= 0) { // to avoid processing any random files in the folder
			platedir = rootgrowthdir + platefolder;
			print("Processing " + platefolder);
			listInplatefolder = getFileList(platedir);
			for (groupfolderno = 0; groupfolderno < listInplatefolder.length; groupfolderno ++) {
				groupfolder = listInplatefolder[groupfolderno];
				groupdir = platedir + groupfolder;
				listIngroupdir = getFileList(groupdir);
				for (outputfileno = 0; outputfileno < listIngroupdir.length; outputfileno ++) {
					if (indexOf(listIngroupdir[outputfileno], "Group") >= 0) {
						open(groupdir + listIngroupdir[outputfileno]);
						filename = File.nameWithoutExtension;
						indexofgroup = indexOf(filename, "Group");
						groupname = substring(filename, indexofgroup + 6); //to find out group name, +6 because of the letters and a space
						close(listIngroupdir[outputfileno]);
					}
				}
				File.delete(groupdir + groupname + " masked.tif");
				File.delete(groupdir + groupname + " rootmask.tif");
				File.delete(groupdir + groupname + " seedlingskels.zip");
				File.delete(groupdir + groupname + " rootstartcoordinates");
				File.delete(groupdir + groupname + " rootstartrois");
				File.delete(groupdir + groupname + " seedpositions");
				File.delete(groupdir + groupname + " seedlingrois");
				File.delete(groupdir + groupname + " lastslicecoordinates");
				File.delete(groupdir + "roots sorted X coordinates");
				File.delete(groupdir + "roots sorted Y coordinates");
				File.delete(groupdir + "seeds Sorted X coordinates");
				File.delete(groupdir + "seeds Sorted Y coordinates");
				File.delete(groupdir + "yref");
			}
		}
	}
}
