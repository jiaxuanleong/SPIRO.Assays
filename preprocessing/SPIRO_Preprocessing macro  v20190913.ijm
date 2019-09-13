//requirements for file organization
//main directory containing all images sorted by plate into subdirectories
//requirements for image naming
//plate1-date20190101-time000000-day

//user selection of main directory
showMessage("Please locate and open your experiment folder.");
maindir = getDirectory("Choose a Directory ");
regq = getBoolean("Would you like to carry out drift correction (registration)? \n Please note that this step may take up a lot of time and computer memory for large datasets.")
list = getFileList(maindir);
segmentsize = 350;
processMain1(maindir);

list = getList("window.titles"); 
     for (i=0; i<list.length; i++){ 
     winame = list[i]; 
     selectWindow(winame); 
     run("Close"); 
     }

///set up recursive processing of a main directory which contains multiple subdirectories   
function processMain1(maindir) {
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/")) {
			subdir = maindir+list[i];
			sublist = getFileList(subdir);
			platename = File.getName(subdir);
			if (sublist.length<segmentsize) {
			processSub1(subdir);
			} else {
				processSub12(subdir);
			}
		}
	}
}

function processSub1(subdir) {
	print("Processing "+ subdir+ "...");
	setBatchMode(false);
	run("Image Sequence...", "open=["+subdir+sublist[0]+"]+convert sort use");
	stack1 = getTitle();
	scale();
	crop();
	if (regq ==1) {
	register();
	} else {
		selectWindow(stack1);
		saveAs("Tiff", subdir+platename+"_unregistered.tif");
		run("Z Project...", "projection=[Standard Deviation]");
		zproj = getTitle();
		saveAs("Tiff", subdir+platename+"unregZ-Projection.tif");
	}
	print(i+1 +"/"+list.length + " folders processed.");
}


function scale() {
	print("Setting scale...");
	if (i==0){
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel global");
	setTool("line");
	run("Set Measurements...", "area bounding display redirect=None decimal=3");
	waitForUser("Setting the scale. Please zoom in on the scale bar and hold the SHIFT key while drawing a line corresponding to 1cm.");
	run("Measure");
	length = getResult('Length', nResults-1);
	while (length==0 || isNaN(length)) {
        waitForUser("Line selection required.");
        run("Measure");
		length = getResult('Length', nResults-1);
	}
	angle  = getResult('Angle', nResults-1);
	while (angle != 0) {
			waitForUser("Line must not be at an angle.");
			run("Measure");
			angle  = getResult('Angle', nResults-1);
	}
	Table.rename("Results", "Positions");
	waitForUser("1cm corresponds to " + length + " pixels. Click OK if correct.");
	run("Set Scale...","distance="+length+" known=1 unit=cm global");
	} else {
		length = Table.get("Length", 0, "Positions");
		run("Set Scale...","distance="+length+" known=1 unit=cm global");
	}
	}

//for cropping of images into a smaller area to allow faster processing
function crop() {
	print("Cropping...");
	nR = Table.size;
	bx = Table.get("BX", nR-1, "Positions");
	by = Table.get("BY", nR-1, "Positions");
	length = Table.get("Length", nR-1, "Positions");
	xmid = (bx+length/2);
	dx = 13;
	dy = 10.5;
	toUnscaled(dx, dy);
	x1 = xmid - dx;
	y1 = by - dy;
	width = 14;
	height = 12.5;
	toUnscaled(width, height);
	makeRectangle(x1, y1, width, height);
	run("Crop");
}

function register() {
	print("Registering...");
	run("8-bit");
	run("Duplicate...", "duplicate");
	stack2 = getTitle();
	run("Subtract Background...", "rolling=30 stack");
	tfn = subdir+"/Transformation Matrices/";
	run("MultiStackReg", "stack_1="+stack2+" action_1=Align file_1="+tfn+" stack_2=None action_2=Ignore file_2=[] transformation=Translation save");
	close(stack2);
	run("MultiStackReg", "stack_1="+stack1+" action_1=[Load Transformation File] file_1="+tfn+" stack_2=None action_2=Ignore file_2=[] transformation=[Translation]");
	selectWindow(stack1);
	saveAs("Tiff", subdir+platename+"_registered.tif");
	run("Z Project...", "projection=[Standard Deviation]");
	zproj = getTitle();
	saveAs("Tiff", subdir+platename+"Z-Projection.tif");
	close();
	close();
}

