//requirements for file organization
//main directory containing all images sorted by plate into subdirectories
//requirements for image naming
//plate1-date20190101-time000000-day

//user selection of main directory
showMessage("Please locate and open your experiment folder containing preprocessed data.");
maindir = getDirectory("Choose a Directory");
list = getFileList(maindir);
processMain1(maindir);
processMain2(maindir);
processMain21(maindir);
processMain3(maindir);

list = getList("window.titles"); 
     for (i=0; i<list.length; i++){ 
     winame = list[i]; 
     selectWindow(winame); 
     run("Close"); 
     }

//PART1 crop groups/genotypes per plate
function processMain1(maindir) {
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/") && indexOf(list[i], "cropped")<0) {
			subdir = maindir+list[i];
			sublist = getFileList(subdir);
			platename = File.getName(subdir);
			cropGroup(subdir);
		}
	}
}

//PART2 find seed positions per group per plate
function processMain2(maindir) {
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/") && indexOf(list[i], "cropped")<0) {
			subdir = maindir+list[i];
			sublist = getFileList(subdir);
			platename = File.getName(subdir);
			processSub2(subdir);
		}
	}
}

function processSub2(subdir) {
	platename = File.getName(subdir);
	
	outcrop = subdir + "/rootcropped/";
	croplist = getFileList(outcrop);
	
	seedPosition(subdir);
	print(i+1 +"/"+list.length + " folders processed.");
}

//PART2.1 find root start coordinates per group per plate
function processMain21(maindir) {
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/") && indexOf(list[i], "cropped")<0) {
			subdir = maindir+list[i];
			sublist = getFileList(subdir);
			platename = File.getName(subdir);
			processSub21(subdir);
		}
	}
}

function processSub21(subdir) {
	platename = File.getName(subdir);
	
	outcrop = subdir + "/rootcropped/";
	croplist = getFileList(outcrop);
	
	rootStart(subdir);
	print(i+1 +"/"+list.length + " folders processed.");
}


//PART3 skeleton analysis per group per plate
function processMain3(maindir) {
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/") && indexOf(list[i], "cropped")<0) {
			subdir = maindir+list[i];
			sublist = getFileList(subdir);
			print("Getting root measurements of "+subdir);
			processSub3(subdir);
		}
	}
}

function processSub3(subdir) {
	platename = File.getName(subdir);
	
	outcrop = subdir + "/rootcropped/";
	croplist = getFileList(outcrop);
	
	rootlength(subdir);
	print(i+1 +"/"+list.length + " folders processed.");
};

//PART1 crop genotypes/group 
function cropGroup(subdir) {
	setBatchMode(false);
	open(subdir+platename+"_registered.tif");
	reg = getTitle();
	waitForUser("Create substack", "Please note first and last slice to be included for root length analysis, and indicate it in the next step.");	
	run("Make Substack...");
	saveAs("Tiff", subdir+platename+"_rootlengthsubstack.tif");
	close(reg);
	print("Cropping genotypes/groups in "+platename);
	run("ROI Manager...");
	setTool("Rectangle");
	if (i==0) {
	roiManager("reset");
	waitForUser("Select each group, and add to ROI manager. ROI names will be saved.");
	}
	if (i>0)
	waitForUser("Modify ROI and names if needed.");
	while (roiManager("count") <= 0) {
		waitForUser("Select each group and add to ROI manager. ROI names will be saved.");
	}
	run("Select None");

	outcrop = subdir + "/rootcropped/";
	File.makeDirectory(outcrop);

	setBatchMode(true);
	
	//loop enables cropping of ROI(s) followed by saving of cropped stacks
	//roi names cannot contain dashes due to split() to extract information from file name later on
	roicount = roiManager("count");
	for (x=0; x<roicount; ++x) {
    	roiManager("Select", x);
    	roiname = Roi.getName;
    	if (indexOf(roiname, "-") > 0) {
    		waitForUser("ROI names cannot contain dashes '-'! Please modify the name.");
    		roiname = Roi.getName;
    	}
    	genodir = outcrop + "/"+roiname+"/";
    	File.makeDirectory(genodir);	
		print("Cropping group "+x+1+"/"+roicount+" "+roiname+"...");
    	run("Duplicate...", "duplicate");
    	saveAs("Tiff", genodir+roiname+".tif");
    	close();
	}
close();
print(i+1 +"/"+list.length + " folders processed.");
}


