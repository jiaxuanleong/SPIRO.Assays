//requirements for file organization
//main directory containing all images sorted by plate into subdirectories
//requirements for image naming
//plate1-date20190101-time000000-day

//user selection of main directory
showMessage("Please locate and open your experiment folder containing preprocessed data.");
maindir = getDirectory("Choose a Directory");
resultsdir = maindir + "/Results/";
preprocessingmaindir = resultsdir + "/Preprocessing/";

preprocessingmaindirlist = getFileList(preprocessingmaindir);
for (a=0; a<preprocessingmaindirlist.length; a++) {
	if (indexOf(preprocessingmaindirlist[a], "plate") < 0)
		preprocessingmaindirlist = Array.deleteValue(preprocessingmaindirlist, preprocessingmaindirlist[a]); //makes sure any non-plate folder isnt processed
}

rootgrowthmaindir = resultsdir + "/Root growth assay/";
if (!File.isDirectory(rootgrowthmaindir)) {
	File.makeDirectory(rootgrowthmaindir);
}

processMain1();
processMain2();
processMain21();
processMain3();

list = getList("window.titles"); 
     for (i=0; i<list.length; i++){ 
     winame = list[i]; 
     selectWindow(winame); 
     run("Close"); 
     }

//PART1 crop groups/genotypes per plate
function processMain1() {
	for (i=0; i<preprocessingmaindirlist.length; i++) {
		plateanalysisno = i;
		platepreprocessedfile = preprocessingmaindirlist [i];
		preprocessedfilenameparts = split(platepreprocessedfile, "_");
		platename = preprocessedfilenameparts[0];
		cropGroup();
	}
}

//PART2 find seed positions per group per plate
function processMain2() {
	for (i=0; i<preprocessingmaindirlist.length; i++) {
		platepreprocessedfile = preprocessingmaindirlist [i];
		preprocessedfilenameparts = split(platepreprocessedfile, "_");
		platename = preprocessedfilenameparts[0];
		processSub2();	
	}
}

function processSub2() {
	rootgrowthsubdir = rootgrowthmaindir + "/" + platename + "/";	
	croplist = getFileList(rootgrowthsubdir);
	seedPosition();
}

//PART2.1 find root start coordinates per group per plate
function processMain21() {
	for (i=0; i<preprocessingmaindirlist.length; i++) {
		platepreprocessedfile = preprocessingmaindirlist [i];
		preprocessedfilenameparts = split(platepreprocessedfile, "_");
		platename = preprocessedfilenameparts[0];
		processSub21();
	}
}

function processSub21() {
	rootgrowthsubdir = rootgrowthmaindir + "/" + platename + "/";
	croplist = getFileList(rootgrowthsubdir);
	
	rootStart();
}


//PART3 skeleton analysis per group per plate
function processMain3() {
	for (i=0; i<preprocessingmaindirlist.length; i++) {
		platepreprocessedfile = preprocessingmaindirlist [i];
		preprocessedfilenameparts = split(platepreprocessedfile, "_");
		platename = preprocessedfilenameparts[0];
		print("Getting root measurements of "+platename);
		processSub3();
	}
}

function processSub3() {
	rootgrowthsubdir = rootgrowthmaindir + "/" + platename + "/";
	croplist = getFileList(rootgrowthsubdir);
	rootlength();
};

