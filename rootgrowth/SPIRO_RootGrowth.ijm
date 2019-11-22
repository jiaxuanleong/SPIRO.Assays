//requirements for file organization
//main directory containing all images sorted by plate into subdirectories
//requirements for image naming
//plate1-date20190101-time000000-day

/*
 * GLOBAL VARIABLES
 * ================
 */

var maindir;	// main directory
var resultsdir;	// results subdir of main directory
var ppdir;		// preprocessing subdir
var curplate;	// number of current plate being processed

var DEBUG = true; // set this to true to enable debugging features

// table names
var ra = "Root analysis";
var bi = "Branch information";

//user selection of main directory
showMessage("Please locate and open your experiment folder containing preprocessed data.");
maindir = getDirectory("Choose a Directory");
resultsdir = maindir + "/Results/";
ppdir = resultsdir + "/Preprocessing/";

ppdirlist = getFileList(ppdir);
for (a=0; a<ppdirlist.length; a++) {
	if (indexOf(ppdirlist[a], "plate") < 0)
		ppdirlist = Array.deleteValue(ppdirlist,
									  ppdirlist[a]); //makes sure any non-plate folder isnt processed
}

// set up temporary directory
if (!File.isDirectory(resultsdir + "/Temp"))
	File.makeDirectory(resultsdir + "/Temp");
tmp = getFileList(resultsdir + "/Temp");
tmpdir = resultsdir + "/Temp/" + tmp.length+1 + "/";
File.makeDirectory(tmpdir);

/* recursive file delete functions
 *  we use this to clean out an old Root growth analysis folder before replacing it with
 *  the new one.
 */

// to ensure we don't get stuck, only venture a few levels deep
var depth = 0;

// during file deletion, add encountered directories to this global variable
var dirs = newArray();

// this function recursively processes a directory, deleting the files it encounters
// directories are saved into a global var "dirs" for subsequent removal
function removeFilesRecursively(dir) {
	dirs = Array.concat(dirs, dir);
	depth += 1;
	files = getFileList(dir);
	files = Array.sort(files);
	for (i = 0; i < files.length; i++) {
		if (depth < 5) {
			if (File.isDirectory(dir + "/" + files[i])) {
				removeFilesRecursively(dir + "/" + files[i]);
			} else {
				ok = File.delete(dir + "/" + files[i]);
			}
		}
	}
	depth -= 1;
}

/* remove directories
 * also deletes .DS_Store files in these dirs
 * N.B.! if there are other hidden files (i.e., filenames starting with "."), this function will fail
 * N.B.! if multiple folders are to be processed, clear the "dirs" variable between calls
 *
 */
function removeDirs(dirs) {
	for (i = dirs.length-1; i >= 0; i--) {
		if (File.exists(dirs[i] + "/.DS_Store"))
			ok = File.delete(dirs[i] + "/.DS_Store");
		ok = File.delete(dirs[i]);
	}
	if (File.exists(dirs[0])) {
		// we failed to remove the dir
		return(0);
	} else {
		return(1);
	}
}

processMain1();
processMain2();
processMain21();
processMain3();
moveResults();

print("Macro finished.");

// close all windows unless we are in debug mode
if (!DEBUG) {
	list = getList("window.titles");
	for (i=0; i<list.length; i++) {
		winame = list[i];
		selectWindow(winame);
		run("Close");
	}
}

//PART1 crop groups/genotypes per plate
curplate = 0;

function processMain1() {
	for (i=0; i<ppdirlist.length; i++) {
		curplate = i;
		platefile = ppdirlist[i];
		fnsplit = split(platefile, "_");
		platename = fnsplit[0];
		cropGroup();
	}
}

//PART2 find seed positions per group per plate
function processMain2() {
	for (i=0; i<ppdirlist.length; i++) {
		platefile = ppdirlist [i];
		fnsplit = split(platefile, "_");
		platename = fnsplit[0];
		processSub2(); 	
	}
}

function processSub2() {
	rootgrowthsubdir = tmpdir + "/" + platename + "/";
	croplist = getFileList(rootgrowthsubdir);
	seedPosition();
}

//PART2.1 find root start coordinates per group per plate
function processMain21() {
	for (i=0; i<ppdirlist.length; i++) {
		platefile = ppdirlist [i];
		fnsplit = split(platefile, "_");
		platename = fnsplit[0];
		processSub21();
	}
}