function processSub12(subdir) {
	setBatchMode(false);
	print("Processing "+ subdir+ "...");
	if (i==0)
	showMessage(sublist.length+" time points detected. Images will be preprocessed in batches of "+segmentsize+" to reduce RAM requirement.");
	numloops = sublist.length/segmentsize; // number of loops
	
	rnl = round(numloops); //returns closest integer
	if (rnl<numloops) { //if rounded down
		numloops = rnl+1; //add one
	} else { //if rounded up or equal
		numloops = rnl; //correct
	}
	
	for (x=0; x<numloops; x++) {
		print("Processing batch "+x+1);
		initial = x*segmentsize+1;
		if (x==numloops-1) {//on last loop
			lastno = sublist.length-initial+1; //open only the number of images left
			run("Image Sequence...", "open=["+subdir+sublist[0]+"] number=["+lastno+"] starting=["+initial+"] convert sort use");
		} else {
		run("Image Sequence...", "open=["+subdir+sublist[0]+"] number=["+segmentsize+"] starting=["+initial+"] convert sort use");
		}
		stack1 = getTitle();
		if (x==0) {
			scale();
		} else {
			length = Table.get("Length", 0, "Positions");
			run("Set Scale...","distance="+length+" known=1 unit=cm global");
		}
		crop();
		if (regq ==1) {
			register12();
		} else {
			selectWindow(stack1);
			saveAs("Tiff", subdir+platename+"_segment"+x+1+"_unregistered.tif");
			close();
		}
	}
	y=0;
	sublist=getFileList(subdir);
	for (x=0; x<sublist.length; x++) {
		if (indexOf(sublist[x], "segment")>0) {
		open(subdir+sublist[x]);
		rename(y);
		y=y+1;
		}
	}
	for (x=0; x<y-1; x++) {
		if (x==0) {
		run("Concatenate...", "  image1=["+x+"] image2=["+x+1+"]");
		} else {
			run("Concatenate...", "  image1=[Untitled] image2=["+x+1+"]");
		}
	}
	run("Z Project...", "projection=[Standard Deviation]");
	saveAs("Tiff", subdir+platename+"Z-Projection.tif");
	close(platename+"Z-Projection.tif");
	selectWindow("Untitled");
	if(regq==1) {
	saveAs("Tiff", subdir+platename+"_registered.tif");
	close(platename+"_registered.tif");
	} else {
		saveAs("Tiff", subdir+platename+"_unregistered.tif");
		close(platename+"_unregistered.tif");
	}
	for (x=0; x<sublist.length; x++) {
		if (indexOf(sublist[x], "segment")>0)
		File.delete(subdir+sublist[x]);
	}
	print(i+1 +"/"+list.length + " folders processed.");
}

function register12() {
	print("Registering...");
	open(subdir+sublist[0]); //open first time point
	crop();
	tempini = getTitle();
	run("8-bit");
	run("Concatenate...", "  image1=["+tempini+"] image2=["+stack1+"]"); 
	//stick first time point to stack, to enable more accurate registration for later time points
	stack1 = getTitle();
	run("Duplicate...", "duplicate");
	stack2 = getTitle();
	run("Subtract Background...", "rolling=30 stack");
	tfn = subdir+"/Transformation Matrices/";
	run("MultiStackReg", "stack_1="+stack2+" action_1=Align file_1="+tfn+" stack_2=None action_2=Ignore file_2=[] transformation=Translation save");
	close(stack2);
	run("MultiStackReg", "stack_1="+stack1+" action_1=[Load Transformation File] file_1="+tfn+" stack_2=None action_2=Ignore file_2=[] transformation=[Translation]");
	selectWindow(stack1);
	run("Slice Remover", "first=1 last=1 increment=1"); //remove temporary first slice
	saveAs("Tiff", subdir+platename+"_segment"+x+1+"_registered.tif");
	close();
}