//PART1 crop genotypes/group 
function cropGroup() {
	rootgrowthsubdir = rootgrowthmaindir + "/" + platename + "/";
	if (!File.isDirectory(rootgrowthsubdir)) {
		File.makeDirectory(rootgrowthsubdir);
	}
	croplist = getFileList(rootgrowthsubdir);
	setBatchMode(false);
	open(preprocessingmaindir+platename+"_preprocessed.tif");
	reg = getTitle();
	waitForUser("Create substack", "Please note first and last slice to be included for root length analysis, and indicate it in the next step.");	
	run("Make Substack...");
	saveAs("Tiff", rootgrowthsubdir+platename+"_rootlengthsubstack.tif");
	close(reg);
	print("Cropping genotypes/groups in "+platename);
	run("ROI Manager...");
	setTool("Rectangle");
	if (plateanalysisno == 0) {
	waitForUser("Select each group, and add to ROI manager. ROI names will be saved.\n" +
		"Please do not use dashes in the ROI names. \n" +
		"ROIs cannot share names.");
	}
	if (plateanalysisno > 0)
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
		waitForUser("Please delete any ROIs that should not be included into analysis, \n e.g. noise selection and seedlings that have overlapping roots");
		roiarray = newArray(roiManager("count"));
		for(x=0; x<roiManager("count"); x++){
			roiManager("select", x);
			roiManager("rename", x+1);
			roiarray[x]=x;
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
			seedlinginitialboolean = getBoolean("Seedlings detected on first slice. Proceed with ROI selection of root start?");
			if (seedlinginitialboolean == 1) 
				seedlinginitial();
		} else {
		roiManager("save", genodir+genoname+"seedpositions.zip");
		selectWindow(img);
		saveAs("Tiff", genodir+genoname+"masked.tif");
		close();
		}
	}
	}
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

function seedlinginitial() { //if seedlings instead of seeds are detected on first slice
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
	waitForUser("Please delete any ROIs that should not be included into analysis, \n e.g. noise selection and seedlings that have overlapping roots");
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
	roiManager("save", genodir+genoname+"initialpositions.zip");
	selectWindow(img);
	saveAs("Tiff", genodir+genoname+"masked.tif");
	close();

}


