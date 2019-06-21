
function countSeeds() {
	outcrop = subdir + "/cropped/";
	croplist = getFileList(outcrop);

	for (y = 0; y < croplist.length; ++y) {
		print("Tracking germination of "+croplist[y]);
		setBatchMode(true);
		genodir = outcrop+"/"+croplist[y]+"/";
		genolist = getFileList(genodir);
		genoname = File.getName(genodir);
		open(genodir+genolist[0]);
		stack1 = getTitle();
		orifile = File.name;
		run("Duplicate...", "duplicate");
		stack2 = getTitle();

		selectWindow(stack1);
		seedMask();
		run("Rotate 90 Degrees Right");
		run("Set Measurements...", "area perimeter shape display redirect=None decimal=3");
		run("Analyze Particles...", "size=0.002-0.009 circularity=0.5-1.00 show=Outlines display clear summarize stack");
		outlinestack = getTitle();
		run("Rotate 90 Degrees Left");
		run("RGB Color");

		//Obtain slice labels (contains time point info)
		//Prints them on a new stack, then merges to outlinestack
		selectWindow(stack2);
		setSlice(1);
		xmax = getWidth;
		
		for (x = 0; x < nSlices; x++) {
			slicelabel = getMetadata("Label");
			newImage("Slice label", "RGB white", xmax, 50, 1);
			setFont("SansSerif", 20, " antialiased");
			makeText(slicelabel, 0, 0);
			setForegroundColor(0, 0, 0);
			run("Draw", "slice");
			selectWindow(stack2);
			run("Next Slice [>]");
		}
		
		run("Images to Stack");
		run("Combine...", "stack1=["+outlinestack+"] stack2=[Stack] combine");
		run("Combine...", "stack1=["+stack2+"] stack2=[Combined Stacks] combine");
		saveAs("Tiff", genodir+"_outline"+".tif");
		close();
		close();

		//save output of particle analysis
		selectWindow("Summary of "+orifile);
		summaryPA();
		platename = File.getName(subdir);
		saveAs("Text", genodir+platename+" "+genoname+" seed count summary.txt");
		run("Close");
		selectWindow("Results");
		resultPA();
		saveAs("Text", genodir+platename+" "+genoname+" individual seed analysis.txt");
		run("Close");
}
}


//creates a binary mask and reduces noise
function seedMask() {
	run("8-bit");
	run("Subtract Background...", "rolling=30 stack");
	run("Median...", "radius=1 stack");
	setAutoThreshold("MaxEntropy dark");
	run("Convert to Mask", "method=MaxEntropy background=Dark");
	run("Options...", "iterations=1 count=4 do=Dilate stack");
    run("Remove Outliers...", "radius=3 threshold=50 which=Dark stack");
}

//reduces summary of particle analysis to just "Count"
//adds Genotype, Date, Time to results table based on file name
function summaryPA() {
	Table.deleteColumn("Total Area");
	Table.deleteColumn("Average Size");
	Table.deleteColumn("%Area");
	Table.deleteColumn("Perim.");
	Table.deleteColumn("Solidity");
	Table.deleteColumn("Circ.");
	Table.update;

	nR = Table.size;

	
	for (v=0; v<nR;v++) {
		resLabel = Table.getString("Slice", v);
		part = split(resLabel, "-");
		date = part[1];
		time = part[2]; 
		Table.set("Genotype", v, genoname);
		Table.set("Date", v, date);
		Table.set("Time", v, time);
	}
	Table.update;

	for (v=0; v<nR; v++) {
		inicount = Table.get("Count", 0);
		count = Table.get("Count", v);
		label = Table.get("Slice", v);

		if (v==0)
		errorcount = 0;
		
		if (count != inicount)
			errorcount=errorcount+1;
	}
	
		if (errorcount > 0)
			print("Warning! Number of seeds detected were not equal between time points.");
}

function resultPA() {
	Table.deleteColumn("Circ.");
	Table.deleteColumn("Solidity");
}
