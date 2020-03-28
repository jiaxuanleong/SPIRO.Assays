/*
 * GLOBAL VARIABLES
 * ================
 */

var maindir;	// main directory
var resultsdir;	// results subdir of main directory
var ppdir;		// preprocessing subdir
var curplate;	// number of current plate being processed
var step;

// alternate types of macro run
var DEBUG = false; // hold down spacebar during macro start to keep non-essential intermediate output files
var freshstart = false; // hold down shift key during macro start to delete all previous data

print("Welcome to the companion macro of SPIRO for germination analysis!");
selectWindow("Log");

if (isKeyDown("shift"))
	freshstart = getBoolean("SHIFT key pressed. Run macro in Fresh Start mode? This will delete all data from the previous run.");

showMessage("Please locate and open your experiment folder containing preprocessed data.");
maindir = getDirectory("Choose a Directory");
resultsdir = maindir + "Results" + File.separator; // all output is contained here
ppdir = resultsdir + "Preprocessing" + File.separator; // output from the proprocessing macro is here
germdir = resultsdir + "Germination" + File.separator; // output from this macro will be here

if (!File.isDirectory(germdir))
	File.makeDirectory(germdir);
	
listInppdir = getFileList(ppdir);
listIngermdir = getFileList(germdir);

if (!is("Batch Mode"))
	setBatchMode(true);

if (freshstart)
deleteOutput();

cropGroups();
seedAnalysis();
print("Germination analysis is complete.");
selectWindow("Log");

// prompts user to make a substack, to make data size smaller by excluding time after seed germination etc.
// then prompts user to draw ROIs around groups of seeds to be analyzed
function cropGroups() {
	print("Step 1/2. Creating selected groups");
			
	for (ppdirno = 0; ppdirno < listInppdir.length; ppdirno ++) {  // main loop through plates
		if (indexOf (listInppdir[ppdirno], "preprocessed") >= 0) { // to avoid processing any random files in the folder
			platefile = listInppdir [ppdirno];
			fnsplit = split(platefile, "_");
			platename = fnsplit[0];
			platefolder = germdir + File.separator + platename + File.separator;
			if (!File.isDirectory(platefolder))
				File.makeDirectory(platefolder);
			print("Processing " + platename);
			if (is("Batch Mode"))
				setBatchMode(false); // has to be false for ROI Manager to open, and to display image
	
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
					Dialog.addCheckbox("All groups have been added to and labelled in ROI Manager.", false);
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

function seedAnalysis() {
	print("Step 2/2 Tracking germination...");
	if (is("Batch Mode"))
		setBatchMode(false);
	listIngermdir = getFileList(germdir);
	for (platefolderno = 0; platefolderno < listIngermdir.length; platefolderno ++) {  // main loop through plates
		platefolder = listIngermdir[platefolderno];
		if (indexOf(platefolder, "plate") >= 0) { // to avoid processing any random files in the folder
			platedir = germdir + platefolder;
			pfsplit = split(platefolder, "/");
			platename = pfsplit[0];
			print("Processing " + platename);
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
						groupname = substring(filename, indexofgroup + 6); // to find out group name, +6 because of the letters and a space
					}
				}
				img = getTitle();
				// masking and thresholding of seeds
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
				roiarray = Array.getSequence(roicount);

				// order the coordinates
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
						run("Enlarge...", "enlarge=0.1");
						roiManager("add");
						roiManager("select", roiManager("count")-1);
						roiManager("rename", roiManager("count"));
						}
					}
				}
	
				selectWindow(seedpositions);
				run("Close");
				selectWindow(sortedxcoords);
				run("Close");
				selectWindow(sortedycoords);
				run("Close");

				run("Set Measurements...", "area perimeter stack display redirect=None decimal=5");
				run("Clear Results");
	
				for (roino = 0; roino < roicount; roino ++) {
					roiManager("select", roino);
					run("Analyze Particles...", "size=0-Infinity show=Nothing display stack");
				}

				selectWindow("Results");
				Table.save(groupdir + groupname + " germination analysis.tsv");
				selectWindow("Results");
				run("Close");
	
				roiManager("Associate", "false");
				roiManager("Centered", "false");
				roiManager("UseNames", "false");
				roiManager("Show All with labels");
				run("Labels...", "color=white font=18 show use draw");
				run("Flatten", "stack");
				
				slicelabelarray = newArray(nS);
				for (sliceno = 0; sliceno < nS; sliceno++) {
					setSlice(sliceno+1);
					slicelabel = getMetadata("Label");
					slicelabelarray[sliceno] = slicelabel;
				}

				selectWindow(img);
				rename(img + "mask");
				imgmask = getTitle();
				
				open(groupdir + "Group " + groupname + ".tif");
				oriimg = getTitle();
				run("RGB Color");
				
				//Determine the cropped frame proportions to orient combining stacks horizontally or vertically
				xmax = getWidth;
				ymax = getHeight;
				frameproportions=xmax/ymax; 
				
				if (frameproportions > 1) {
				run("Combine...", "stack1=["+ img +"] stack2=["+ imgmask +"] combine");
				} else {
					run("Combine...", "stack1=["+ img +"] stack2=["+ imgmask +"]");
				}

				for (sliceno = 0; sliceno < nS; sliceno++) {
					setSlice(sliceno+1);
					setMetadata("Label", slicelabelarray[sliceno]);
				}
				saveAs("Tiff", groupdir + groupname + " germinationlabelled.tif");

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
}

function deleteOutput() {
	print("Starting analysis from beginning. \nRemoving output from previous run.");
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
				listIngroupdir = getFileList(groupdir);
				for (outputfileno = 0; outputfileno < listIngroupdir.length; outputfileno ++) {
					if (indexOf(listIngroupdir[outputfileno], "Group") >= 0) {
						open(groupdir + listIngroupdir[outputfileno]);
						filename = File.nameWithoutExtension;
						indexofgroup = indexOf(filename, "Group");
						groupname = substring(filename, indexofgroup + 6); // to find out group name, +6 because of the letters and a space
						close(listIngroupdir[outputfileno]);
					}
				}

				File.delete(groupdir + groupname + ".tif");
				File.delete(groupdir + groupname + " germination analysis.tsv");
			}
		}
	}
}