//PART2.1 finds root start coordinates per genotype/group
function rootStart() {
	for (y = 0; y < croplist.length; ++y) {
		if (indexOf(croplist[y], "substack")<0) {
		setBatchMode(true);
		genodir = rootgrowthsubdir+"/"+croplist[y]+"/";	
		genoname = File.getName(genodir);
		print("Finding root start coordinates for "+platename+genoname);
		open(genodir+genoname+"masked.tif");
		img = getTitle();
		roiManager("reset");
		if (File.exists(genodir+genoname+"seedpositions.zip")==1) {
			roiManager("open", genodir+genoname+"seedpositions.zip");
		} else {
		roiManager("open",genodir+genoname+"initialpositions.zip");
		}
			
		roiarray = newArray(roiManager("count"));
				for(x=0; x<roiManager("count"); x++){
					roiarray[x]=x;
				}
	
		run("Set Measurements...", "centroid redirect=None decimal=5");
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
				Table.create(yref); //table for "y references" which contain the top and bottom borders
				//the borders are setting the top/bottom limits within which the roi can be positioned to prevent rsc from jumping to hypocotyls or sliding down roots
				for(positionnumber = 0; positionnumber < roicount; positionnumber ++) {
					xisp = getResult("X", positionnumber); //xisp is x initial seed position
					yisp = getResult("Y", positionnumber); //yisp is y initial seed position
					ytb = yisp - 0.05; //y top border 
					ybb = yisp + 0.4; //y bottom border 
					Table.set("ytb", positionnumber, ytb, yref); //y (top border) cannot be more than 0.4cm to the top of initial xm
					Table.set("ybb", positionnumber, ybb, yref); //y (bottom border) cannot be more than yisp
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
				for(positionnumber = 0; positionnumber < roicount; positionnumber ++) {
					zprev = z-1;
					rowIndex = (zprev*roicount)+positionnumber; //to reference same ROI from previous slice
					//xm, ym are coordinates for the centre of mass obtained through erosion
					xmprev = Table.get("XM", rowIndex, rsc); //xm of prev slice
					ymprev = Table.get("YM", rowIndex, rsc); //ym of prev slice
					toScaled(xmprev, ymprev);
					ytb = Table.get("ytb", positionnumber, yref);
					ybb = Table.get("ybb", positionnumber, yref);
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
					rowIndex = (zprev*roicount)+x; //to reference same ROI from previous slice
					//xm, ym are coordinates for the centre of mass obtained through erosion
					xmprev = Table.get("XM", rowIndex, rsc); //xm of prev slice
					ymprev = Table.get("YM", rowIndex, rsc); //ym of prev slice
					nr = Table.size(rsc);
					Table.set("Slice", nr, z+1, rsc);
					Table.set("ROI", nr, x+1, rsc);
					Table.set("XM", nr, xmprev, rsc); //set xm as previous slice
					Table.set("YM", nr, ymprev, rsc); //ym as previous slice
				} else { //object detected, erode then analyse particles for xm/ym
					erosionround = 1;
					while (totalarea>0.002 && erosionround < 15) { //if erosion is not working due to bad thresholding, total area never decreases, rsc is copied from previous slice.
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
					erosionround = erosionround + 1;
					}
					
					if (erosionround < 15) {
						while (totalarea>0.012) { 
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
		saveAs("Results", genodir+genoname+"_"+rsc+".tsv");
		rsctsv=genoname+"_"+rsc+".tsv";
		close(rsctsv);
		File.delete(genodir+genoname+"masked.tif");
	}
	}
}

//PART3 skeleton analysis per group
function rootlength() {
	for (y = 0; y < croplist.length; ++y) {
		if (indexOf(croplist[y], "substack")<0) {
			setBatchMode(true);
			genodir = rootgrowthsubdir+"/"+croplist[y]+"/";	
			genoname = File.getName(genodir);
			print("Analyzing root growth of "+platename+genoname);
			open(genodir+genoname+".tif");
			stack1 = getTitle();
					
			//process roots for skeletonization
			secondMask();
			rsc = "Root start coordinates";
			rsctsv = genoname+"_"+rsc+".tsv";
			open(genodir+rsctsv);
			
			nr = Table.size(rsctsv);
			roicount = nr/nSlices;
			roiManager("reset");
			roih = "ROI Heights";
			Table.create(roih);
			for (x=0; x<roicount; x++) {
				setSlice(1);
				roino = Table.get("ROI", x, rsctsv);
				xm1 = Table.get("XM", x, rsctsv);
				ym1 = Table.get("YM", x, rsctsv);
				if (roino<roicount) {
				ym2 = Table.get("YM", x+1, rsctsv);
				y2 = 0.6*(ym2-ym1)+ym1;
				h = 2*(y2-ym1); //height of ROI is distance to next seed *0.6 *2
				Table.set("ROI height", x, h, roih);
				} else { //if last ROI, no distance to next seed, copy last height
				Table.set("ROI height", x, h, roih); 
				}
			}	
			for (x=0; x<nr; x++) {
				slice = Table.get("Slice", x, rsctsv);
				roino = Table.get("ROI", x, rsctsv);
				xm = Table.get("XM", x, rsctsv);
				ym = Table.get("YM", x, rsctsv);
				h = Table.get("ROI height", roino-1, roih); 
				setSlice(slice);
				roiytopright = ym - (0.5*roiheight);
				makeRectangle(0, roiytopright, xm, h);
				roiManager("add");
				roiManager("select", x);
				roiManager("rename", roino);
			}
			
			for (x=0; x<nr; x++) {
			selectWindow(stack1);
			roiManager("select", x);
			roino = Roi.getName;
			sliceno = getSliceNumber();
			run("Duplicate...", "use");
			temp = getTitle();
			halfy = 0.5*getHeight();
			fullx = getWidth();
			run("Set Measurements...", "display redirect=None decimal=3");
			run("Analyze Skeleton (2D/3D)", "prune=none show");
			close("Tagged skeleton");
			close(temp);
			close("Results");
	
			ra="Root analysis";
			bi="Branch information";
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
				Table.set("Primary X", rar, fullx, ra);
				Table.set("Primary Y", rar, halfy, ra);
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
			if (frameproportions >= 1) { //if horizontal
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
		} else {
		run("Combine...", "stack1=["+rsl+"] stack2=["+stack1+"]");
		run("Combine...", "stack1=[Combined Stacks] stack2=["+label+"] combine");
		}
		saveAs("Tiff", genodir+platename+"_"+genoname+"_rootgrowth.tif");
		close();
//Delete temporary files used for analysis
		File.delete(genodir+genoname+"seedpositions.zip");
		File.delete(genodir+genoname+"initialpositions.zip");
		File.delete(genodir+genoname+"_"+"rootstartlabelled.tif");
		File.delete(genodir+genoname+"_"+"skeletonized.tif");
		File.delete(genodir+genoname+"rootstartrois.zip");
		File.delete(genodir+rsctsv);
		
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