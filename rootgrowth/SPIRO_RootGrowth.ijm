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

// table names
var ra = "Root analysis";
var bi = "Branch information";

showMessage("Please locate and open your experiment folder containing preprocessed data.");
maindir = getDirectory("Choose a Directory");
resultsdir = maindir + File.separator + "Results" + File.separator; // all output is contained here
ppdir = resultsdir + File.separator + "Preprocessing" + File.separator; // output from the proprocessing macro is here
rootgrowthdir = resultsdir + "Root Growth"; // output from this macro will be here
if (!File.isDirectory(rootgrowthdir))
	File.makeDirectory(rootgrowthdir);
listInppdir = getFileList(ppdir);
listInrootgrowthdir = getFileList(rootgrowthdir);
step = 0;
detectOutput();
if (step == 1)
cropGroups();
if (step == 2)
seedPositions();

// detect presence of output files of each function on last plate
// if not present, run the function
// also checks if user wants to rerun functions even when outputs are detected
function detectOutput() {
	if (step == 0) { // check of cropGroups()
		lastplatefile = listInppdir [listInppdir.length-1]; // checking on last plate
		fnsplit = split(lastplatefile, "_");
		lastplatename = fnsplit[0];
		lastplatefolder = rootgrowthdir + File.separator + lastplatename + File.separator;
		if (endsWith(lastplatefolder, File.separator)) {
			listInlastplatefolder = getFileList(lastplatefolder);
			if (listInlastplatefolder.length > 0) {
				lastgroupfolder = lastplatefolder + listInlastplatefolder[listInlastplatefolder.length-1]; 
				listInlastgroupfolder = getFileList(lastgroupfolder);
				for (outputfileno = 0 ; outputfileno < listInlastgroupfolder.length; outputfileno ++ ) {
					outputfilename = File.getName(listInlastgroupfolder[outputfileno]);
					isTiff = indexOf(outputfilename, ".tif");
					if (isTiff > 0)
						step = 1;
						print(step);
				}
			}
		}
	}

	if (step >= 1) { 
		// identify last plate folder
		listInrootgrowthdir = getFileList(rootgrowthdir);
		for (platefolderno = 0; platefolderno < listInrootgrowthdir.length; platefolderno ++) {
				if (!endsWith(rootgrowthdir + listInrootgrowthdir[platefolderno], File.separator)) // if it is NOT a directory
				listInrootgrowthdir = Array.deleteIndex(listInrootgrowthdir, platefolderno); // delete from platedir list 
		}
		
		lastplatefile = listInppdir [listInppdir.length-1]; // checking on last plate
		fnsplit = split(lastplatefile, "_");
		lastplatename = fnsplit[0];
		lastplatedir = rootgrowthdir + File.separator + lastplatename + File.separator;
		listInlastplatedir = getFileList(lastplatedir);
		// identify last group folder
		// for (groupfolderno = 0; groupfolderno < listInlastplatedir.length; groupfolderno ++) {
			// if (!endsWith(lastplatedir + listInlastplatedir[groupfolderno], File.separator)) // if it is NOT a directory
			//	listInlastplatedir = Array.deleteIndex(listInlastplatedir, groupfolderno); // delete from platedir list 
		// } somehow file separator doesnt work
		lastgroupfolder = lastplatedir + listInlastplatedir [listInlastplatedir.length-1]; 
		lastgroupdir = lastplatedir + lastgroupfolder;	
	}

	if (step == 1) { // check for seedPositions()
		for (outputfileno = 0 ; outputfileno < listInlastgroupfolder.length; outputfileno ++ ) {
			outputfilename = listInlastgroupfolder[outputfileno];
			isSeedroi = indexOf(outputfilename, "seedpositions");
			if (isSeedroi > 0 )
				step = 2;
				print(step);
		}
	}
}
	


// prompts user to make a substack, to make data size smaller by excluding time to germination etc.
// then prompts user to draw ROIs around groups of seeds to be analyzed
function cropGroups() {
	print("Cropping groups");

	for (ppdirno = 0; ppdirno < listInppdir.length; ppdirno ++) {  // main loop through plates
		if (indexOf (listInppdir[ppdirno], "preprocessed") > 0) { // to avoid processing any random files in the folder		
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
						run("Make Substack...");
			
			run("ROI Manager...");
			setTool("Rectangle");
			roiManager("reset");
			roicount = roiManager("count"); 
			while (roicount == 0) {
				waitForUser("Select each group, and add to ROI manager. ROI names will be saved.\n" +
					"Please use only letters and numbers in the ROI names. \n" + // to avoid file save issues
					"ROIs cannot share names."); // shared roi names would combine both rois and any area between
				roicount = roiManager("count");
			} 
			run("Select None");
			setBatchMode(true);
			
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
				close(roiname + "*");
			}
			close(platefile);
		}
	}
}