//PART2 finds seed position and saves ROI - looped through crops immediately for user friendliness
function seedPosition(subdir) {
	for (y = 0; y < croplist.length; ++y) {
		setBatchMode(false);
		genodir = outcrop+"/"+croplist[y]+"/";	
		genoname = File.getName(genodir);
		print("Finding seedling positions for "+platename+genoname);
		open(genodir+genoname+".tif");
		img = getTitle();
		
		firstMask();
		run("Rotate 90 Degrees Right");
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
					if (area<0.0008 || area>0.01) {
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
		a = 0;
		for (x=0; x<nResults; x++){
			area = getResult("Area", x);
			if (area>0.02)
			a = a+1;
		}
		if (a>2) {
			sdf = getBoolean("Seedlings detected on first slice. Proceed with ROI selection of root start?");
			if (sdf == 1) 
				sdlingf();
		} else {
		roiManager("save", genodir+genoname+"seedpositions.zip");
		selectWindow(img);
		saveAs("Tiff", genodir+genoname+"masked.tif");
		close();
		}
	}
}

//PART2 creates a binary mask for seed/lings and reduces noise
function firstMask() {
	run("8-bit");
	run("Subtract Background...", "rolling=30 stack");
	run("Median...", "radius=1 stack");
	setAutoThreshold("MaxEntropy dark");
	run("Convert to Mask", "method=MaxEntropy background=Dark");
	run("Options...", "iterations=1 count=4 do=Dilate stack");
    run("Remove Outliers...", "radius=3 threshold=50 which=Dark stack");
    //run("Remove Outliers...", "radius=5 threshold=50 which=Dark stack");
}

function sdlingf() {
	roiManager("reset");
	waitForUser("Please draw ROI encompassing all root starts, then add to ROI Manager.");
	while (roiManager("count") <= 0) {
		waitForUser("Please draw ROI encompassing all root starts, then add to ROI Manager.");
	}
	roiManager("select", 0);
	getBoundingRect(x1, y1, width, height);
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

	waitForUser("Please delete any ROIs that should not be included into analysis, \n e.g. noise selection and seedlings that have overlapping roots");
	roicount = roiManager("count");
	for(x=0; x<roicount; x++){
		roiManager("select", 0);
		Roi.getBounds(x2, y2, width, height);
		selectWindow(img);
		makeRectangle(x2+x1, y2+y1, width, height);
		roiManager("add");
		roiManager("rename", x+1);
		roiManager("select", 0);
		roiManager("delete");
	}
	close(rootstartroi);
	roiManager("save", genodir+genoname+"initialpositions.zip");
	selectWindow(img);
	saveAs("Tiff", genodir+genoname+"masked.tif");
	close();

}


//PART2.1 finds root start coordinates per genotype/group
function rootStart(subdir) {
	for (y = 0; y < croplist.length; ++y) {
		setBatchMode(true);
		genodir = outcrop+"/"+croplist[y]+"/";	
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

		w = 0.18; //width of ROI is 0.18cm
		h = 0.2; //height
		toUnscaled(w, h);
		
		nS = nSlices;
		rsc = "Root start coordinates";
		Table.create(rsc);
		
		for (z=0; z<nS; z++) { //for each slice
			setSlice(z+1); //starting with first slice
			if (z==0) { //if first slice, obtain XY coordinates from Results to make ROI
				roiManager("reset");
				xref = "XRef";
				Table.create(xref);
				for(x=0; x<roicount; x++) {
					xm0 = getResult("X", x); //xm0 is xm of initial seed
					xlb = xm0 - 0.1;
					Table.set("xlb", x, xlb, xref); //x (left border) cannot be more than 0.5cm to the left of initial xm
					Table.set("xrb", x, xm0, xref); //x (right border) cannot be more than xm0
					y0 = getResult("Y", x);
					x2 = xm0 - 0.12; //shift centre of mass 0.12cm to the left
					y2 = y0 - 0.1; //to the top
					toUnscaled(x2, y2);
					makeRectangle(x2, y2, w, h);
					roiManager("add");
				}
			} else { //if subsequent slices, obtain XY coordinates from rsc
				roiManager("reset");
				for(x=0; x<roicount; x++) {
					zprev = z-1;
					rowIndex = (zprev*roicount)+x; //to reference same ROI from previous slice
					x1 = Table.get("XM", rowIndex, rsc); //x1 now is xm of prev slice
					y1 = Table.get("YM", rowIndex, rsc); 
					toScaled(x1, y1);
					xlb = Table.get("xlb", x, xref);
					xrb = Table.get("xrb", x, xref);
					if (x1>xrb){
						x1=xrb;
					}
					if (x1<xlb){
						x1=xlb;
					}
					Table.set("xrb", x, x1, xref); //set right border 
					x2 = x1 - 0.12;
					y2 = y1 - 0.1;
					toUnscaled(x2, y2);
					makeRectangle(x2, y2, w, h);
					roiManager("add");
				}
			}
		
			for (x=0; x<roiManager("count"); x++) { //for number of rois
				run("Set Measurements...", "area center display redirect=None decimal=5");
				roiManager("select", x);
				run("Analyze Particles...", "display clear summarize slice");
			
				count = Table.get("Count", Table.size("Summary of "+img)-1, "Summary of "+img);
				totalarea = Table.get("Total Area", Table.size("Summary of "+img)-1, "Summary of "+img);
 
				if (count==0) { //firstMask() erased seed (rarely happens)
					toUnscaled(x1,y1);
					nr = Table.size(rsc);
					Table.set("Slice", nr, z+1, rsc);
					Table.set("ROI", nr, x+1, rsc);
					Table.set("XM", nr, x1, rsc); //set xm as previous slice
					Table.set("YM", nr, y1, rsc); //ym as previous slice
				} else { //erode then analyse particles for xm/ym
					
				while (totalarea>0.0015) {
				roiManager("select", x);
				run("Options...", "iterations=1 count=1 do=Erode");
				roiManager("select", x);
				run("Analyze Particles...", "display summarize slice");
		
				count = Table.get("Count", Table.size-1, "Summary of "+img);
					if (count==0) { //erode went too far, particle disappeared
						totalarea=0; //to get out of the while loop
					} else {
					totalarea = Table.get("Total Area", Table.size-1, "Summary of "+img);
					}
				}
		
				while (totalarea>0.0012) {
				roiManager("select", x);
				run("Options...", "iterations=1 count=3 do=Erode");
				roiManager("select", x);
				run("Analyze Particles...", "display clear summarize slice");
		
				count = Table.get("Count", Table.size-1, "Summary of "+img);
					if (count==0) { //erode went too far, particle disappeared
						totalarea=0; //to get out of the while loop
					} else {
					totalarea = Table.get("Total Area", Table.size-1, "Summary of "+img);
					}
				}
		
				if (count>1) {
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
		}
		}
		close(xref);
		close("Results");
		close("Summary of "+img);
		close(img);
		
		open(genodir+genoname+".tif");
		run("Rotate 90 Degrees Right");
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
		run("Rotate 90 Degrees Left");
		saveAs("Tiff", genodir+genoname+"_"+"rootstartlabelled.tif");
		close();
		
		selectWindow(rsc);
		saveAs("Results", genodir+genoname+"_"+rsc+".tsv");
		close(rsc);
		File.delete(genodir+genoname+"masked.tif");
	}
}

//PART3 skeleton analysis per group
function rootlength(subdir) {
	for (y = 0; y < croplist.length; ++y) {
		setBatchMode(true);
		genodir = outcrop+"/"+croplist[y]+"/";	
		genoname = File.getName(genodir);
		print("Analyzing root growth of "+platename+genoname);
		open(genodir+genoname+".tif");
		stack1 = getTitle();
		run("Rotate 90 Degrees Right");
				
		//process roots for skeletonization
		secondMask();
		rsc = "Root start coordinates";
		rsc = genoname+"_"+rsc+".tsv";
		open(genodir+rsc);
		
		nr = Table.size(rsc);
		roicount = nr/nSlices;
		roiManager("reset");
		roih = "ROI Heights";
		Table.create(roih);
		for (x=0; x<roicount; x++) {
			setSlice(1);
			roino = Table.get("ROI", x, rsc);
			xm1 = Table.get("XM", x, rsc);
			ym1 = Table.get("YM", x, rsc);
			if (roino<roicount) {
			ym2 = Table.get("YM", x+1, rsc);
			y2 = 0.6*(ym2-ym1)+ym1;
			h = 2*(y2-ym1); //height of ROI is distance to next seed *0.6 *2
			Table.set("ROI height", x, h, roih);
			} else { //if last ROI, no distance to next seed, copy last height
			Table.set("ROI height", x, h, roih); 
			}
		}
		for (x=0; x<nr; x++){
			slice = Table.get("Slice", x, rsc);
			roino = Table.get("ROI", x, rsc);
			xm1 = Table.get("XM", x, rsc);
			ym1 = Table.get("YM", x, rsc);
			h = Table.get("ROI height", roino-1, roih); 
			setSlice(slice);
			y1 = ym1 - (0.5*h);
			makeRectangle(0, y1, xm1, h);
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

		selectWindow(stack1);
		roiManager("reset");
		roiManager("open", genodir+genoname+"rootstartrois.zip");
		roiManager("Associate", "true");
		roiManager("Centered", "false");
		roiManager("UseNames", "true");
		roiManager("Show All with labels");
		run("Labels...", "color=white font=18 show use draw");
		run("Flatten", "stack");
		run("Rotate 90 Degrees Left");
		saveAs("Tiff", genodir+genoname+"_"+"skeletonized.tif");
		stack1 = getTitle();
		nS = nSlices;
//Determine the cropped frame proportions to orient combining stacks horizontally or vertically
		xmax = getWidth;
		ymax = getHeight;
		frameproportions=xmax/ymax; 
		
//Add label to each slice (time point). The window width for label is determined by frame proportions 
		for (x = 0; x < nS; x++) {
			selectWindow(stack1);
			setSlice(x+1);
			slicelabel = getMetadata("Label");
			if (frameproportions > 1) {
			newImage("Slice label", "RGB Color", xmax, 50, 1);
			setFont("SansSerif", 20, " antialiased");
			makeText(slicelabel, 0, 0);
			setForegroundColor(0, 0, 0);
			run("Draw", "slice");
			selectWindow(stack1);
			run("Next Slice [>]");
		 }
		
		if (frameproportions < 1) {
			newImage("Slice label", "RGB Color", 2*xmax, 50, 1);
			setFont("SansSerif", 20, " antialiased");
			makeText(slicelabel, 0, 0);
			setForegroundColor(0, 0, 0);
			run("Draw", "slice");
			selectWindow(stack1);
			run("Next Slice [>]");
		}
}
//Combine the cropped photos and binary masks with labels into one time-lapse stack. Combine vertically or horizontally depending on the frame proportions
		run("Images to Stack");
		label = getTitle();
		open(genodir+genoname+"_"+"rootstartlabelled.tif");
		rsl = getTitle();
		
		if (frameproportions > 1) {
		run("Combine...", "stack1=["+rsl+"] stack2=["+stack1+"] combine");
		run("Combine...", "stack1=[Combined Stacks] stack2=["+label+"] combine");
		}
		if (frameproportions < 1) {
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
		File.delete(genodir+rsc);
		
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