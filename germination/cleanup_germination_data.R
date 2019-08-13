# cleanup_germination_data.R -
#
#   imports data from germination macro and cleans it up a bit.
#   after running this script, adjust the groups in the file output.tsv, 
#   then run process_data.R to get statistics.

library(dplyr)

# below are cutoffs for area filtering
upper_area_threshold = 0.01
lower_area_threshold = 0.0012

# extract datetime from strings such as "plate1-20190602-082944-day"
getdate <- function(name) {
  params <- unlist(strsplit(name, '-', fixed=T))
  x <- paste0(params[2:3], collapse='')
  return(strptime(x, format='%Y%m%d%H%M%S'))
}

# return elapsed time in hours from two datetime strings
elapsed <- function(from, to) {
  f <- strptime(from, format="%Y-%m-%d %H:%M:%S")
  t <- strptime(to, format="%Y-%m-%d %H:%M:%S")
  return(as.numeric(difftime(t, f, units='hours')))
}

# main function for extracting data from files
processfile <- function(file) {
  r <- SeedPos <- Date <- ImgSource <- startdate <- ElapsedHours <- plates <- NULL
  resultfile <- read.delim(file, row.names=1, stringsAsFactors = FALSE)
  #resultfile <- resultfile[resultfile$Area <= 2 * upper_area_threshold,]
  for (i in 1:nrow(resultfile)) {
    row <- resultfile[i,]
    # first, go through the file and make a list of rois and timepoints
    params <- unlist(strsplit(row$Label, ':', fixed=T))
    ImgSource <- c(ImgSource, sub('\\.tif$', '', params[1], ignore.case=T))

    if (length(params) == 3) {
      # assume that if the label contains two colons (i.e. 3 extracted elements), it is the initial image
      # for that seed, i.e., we are starting with a new seed here. set initial parameters like seed no etc.
      r <- params[2]
      SeedPos <- c(SeedPos, r)
      d <- startdate <- getdate(params[3])
      plate <- unlist(strsplit(params[3], '-', fixed=T))[1]
      plates <- c(plates, plate)
      Date <- c(Date, as.character(d))
    } else {
      # this is not the first record for a seed
      SeedPos <- c(SeedPos, r)
      d <- getdate(params[2])
      plate <- unlist(strsplit(params[2], '-', fixed=T))[1]
      plates <- c(plates, plate)
      Date <- c(Date, as.character(d))
    }
    ElapsedHours <- c(ElapsedHours, elapsed(startdate, d))
  }
  data <- NULL
  data$UID <- paste0(plates, '_', ImgSource, '_', SeedPos)
  data$Group <- paste0(plates[1], '_', ImgSource[1])
  resultfile <- select(resultfile, -Label)
  data <- cbind(data, resultfile, SeedPos, Date, ElapsedHours)
  return(data)
}

check_duplicates <- function(data) {
  # check for rois with duplicate measurements
  for(uid in unique(data$UID)) {
    # check data per uid (will only be one group per file)
    # ds = data subset
    ds <- data[data$UID == uid,]
    
    # remove data after first occurence of large area
    largearea <- which(ds$Area > upper_area_threshold)
    if (length(largearea)) {
      ds <- ds[1:largearea[1]-1,]
      if(largearea[1] < 50) {
        print(paste(uid, " - large area detected in early slice, please check."))
      }
    }
    
    # d = list of slices with multiple measurements
    d <- ds$Slice[duplicated(ds$Slice)]
    d <- unique(d)
    
    # some stats
    dupes <- cleaned <- 0
    
    for(slice in d) {
      areas <- ds$Area[ds$Slice == slice]
      # remove largest area from list of areas
      areas <- areas[-which.max(areas)]
      #print(paste0("Slice ", slice, ": Removing ", length(areas), " entries with areas ", areas))
      # remove entries with these areas
      if(length(areas)) {
        x <- which(ds$Slice == slice & ds$Area %in% areas)
        ds <- ds[-x,]
        cleaned <- cleaned + 1
      } else {
        #print("Same areas")
        dupes <- dupes + 1
      }
      #ds <- ds[ds$Slice == slice,][! ds$Area %in% areas,]
    }
    # remove this uid from data, then add modified subset in its place
    data <- data[data$UID != uid,]
    
    # if there are anomalous objects in the first slice, remove the seed from analysis
    if(length(which(ds$Area < lower_area_threshold & ds$Area > upper_area_threshold))) {
      print(paste("Removing UID", uid, "as it contains an anomalous object in the first slice."))
    } else {
      if(dupes == 0) {
        # keep the seed only if there were no duplicate measurements left
        data <- rbind(data, ds)
      } else {
        print(paste("Removing UID", uid, "as it contains multiple objects."))
      }
    }
  }
  return(data)
}

# there is no support for directory picker under non-windows platforms
if (.Platform$OS.type == 'unix') {
  dir <- readline(prompt = "Enter directory: ")
} else {
  dir <- choose.dir(getwd(), "Choose folder to process")
}

# get all .txt files in the directory
files <- list.files(path = dir, pattern = 'txt$', full.names = TRUE, recursive = TRUE, ignore.case = TRUE, no.. = TRUE)

allout <- NULL
print("Processing files and performing basic quality control. This may take a little while...")
for (f in files) {
  out <- processfile(f)
  out <- check_duplicates(out)
  allout <- rbind(allout, out)
}

allout <- select(allout, -X.1)

write.table(allout, file=paste0(dir, "/output.tsv"), sep='\t', row.names=F)