function seedPositions() {
	print("Finding seed positions");
	for (platefolderno = 0; platefolderno < listInrootgrowthdir.length; platefolderno ++) {  // main loop through plates
		platefolder = listInrootgrowthdir[platefolderno];
		//if (indexOf(platefolder, "plate") > 0) { // to avoid processing any random files in the folder		
			platedir = rootgrowthdir + platefolder;
			print("Processing " + platefolder);
			listInplatefolder = getFileList(listInplatefolder);
			for (groupfolderno = 0; listInplatefolder < listInplatefolder.length; groupfolderno ++) {
				groupfolder = listInplatefolder[listInplatefolder];
				groupname = groupfolder;
				groupdir = platedir + groupfolder;
				open(groupdir + groupname + ".tif");
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
				roiManager("split");
				roiManager("select", 0);
				roiManager("delete");

				// delete trash ROI which are features detected as below a certain area
				// using table as a workaround to roi indexes changing if deletion happens one by one 
				roicount = roiManager("count");
				roiarray = Array.getSequence(roicount);
				run("Set Measurements...", "area redirect=None decimal=2");
				roiManager("select", roiarray);
				roiManager("multi-measure");
				tp = "Trash positions";
				Table.create(tp);
				nr = nResults; 
				for (row = 0; row < nr; row ++) {
					area = getResult("Area", row);
					if (area<0.0005) // test upper limit > 0.01?
						Table.set("Trash ROI", Table.size(tp), x, tp);
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
				roiManager("save", groupdir + groupname +"seedpositions.zip");
				selectWindow(img);
				saveAs("Tiff", groupdir + groupname+"masked.tif");
			}
		//}
	}
}

// calling ordercoords() with argument 'true' runs to order seed positions
// otherwise done to order root dimensions later
function ordercoords(roots) {
	roicount = roiManager("count");
	roiarray = getSequence(roicount);
	run("Clear Results");
	run("Set Measurements...", "center display redirect=None decimal=2");
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

	sortedycoords = "Sorted Y coordinates";
	sortedxcoords = "Sorted X coordinates";
	Table.create(sortedycoords);
	Table.create(sortedxcoords);

	rowno = 0; //assume no row of seeds to start with
	col = 0 ; //current col selection is 0
	colname = "col" + col + 1;
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
	Table.save(genodir + sortedxcoords + ".tsv", sortedxcoords);
	Table.save(genodir + sortedycoords + ".tsv", sortedycoords);
	selectWindow("Seed Positions");
	run("Close");
	selectWindow(sortedxcoords + ".tsv");
	run("Close");
	selectWindow(sortedycoords + ".tsv");
	run("Close");
}

function rootStart() {
	print("Finding root starts");
	for (platefolderno = 0; platefolderno < listInrootgrowthdir.length; platefolderno ++) {  // main loop through plates
		platefolder = listInrootgrowthdir[platefolderno];
		platedir = rootgrowthdir + platefolder;
		print("Processing " + platefolder);
		listInplatefolder = getFileList(listInplatefolder);
		for (groupfolderno = 0; listInplatefolder < listInplatefolder.length; groupfolderno ++) {
			groupfolder = listInplatefolder[listInplatefolder];
			groupname = groupfolder;
			groupdir = platedir + groupfolder;
			open(groupdir + groupname + "masked.tif");
			mask = getTitle();
			roiManager("reset");
			roiManager("open", groupdir + groupname + "seedpositions.zip");
			roicount = roiManager("count");
			roiarray = getSequence(roicount);
			run("Set Measurements...", "center redirect=None decimal=2");
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
					for(roino = 0; roino < roicount; roino ++) {
						xisp = getResult("XM", roino); //xisp is x initial seed roinoition
						yisp = getResult("YM", roino); //yisp is y initial seed position
						ytb = yisp - 0.05; //y top border
						ybb = yisp + 0.4;  //y bottom border
						Table.set("ytb", roino, ytb, yref); //y (top border) cannot be more than 0.4cm to the top of initial xm
						Table.set("ybb", roino, ybb, yref); //y (bottom border) cannot be more than yisp
						topoffset = 0.05; //needed to include a little more of the top bit from the centre of mass

						//imagej takes top+leftmost coordinate to make rois
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
					prevsliceno = sliceno - 1;

					for(roino = 0; roino < roicount; roino++) {
						rowIndex = (zprev*roicount)+roino; 
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
				for (x=0; x<roicount; x++) { //for number of rois
					roiManager("select", x);
					run("Analyze Particles...", "display clear summarize slice");

					count = Table.get("Count", Table.size("Summary of "+img)-1, "Summary of "+img);
					totalarea = Table.get("Total Area", Table.size("Summary of "+img)-1, "Summary of "+img);

					if (count == 0) { //no object detected, masking erased seed due to seed too small - copy xm/ym from previous slice
						if (z > 0) {
							// don't do this for the first slice
							rowIndex = (zprev*roicount)+x; //to reference same ROI from previous slice

							//xm, ym are coordinates for the centre of mass obtained through erosion
							xmprev = Table.get("XM", rowIndex, rsc); //xm of prev slice
							ymprev = Table.get("YM", rowIndex, rsc); //ym of prev slice
							nr = Table.size(rsc);
							Table.set("Slice", nr, z+1, rsc);
							Table.set("ROI", nr, x+1, rsc);
							Table.set("XM", nr, xmprev, rsc); //set xm as previous slice
							Table.set("YM", nr, ymprev, rsc); //ym as previous slice
						}
					} else { //object detected, erode then analyse particles for xm/ym
						erosionround = 1;
						while (totalarea>0.002 && erosionround < 15) {
							//if erosion is not working due to bad thresholding, total area never decreases, rsc is copied from previous slice.
							roiManager("select", x);
							run("Options...", "iterations=1 count=1 do=Erode");
							roiManager("select", x);
							run("Analyze Particles...", "display summarize slice");

							count = Table.get("Count", Table.size-1, "Summary of "+img);
							if (count == 0) { //erode went too far, particle disappeared
								totalarea = 0; //to get out of the while loop
							} else {
								totalarea = Table.get("Total Area", Table.size-1, "Summary of "+img);
							}
							erosionround += 1;
						}

						if (erosionround < 15) {
							while (totalarea > 0.012) {
								roiManager("select", x);
								run("Options...", "iterations=1 count=3 do=Erode");
								roiManager("select", x);
								run("Analyze Particles...", "display clear summarize slice");
				
								count = Table.get("Count", Table.size-1, "Summary of "+img);
								if (count == 0) { //erode went too far, particle disappeared
									totalarea = 0; //to get out of the while loop
								} else {
									totalarea = Table.get("Total Area", Table.size-1, "Summary of "+img);
								}
							}
				
							if (count > 1) {
								area = newArray(count);
								for (v=0; v<count; v++){
									area[v] = getResult("Area", nResults-(v+1));
								}
								areaasc = Array.rankPositions(area);
								areadesc = Array.invert(areaasc);
								maxarea = areadesc[0];

								xm = getResult("XM", nResults-(maxarea+1));
								ym = getResult("YM", nResults-(maxarea+1));
							} else {
								xm = getResult("XM", nResults-1);
								ym = getResult("YM", nResults-1);
							}

							toUnscaled(xm, ym);

							nr = Table.size(rsc);
							Table.set("Slice", nr, z+1, rsc);
							Table.set("ROI", nr, x+1, rsc);
							Table.set("XM", nr, xm, rsc);
							Table.set("YM", nr, ym, rsc);
						}

						if (erosionround == 15) {
							rowIndex = (zprev*roicount)+x; //to reference same ROI from previous slice
							//xm, ym are coordinates for the centre of mass obtained through erosion
							xmprev = Table.get("XM", rowIndex, rsc); //xm of prev slice
							ymprev = Table.get("YM", rowIndex, rsc); //ym of prev slice

							nr = Table.size(rsc);
							Table.set("Slice", nr, z+1, rsc);
							Table.set("ROI", nr, x+1, rsc);
							Table.set("XM", nr, xmprev, rsc); //set xm as previous slice
							Table.set("YM", nr, ymprev, rsc); //ym as previous slice
						}
					}
				}
			}
			close(yref);
			close("Results");
			close("Summary of "+img);
			close(img);
			open(genodir+genoname+".tif");
			roiManager("reset");

			nr = Table.size(rsc);
			for (x=0; x<nr; x++) {
				xm = Table.get("XM", x, rsc);
				ym = Table.get("YM", x, rsc);
				slice = Table.get("Slice", x, rsc);
				roino = Table.get("ROI", x, rsc);

				setSlice(slice);
				makePoint(xm, ym);
				roiManager("add");
				roiManager("select", x);
				roiManager("rename", roino);
			}

			roiManager("save", genodir+genoname+"rootstartrois.zip");
			roiManager("Associate", "true");
			roiManager("Centered", "false");
			roiManager("UseNames", "true");
			roiManager("Show All with labels");
			run("Labels...", "color=white font=18 show use draw");
			run("Flatten", "stack");

			saveAs("Tiff", genodir+genoname+"_"+"rootstartlabelled.tif");
			close();
			selectWindow(rsc);
			rsctsv = genoname+"_"+rsc+".tsv";
			saveAs("Results", genodir+rsctsv);
			close(rsc);
}