function processSub21() {
	rootgrowthsubdir = tmpdir + "/" + platename + "/";
	croplist = getFileList(rootgrowthsubdir);
	
	rootStart();
}


//PART3 skeleton analysis per group per plate
function processMain3() {
	for (i=0; i<ppdirlist.length; i++) {
		platefile = ppdirlist [i];
		fnsplit = split(platefile, "_");
		platename = fnsplit[0];
		print("Getting root measurements of "+platename);
		processSub3();
	}
}

function processSub3() {
	rootgrowthsubdir = tmpdir + "/" + platename + "/";
	croplist = getFileList(rootgrowthsubdir);
	rootlength();
};

//PART1 crop genotypes/group
function cropGroup() {
	rootgrowthsubdir = tmpdir + "/" + platename + "/";
	if (!File.isDirectory(rootgrowthsubdir)) {
		File.makeDirectory(rootgrowthsubdir);
	}
	croplist = getFileList(rootgrowthsubdir);
	setBatchMode(false);
	open(ppdir+platename+"_preprocessed.tif");
	reg = getTitle();
	waitForUser("Create substack",
				"Please note first and last slice to be included for root length analysis, and indicate it in the next step.");
	run("Make Substack...");
	saveAs("Tiff", rootgrowthsubdir+platename+"_rootlengthsubstack.tif");
	close(reg);
	print("Cropping genotypes/groups in "+platename);
	run("ROI Manager...");
	setTool("Rectangle");
	if (curplate == 0) {
		waitForUser("Select each group, and add to ROI manager. ROI names will be saved.\n" +
					"Please do not use dashes in the ROI names. \n" +
					"ROIs cannot share names.");
	}
	if (curplate > 0)
		waitForUser("Modify ROI and names if needed.");

	while (roiManager("count") <= 0) {
		waitForUser("Select each group, and add to ROI manager. ROI names will be saved.\n" +
					"Please do not use dashes in the ROI names.\n" +
					"ROIs cannot share names.");
	}

	run("Select None");
	setBatchMode(true);
	
	//loop enables cropping of ROI(s) followed by saving of cropped stacks
	//roi names cannot contain dashes due to split() to extract information from file name later on
	roicount = roiManager("count");
	for (x=0; x<roicount; ++x) {
		roiManager("Select", x);
		roiname = Roi.getName;
		while (indexOf(roiname, "-") > 0) {
			waitForUser("ROI names cannot contain dashes '-'! Please modify the name, then click OK.");
			roiManager("Select", x);
			roiname = Roi.getName;
		}
		genodir = rootgrowthsubdir + "/"+roiname+"/";
		File.makeDirectory(genodir);
		print("Cropping group "+x+1+"/"+roicount+" "+roiname+"...");

		roitype = Roi.getType;
		if (roitype != "rectangle") {
			run("Duplicate...", "duplicate");
			run("Make Inverse");
			run("Clear", "stack");
		} else {
			run("Duplicate...", "duplicate");
		}
    	saveAs("Tiff", genodir+roiname+".tif");
    	close();
	}
	close();
}


