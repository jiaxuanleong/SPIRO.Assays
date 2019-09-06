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
	};
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
		roiarray = newArray(roiManager("count"));
				for(x=0; x<roiManager("count"); x++){
					roiManager("select", x);
					roiManager("rename", x+1);
					roiarray[x]=x;
				}
				
		roiManager("save", genodir+genoname+"seedpositions.zip");
		selectWindow(img);
		saveAs("Tiff", genodir+genoname+"masked.tif");
		close();
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
    run("Remove Outliers...", "radius=5 threshold=50 which=Dark stack");
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
		roiManager("open", genodir+genoname+"seedpositions.zip")
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
				xini = "Xini";
				Table.create(xini);
				for(x=0; x<roicount; x++) {
					x0 = getResult("X", x);
					Table.set("x0", x, x0, xini);
					y0 = getResult("Y", x);
					x2 = x0 - 0.12; //shift centre of mass 0.12cm to the left
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
					x1 = Table.get("XM", rowIndex, rsc);
					y1 = Table.get("YM", rowIndex, rsc);
					toScaled(x1, y1);
					x0 = Table.get("x0", x, xini);
					if (x1>x0) {
						x1=x0;
					}
					
					Table.set("x0", x, x1, xini); //HASH THIS LINE OUT TO ALWAYS REFER TO X OF FIRST SLICE
					//RUN LINE ABOVE TO REFER TO X OF PREVIOUS SLICE
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
			
				count = Table.get("Count", Table.size-1, "Summary of "+img);
				totalarea = Table.get("Total Area", Table.size-1, "Summary of "+img);
 
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
		close(xini);
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
		for (x=0; x<nr; x++){
			slice = Table.get("Slice", x, rsc);
			roino = Table.get("ROI", x, rsc);
			xm1 = Table.get("XM", x, rsc);
			ym1 = Table.get("YM", x, rsc);
			setSlice(slice);
			if (roino == roicount) {
				y1 = ym1 - (0.5*h);
				makeRectangle(0, y1, xm1, h);
			} else {
				ym2 = Table.get("YM", x+1, rsc);
				y2 = 0.6*(ym2-ym1)+ym1;
				h = 2*(y2-ym1);
				y1 = ym1 - (0.5*h);
				makeRectangle(0, y1, xm1, h);
			}
			roiManager("add");
			roiManager("select", x);
			roiManager("rename", roino);
		}
		
		for (x=0; x<nr; x++) {
		selectWindow(stack1);
		roiManager("select", x);
		roino = Roi.getName;
		run("Duplicate...", "use");
		temp=getTitle();
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
			Table.set("ROI", rar, roino, ra);
			id = Table.get("Skeleton ID", z, bi);
			Table.set("Skeleton ID", rar, id, ra);
			bl = Table.get("Branch length", z, bi);
			Table.set("Branch length", rar, bl, ra);
			v1x = Table.get("V1 x", z, bi);
			Table.set("V1 x", rar, v1x, ra);
			v1y = Table.get("V1 y", z, bi);
			Table.set("V1 y", rar, v1y, ra);
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
		run("Flatten", "stack");
		run("Rotate 90 Degrees Left");
		saveAs("Tiff", genodir+genoname+"_"+"skeletonized.tif");
		stack1 = getTitle();
		xmax = getWidth;
		nS = nSlices;

		for (x = 0; x < nS; x++) {
			selectWindow(stack1);
			setSlice(x+1);
			slicelabel = getMetadata("Label");
			newImage("Slice label", "RGB Color", xmax, 50, 1);
			setFont("SansSerif", 20, " antialiased");
			makeText(slicelabel, 0, 0);
			setForegroundColor(0, 0, 0);
			run("Draw", "slice");
		}
		
		run("Images to Stack");
		label = getTitle();
		
		open(genodir+genoname+"_"+"rootstartlabelled.tif");
		rsl = getTitle();
		
		run("Combine...", "stack1=["+rsl+"] stack2=["+stack1+"] combine");
		run("Combine...", "stack1=[Combined Stacks] stack2=["+label+"] combine");
		
		saveAs("Tiff", genodir+platename+"_"+genoname+"_rootgrowth.tif");
		close();
		File.delete(genodir+genoname+"seedpositions.zip");
		File.delete(genodir+genoname+"_"+"rootstartlabelled.tif");
		File.delete(genodir+genoname+"_"+"skeletonized.tif");
		File.delete(genodir+genoname+"rootstartrois.zip");
		File.delete(genodir+rsc);
		
}
}


//PART3 creates a binary mask for roots and reduces noise
function secondMask() {
	run("8-bit");
	run("Subtract Background...", "rolling=5 stack");
	run("Enhance Contrast...", "saturated=0.2 normalize process_all");
	setAutoThreshold("MaxEntropy dark");
	setOption("BlackBackground", false);
	run("Convert to Mask", "method=MaxEntropy background=Dark calculate");
	run("Options...", "iterations=1 count=1 pad do=Dilate stack");
	run("Options...", "iterations=3 count=1 pad do=Close stack");
	run("Remove Outliers...", "radius=4 threshold=1 which=Dark stack");
	run("Options...", "iterations=1 count=1 pad do=Skeletonize stack");
}