//PART2 finds seed position and saves ROI - looped through crops immediately for user friendliness
function seedPosition() {
	for (y = 0; y < croplist.length; ++y) { //-1 for substack file
		if (indexOf(croplist[y], "substack")<0) {
			setBatchMode(false);
			genodir = rootgrowthsubdir+"/"+croplist[y]+"/";
			genoname = File.getName(genodir);
			print("Finding seed positions for "+platename+genoname);
			open(genodir+genoname+".tif");
			img = getTitle();
			firstMask();
			roiManager("reset");
			run("Create Selection");
			run("Colors...", "foreground=black background=black selection=red");

			roiManager("Add");
			roiManager("select", 0);
			roiManager("split");
			roiManager("select", 0);
			roiManager("delete");
		
			//to delete all trash ROI
			roiarray = newArray(roiManager("count"));
			for (x = 0; x<roiManager("count"); x++) {
				roiarray[x] = x;
			}
			run("Set Measurements...", "area redirect=None decimal=5");
			roiManager("select", roiarray);
			roiManager("multi-measure");
			roiManager("deselect");
			tp = "Trash positions";
			Table.create(tp);
			selectWindow("Results");

			for (x=0; x<nResults; x++) {
				selectWindow("Results");
				area = getResult("Area", x);
				//if (area<0.0008 || area>0.01) upper limit doesnt work properly
				if (area<0.0005) {
					Table.set("Trash ROI", Table.size(tp), x, tp);
				}
			}

			if (Table.size(tp)>0) {
				trasharray = Table.getColumn("Trash ROI", tp);
				roiManager("select", trasharray);
				roiManager("delete");
				roiarray = newArray(roiManager("count"));
			}
			close("Trash positions");

			//numbers remaining ROI
			for(x=0; x<roiManager("count"); x++){
				roiManager("select", x);
				roiManager("rename", x+1);
			}

			Roi.setStrokeWidth(2);
			waitForUser("Please delete any ROIs that should not be included into analysis, \n" +
						"e.g. noise selection and seedlings that have overlapping roots");

			roiarray = newArray(roiManager("count"));
			for(x=0; x<roiManager("count"); x++){
				roiManager("select", x);
				roiManager("rename", x+1);
				roiarray[x] = x;
			}

			roiManager("select", roiarray);
			run("Set Measurements...", "area redirect=None decimal=5");
			roiManager("multi-measure");
			seedlingsdetected = 0;

			for (x=0; x<nResults; x++){
				area = getResult("Area", x);
				if (area>0.02)
					seedlingsdetected = seedlingsdetected + 1;
			}

			if (seedlingsdetected > 0) {
				if (getBoolean("Seedlings detected on first slice. Proceed with ROI selection of root start?"))
					seedlinginitial();
			} else {
				ordercoords();
				roiManager("save", genodir+genoname+"seedpositions.zip");
				roiManager("reset");
				selectWindow(img);
				saveAs("Tiff", genodir+genoname+"masked.tif");
				close();
			}
		}
	}
}

function ordercoords () {
	roiarray = newArray(roiManager("count"));
	for(x=0; x<roiManager("count"); x++){
		roiarray[x]=x;
	}
	run("Clear Results");
	run("Set Measurements...", "center display redirect=None decimal=5");
	roiManager("select", roiarray);
	roiManager("multi-measure");
	seedpositions = ("Seed Positions");
	Table.rename("Results", seedpositions);
	roicount = Table.size(seedpositions);

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
	
	for (arrayindex = 1; arrayindex < roicount; arrayindex++) {
		ydiff = ymseeds[ymascendingindexes[arrayindex]] - ymseeds[ymascendingindexes[arrayindex-1]];
		if (ydiff > 1) {
			rowno = rowno + 1;
			col = 0;
		} else {
			col = col + 1;
		}
		colname = "col" + col + 1;
		Table.set(colname, rowno, ymseeds[ymascendingindexes[arrayindex]], sortedycoords);
		Table.set(colname, rowno, xmseeds[ymascendingindexes[arrayindex]], sortedxcoords);
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
			toUnscaled(xm, ym);
			makePoint(xm, ym);
			roiManager("add");
			roiManager("select", roiManager("count")-1);
			roiManager("rename", roiManager("count"));
		}
	}

	Table.save(genodir + sortedxcoords + ".csv", sortedxcoords);
	Table.save(genodir + sortedycoords + ".csv", sortedycoords);
	close(sortedxcoords);
	close(sortedycoords);
}

//PART2 creates a binary mask for seed/lings and reduces noise
function firstMask() {
	run("8-bit");
	//run("Subtract Background...", "rolling=30 stack");
	run("Enhance Contrast...", "saturated=0.2 normalize process_all");
	run("Median...", "radius=1 stack");
	setAutoThreshold("MaxEntropy dark");
	run("Convert to Mask", "method=MaxEntropy background=Dark calculate");
	run("Options...", "iterations=1 count=4 do=Dilate stack");
	run("Remove Outliers...", "radius=3 threshold=50 which=Dark stack");
	run("Remove Outliers...", "radius=5 threshold=50 which=Dark stack");
}

function seedlinginitial() {  //if seedlings instead of seeds are detected on first slice
	roiManager("reset");
	waitForUser("Please draw ROI encompassing all root starts, then add to ROI Manager.");
	while (roiManager("count") <= 0) {
		waitForUser("Please draw ROI encompassing all root starts, then add to ROI Manager.");
	}

	roiManager("select", 0);
	getBoundingRect(boundingx, boundingy, width, height);
	run("Duplicate...", "use");
	rootstartroi = getTitle();
	roiManager("reset");
	run("Create Selection");
	run("Colors...", "foreground=black background=black selection=red");
				
	roiManager("Add");
	roiManager("select", 0);
	roiManager("split");
	roiManager("select", 0);
	roiManager("delete");

	//to delete all trash ROI
	roiarray = newArray(roiManager("count"));
	for (x = 0; x<roiManager("count"); x++) {
		roiarray[x]=x;
	}

	run("Set Measurements...", "area redirect=None decimal=5");
	roiManager("select", roiarray);
	roiManager("multi-measure");
	roiManager("deselect");

	tp = "Trash positions";
	Table.create(tp);
	selectWindow("Results");

	for (x=0; x<nResults; x++) {
		selectWindow("Results");
		area = getResult("Area", x);
		if (area<0.0012) {
			Table.set("Trash ROI", Table.size(tp), x, tp);
		}
	}

	if (Table.size(tp)>0) {
		trasharray = Table.getColumn("Trash ROI", tp);
		roiManager("select", trasharray);
		roiManager("delete");
		roiarray = newArray(roiManager("count"));
	}
	close("Trash positions");

	//numbers remaining ROI
	for(x=0; x<roiManager("count"); x++){
		roiManager("select", x);
		roiManager("rename", x+1);
	}

 	Roi.setStrokeWidth(2);
	waitForUser("Please delete any ROIs that should not be included into analysis, \n" +
				"e.g. noise selection and seedlings that have overlapping roots");

	roicount = roiManager("count");
	for(x=0; x<roicount; x++){
		roiManager("select", x);
		Roi.getBounds(groupx, groupy, groupw, grouph);
		selectWindow(img);
		makeRectangle(boundingx+groupx, boundingy+groupy, groupw, grouph);
		roiManager("add");
		roiManager("rename", x+1);
	}
	close(rootstartroi);

	ordercoords();

	roiManager("save", genodir+genoname+"initialpositions.zip");
	roiManager("reset");
	selectWindow(img);
	saveAs("Tiff", genodir+genoname+"masked.tif");
	close();
}


//PART2.1 finds root start coordinates per genotype/group
function rootStart() {
	for (y = 0; y < croplist.length; ++y) {
		if (indexOf(croplist[y], "substack")<0) {
			setBatchMode(false);
			genodir = rootgrowthsubdir+"/"+croplist[y]+"/";
			genoname = File.getName(genodir);
			print("Finding root start coordinates for "+platename+genoname);
			open(genodir+genoname+"masked.tif");
			img = getTitle();
			roiManager("reset");
			if (File.exists(genodir+genoname+"seedpositions.zip")) {
				roiManager("open", genodir+genoname+"seedpositions.zip");
			} else {
				roiManager("open", genodir+genoname+"initialpositions.zip");
			}

			roiarray = newArray(roiManager("count"));
			for(x=0; x<roiManager("count"); x++){
				roiarray[x]=x;
			}

			run("Set Measurements...", "centre redirect=None decimal=5");
			run("Clear Results");
			roiManager("select", roiarray);
			roiManager("multi-measure");
			roicount = roiManager("count");

			scaledwroi = 0.12; //width of ROI for finding root start coordinates is 0.12cm
			scaledhroi = 0.18; //height of ROI is 0.18cm
			unscaledwroi = 0.12;
			unscaledhroi = 0.18;
			toUnscaled(unscaledwroi, unscaledhroi);

			nS = nSlices;
			rsc = "Root start coordinates";
			Table.create(rsc);

			for (z=0; z<nS; z++) { //for each slice
				setSlice(z+1); //starting with first slice
				if (z==0) { //if first slice, obtain XY coordinates from Results to make ROI
					roiManager("reset");
					yref = "YRef";
					Table.create(yref);  //table for "y references" which contain the top and bottom borders

					//the borders are setting the top/bottom limits within which the roi can be positioned to prevent rsc
					// from jumping to hypocotyls or sliding down roots
					for(pos = 0; pos < roicount; pos ++) {
						xisp = getResult("X", pos); //xisp is x initial seed position
						yisp = getResult("Y", pos); //yisp is y initial seed position
						ytb = yisp - 0.05; //y top border
						ybb = yisp + 0.4;  //y bottom border
						Table.set("ytb", pos, ytb, yref); //y (top border) cannot be more than 0.4cm to the top of initial xm
						Table.set("ybb", pos, ybb, yref); //y (bottom border) cannot be more than yisp
						topoffset = 0.05; //needed to include a little more of the top bit from the centre of mass

						//imagej takes top+leftmost coordinate to make rois
						yroi = yisp - topoffset; //yroi is top+leftmost ycoordinate of roi
						xroi = xisp - 0.5*scaledwroi; //xroi is top+leftmost xcoordinate of roi
						toUnscaled(xroi, yroi);
						makeRectangle(xroi, yroi, unscaledwroi, unscaledhroi);
						roiManager("add");
						Table.save(genodir + "yref.tsv", yref);
					}
				} else {
					//for subsequent slices, obtain XY centre of mass coordinates from rsc
					//of previous slice
					roiManager("reset");
					zprev = z-1;

					for(pos = 0; pos < roicount; pos++) {
						rowIndex = (zprev*roicount)+pos; //to reference same ROI from previous slice

						//xm, ym are coordinates for the centre of mass obtained through erosion
						xmprev = Table.get("XM", rowIndex, rsc); //xm of prev slice
						ymprev = Table.get("YM", rowIndex, rsc);  //ym of prev slice
						toScaled(xmprev, ymprev);
						ytb = Table.get("ytb", pos, yref);
						ybb = Table.get("ybb", pos, yref);
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
			close(rsctsv);
			if (!DEBUG) {
				ok = File.delete(genodir+genoname+"masked.tif");
				ok = File.delete(genodir+yref+".tsv");
			}
		}
	}
}


//PART3 skeleton analysis per group
function rootlength() {
	for (y = 0; y < croplist.length; ++y) {
		if (indexOf(croplist[y], "substack") < 0) {
			setBatchMode(false);
			genodir = rootgrowthsubdir+"/"+croplist[y]+"/";	
			genoname = File.getName(genodir);
			print("Analyzing root growth of "+platename+genoname);
			open(genodir+genoname+".tif");
			stack1 = getTitle();
					
			//process roots for skeletonization
			secondMask();
			overlayskeletons();

			setBatchMode(true);
			open(genodir+genoname+" overlaidskeletons.tif");
			roiManager("Associate", "true");
			stack1 = getTitle();
			rsc = "Root start coordinates";
			rsctsv = genoname+"_"+rsc+".tsv";
			open(genodir+rsctsv);
			
			nr = Table.size(rsctsv);
			roicount = nr/nSlices;
			roiManager("reset");
			
			sortedxcoords = "Sorted X Coordinates";
			sortedxcoordscsv = sortedxcoords + ".csv";
			open(genodir + sortedxcoordscsv);
			colnames = Table.headings(sortedxcoordscsv);
			colnamessplit = split(colnames, "	");
			colno = lengthOf(colnamessplit);

			if (colno > 1) {
				xfirstcol = Table.get("col1", 0, sortedxcoordscsv);
				xsecondcol = Table.get("col2", 0, sortedxcoordscsv);
				xdiff = xsecondcol - xfirstcol;
				roiwidth = 3*xdiff;
			} else {
				xfirstcol = Table.get("col1", 0, sortedxcoordscsv);
				roiwidth = getWidth(stack1); //ARBITRARY VALUE, TO DETERMINE
			}
			close(sortedxcoordscsv);

			sortedycoords = "Sorted Y Coordinates";
			sortedycoordscsv = sortedycoords + ".csv";
			open(genodir + sortedycoordscsv);
			rowno = Table.size - 1;

			if (rowno > 1) {
				yfirstrow = Table.get("col1", 0, sortedycoordscsv);
				ysecondrow = Table.get("col1", 1, sortedycoordscsv);
				ydiff = ysecondrow - yfirstrow;
				roiheight = ydiff - 0.5;
			} else {
				yfirstrow = Table.get("col1", 0, sortedycoordscsv);
				roiheight = getHeight() - yfirstrow;
			}

			toUnscaled(roiwidth, roiheight);
			dummy = 1;
			toUnscaled(xdiff, dummy);

			groupwidth = getWidth();
			
			for (x=0; x<nr; x++) {
				slice = Table.get("Slice", x, rsctsv);
				roino = Table.get("ROI", x, rsctsv);
				xm = Table.get("XM", x, rsctsv);
				ym = Table.get("YM", x, rsctsv);
				setSlice(slice);
				roiytopleft = ym;
				roixtopleft = xm - (0.5*roiwidth);
				makeRectangle(roixtopleft, roiytopleft, roiwidth, roiheight);
				roiManager("add");
				roiManager("select", x);
				roiManager("rename", roino);
			}
			
			for (x=0; x<nr; x++) {
				selectWindow(stack1);
				roiManager("select", x);
				roino = parseInt(Roi.getName);
				sliceno = getSliceNumber();
				run("Duplicate...", "use");
				if (DEBUG) saveAs("Tiff", genodir+genoname+"_"+"crop_roi" + roino + "_slice" + sliceno + ".tif");
				temp = getTitle();
				xm = Table.get("XM", x, rsctsv);
				roixtopleft = xm - (0.5*roiwidth);
				halfx = xm - roixtopleft;

				if (xm - (0.5*roiwidth) < 0) {
					// roi overflowed to the left
					// compensate by moving midpoint to the left by half the amount of overflow
					halfx = 0.5*getWidth() - ((0.5*roiwidth - xm) / 2);
				} else if (xm + (0.5*roiwidth) > groupwidth) {
					// roi overflows to the right
					halfx = 0.5*getWidth() + ((xm + 0.5*roiwidth) - groupwidth) / 2;
				}

				fully = getHeight();
				run("Set Measurements...", "display redirect=None decimal=3");
				run("Analyze Skeleton (2D/3D)", "prune=none show");
				close("Tagged skeleton");
				close(temp);
				close("Results");

				if (x==0) {
					Table.create(ra);
				}

				for (z=0; z<Table.size(bi); z++) {
					rar = Table.size(ra);
					Table.set("Slice name", rar, temp, ra);
					Table.set("Slice no.", rar, sliceno, ra);
					Table.set("ROI", rar, roino, ra);
					id = Table.get("Skeleton ID", z, bi);
					Table.set("Skeleton ID", rar, id, ra);
					bl = Table.get("Branch length", z, bi);
					Table.set("Branch length", rar, bl, ra);
					v1x = Table.get("V1 x", z, bi);
					v1y = Table.get("V1 y", z, bi);
					v2x = Table.get("V2 x", z, bi);
					v2y = Table.get("V2 y", z, bi);
					toUnscaled(v1x, v1y);
					toUnscaled(v2x, v2y);
					Table.set("V1 x", rar, v1x, ra);
					Table.set("V1 y", rar, v1y, ra);
					Table.set("V2 x", rar, v2x, ra);
					Table.set("V2 y", rar, v2y, ra);
					Table.set("ROI mid X", rar, halfx, ra);
					Table.set("ROI full Y", rar, fully, ra);
				}
			}

			close(bi);
			Table.save(genodir+platename+" "+genoname+" root analysis.tsv", ra);
			tableraname = platename+" "+genoname+" root analysis.tsv";
			close(tableraname);
			close(rsctsv);

			selectWindow(stack1);
			roiManager("reset");
			roiManager("open", genodir+genoname+"rootstartrois.zip");
			roiManager("Associate", "true");
			roiManager("Centered", "false");
			roiManager("UseNames", "true");
			roiManager("Show All with labels");
			run("Labels...", "color=white font=18 show use draw");
			run("Flatten", "stack");

			saveAs("Tiff", genodir+genoname+"_"+"skeletonized.tif");
			stack1 = getTitle();
			nS = nSlices;
			//Determine the cropped frame proportions to orient combining stacks horizontally or vertically
			xmax = getWidth;
			ymax = getHeight;
			frameproportions = xmax/ymax;

			//Add label to each slice (time point). The window width for label is determined by frame proportions
			for (x = 0; x < nS; x++) {
				selectWindow(stack1);
				setSlice(x+1);
				slicelabel = getMetadata("Label");

				if (frameproportions >= 1) {  //if horizontal
					newImage("Slice label", "RGB Color", xmax, 50, 1);
				} else {
					newImage("Slice label", "RGB Color", 2*xmax, 50, 1);
				}

				setFont("SansSerif", 20, " antialiased");
				makeText(slicelabel, 0, 0);
				setForegroundColor(0, 0, 0);
				run("Draw", "slice");
				selectWindow(stack1);
				run("Next Slice [>]");
			}

			//Combine the cropped photos and binary masks with labels into one time-lapse stack. Combine vertically or horizontally depending on the frame proportions
			run("Images to Stack");
			label = getTitle();
			open(genodir+genoname+"_"+"rootstartlabelled.tif");
			rsl = getTitle();

			if (frameproportions >= 1) {
				run("Combine...", "stack1=["+rsl+"] stack2=["+stack1+"] combine");
				run("Combine...", "stack1=[Combined Stacks] stack2=["+label+"] combine");
			}  else {
				run("Combine...", "stack1=["+rsl+"] stack2=["+stack1+"]");
				run("Combine...", "stack1=[Combined Stacks] stack2=["+label+"] combine");
			}

			saveAs("Tiff", genodir+platename+"_"+genoname+"_rootgrowth.tif");
			close();

			//Delete temporary files used for analysis
			if (!DEBUG) {
				ok = File.delete(genodir+genoname+"seedpositions.zip");
				ok = File.delete(genodir+genoname+"initialpositions.zip");
				ok = File.delete(genodir+genoname+"_"+"rootstartlabelled.tif");
				ok = File.delete(genodir+genoname+"_"+"skeletonized.tif");
				ok = File.delete(genodir+genoname+"rootstartrois.zip");
				ok = File.delete(genodir+genoname+" overlaidskeletons.tif");
				ok = File.delete(genodir+rsctsv);
				ok = File.delete(genodir+sortedxcoordscsv);
				ok = File.delete(genodir+sortedycoordscsv);
			}
		}
	}
}

//PART3 creates a binary mask for roots and reduces noise
function secondMask() {
	run("8-bit");
	run("Subtract Background...", "rolling=15 stack");
	run("Enhance Contrast...", "saturated=0.2 normalize process_all");
	setAutoThreshold("MaxEntropy dark");
	setOption("BlackBackground", false);
	run("Convert to Mask", "method=MaxEntropy background=Dark calculate");
	run("Options...", "iterations=1 count=1 pad do=Dilate stack");
	run("Remove Outliers...", "radius=2 threshold=1 which=Dark stack");
	run("Options...", "iterations=3 count=1 pad do=Close stack");
	run("Remove Outliers...", "radius=4 threshold=1 which=Dark stack");
	run("Remove Outliers...", "radius=4 threshold=1 which=Dark stack");
	run("Options...", "iterations=1 count=1 pad do=Skeletonize stack");
}

function overlayskeletons() {
	roiManager("Associate", "false");
	run("Colors...", "foreground=black background=black selection=black");
	stack1 = getTitle();
	setSlice(1);
	slicelabel = getInfo("slice.label");
	run("Duplicate...", "use");
	//run("8-bit");
	//run("Make Binary");
	//run("Skeletonize");
	rename(slicelabel);
	selectWindow(stack1);
	nS = nSlices();
	roiManager("reset");
	for (sliceno = 1; sliceno < nS; sliceno++) {
		//roiManager("reset");
		selectWindow(stack1);
		setSlice(sliceno);
		run("Create Selection");
		roiManager("add");
		setSlice(sliceno + 1);
		slicelabel = getInfo("slice.label");
		
		roiarray = newArray(roiManager("count"));
		for(x=0; x<roiManager("count"); x++){
			roiarray[x]=x;
		}

		roiManager("select", roiarray);
		roiManager("Show All without labels");
		run("Flatten", "slice");
		rename(slicelabel);
		run("Make Binary");
		run("8-bit");
		//run("Erode");
		//run("Skeletonize");	
	}

	close(stack1);

	run("Images to Stack");
	run("Options...", "iterations=2 count=1 pad do=Dilate stack");
	run("Options...", "iterations=1 count=1 pad do=Skeletonize stack");
	saveAs("Tiff", genodir+genoname+" overlaidskeletons.tif");
	close();
	run("Colors...", "foreground=black background=black selection=red");
}

// cleanup:
// the macro succeeded; move the temp files into their proper place
function moveResults() {
	dstdir = resultsdir + "/Root growth assay/";
	removeFilesRecursively(dstdir);
	// dirs is a global variable containing the directories processed by removeFilesRecursively;
	ok = removeDirs(dirs);
	if (ok) {
		// directory removed, move files into place
		s = File.rename(tmpdir, dstdir);
	} else {
		showMessage("Failed to delete old results folder." +
					"Manually move the folder " + tmpdir +
					" to the directory " + resultsdir +
					" and rename it 'Root growth assay'.");
	}
	removeFilesRecursively(resultsdir + "/Temp");
	ok = File.delete(resultsdir + "/Temp");
}
