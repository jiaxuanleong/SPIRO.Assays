# cleanup_germination_data.R -
#
#   imports data from germination macro and cleans it up a bit.
#   after running this script, adjust the groups in the file germination.postQC.tsv, 
#   then run process_germination_data.R to get statistics.

library(dplyr)
library(foreach)
library(doParallel)

# below are cutoffs for area filtering
upper_area_threshold = 0.012
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
processfile <- function(file, logdir) {
  r <- SeedPos <- Date <- ImgSource <- startdate <- ElapsedHours <- plates <- NULL

  # need to suppress warnings here as imagej saves row numbers as unnamed first column
  suppressWarnings(resultfile <- read_tsv(file, 
                                          col_types=c(Area=col_double(), `Perim.`=col_double(), Slice=col_integer()), 
                                          progress=FALSE))

  if ("X1" %in% names(resultfile)) {
    resultfile <- select(resultfile, -X1)
  }

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
  check_duplicates(data, paste0(logdir, '/', basename(file), '.log'))
  return(data)
}

check_duplicates <- function(data, logfile) {
  # check for rois with duplicate measurements
  error_uids <- error_types <- NULL

  for(uid in unique(data$UID)) {
    # check data per uid (will only be one group per file)
    # ds = data subset
    ds <- data[data$UID == uid,]
    
    # remove data after first occurence of large area
    largearea <- which(ds$Area > upper_area_threshold)
    if (length(largearea)) {
      ds <- ds[1:largearea[1]-1,]
      if(largearea[1] < 50) {
        error_uids <- c(error_uids, uid)
        error_types <- c(error_types, 'EARLY_LARGE_AREA')
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
      # remove entries with these areas
      if(length(areas)) {
        x <- which(ds$Slice == slice & ds$Area %in% areas)
        ds <- ds[-x,]
        cleaned <- cleaned + 1
      } else {
        #print("Same areas")
        dupes <- dupes + 1
      }
    }
    # remove this uid from data, then add modified subset in its place
    data <- data[data$UID != uid,]
    
    # if there are anomalous objects in the first slice, remove the seed from analysis
    if(length(which(ds$Area < lower_area_threshold & ds$Area > upper_area_threshold))) {
      cat(paste("Removing UID", uid, "as it contains an anomalous object in the first slice.\n"))
      error_uids <- c(error_uids, uid)
      error_types <- c(error_types, 'ANOMALOUS_OBJECT')
    } else {
      if(dupes == 0) {
        # keep the seed only if there were no duplicate measurements left
        data <- rbind(data, ds)
      } else {
        cat(paste("Removing UID", uid, "as it contains multiple objects.\n"))
        error_uids <- c(error_uids, uid)
        error_types <- c(error_types, 'DUPE')
      }
    }
  }
  
  if (length(error_uids > 0)) {
    errors <- data.frame(UID=error_uids, Type=error_types)
    write_tsv(errors, path=logfile)
  }

  return(data)
}

# there is no support for directory picker under non-windows platforms
if (.Platform$OS.type == 'unix') {
  dir <- readline(prompt = "Enter directory: ")
} else {
  dir <- choose.dir(getwd(), "Choose folder to process")
}

resultsdir <- paste0(dir, '/Results')
outdir <- paste0(resultsdir, '/Germination assay')

# get all matching .tsv files in the directory
files <- list.files(path = outdir, pattern = 'seed germination analysis.tsv$', full.names = TRUE, recursive = TRUE, ignore.case = TRUE, no.. = TRUE)

allout <- toolarge <- NULL

if (length(files) > 0) {
  num_cores <- max(1, detectCores() - 1)
  cl <- makeCluster(num_cores)
  registerDoParallel(cl)
  
  if (num_cores > 1) {
    core_plural <- 'threads'
  } else {
    core_plural <- 'thread'
  }
  cat(paste0("Processing files and performing basic quality control, using ", 
             length(cl), ' ', core_plural, ". This may take a little while...\n"))

  allout <- foreach(f=files, .combine=rbind, .multicombine=T, .packages=c('dplyr', 'readr')) %dopar%
    processfile(f, outdir)
  
  stopCluster(cl)
  
  # check the logs
  logfiles <- list.files(path = outdir, pattern = 'seed germination analysis.tsv.log$', full.names = TRUE, recursive = TRUE, ignore.case = TRUE, no.. = TRUE)
  log <- NULL
  for (f in logfiles) {
    logfile <- read_tsv(f, col_types=c(UID=col_character(), Type=col_character()))
    log <- rbind(log, logfile)
    file.remove(f)
  }

  for (errtype in unique(log$Type)) {
    if (errtype == 'EARLY_LARGE_AREA') {
      cat('Large non-seed object detected in ROI. Time range has been truncated.\n')
      cat('Affected seeds: ')
      cat(log$UID[log$Type == 'EARLY_LARGE_AREA'])
      cat('\n')
    } else if (errtype == 'ANOMALOUS_OBJECT') {
      cat('An anomalous object was detected in the first slice. Affected seeds were removed from analysis.\n')
      cat('Affected seeds: ')
      cat(log$UID[log$Type == 'ANOMALOUS_OBJECT'])
      cat('\n')
    } else if (errtype == 'DUPE') {
      cat('Duplicated seedlike objects were detected. Affected seeds were removed from analysis.\n')
      cat('Affected seeds: ')
      cat(log$UID[log$Type == 'DUPE'])
      cat('\n')
    }
  }
}

if (length(files) > 0) {
  # round off ElapsedHours to ensure compatibility with spreadsheet software
  allout$ElapsedHours <- round(allout$ElapsedHours, 4)
  allout <- allout[,c(1:2, 8, 3:7)]
  
  write.table(allout, file=paste0(outdir, "/germination.postQC.tsv"), sep='\t', row.names=F)
  cat(paste0("Saving cleaned and collated data to '", outdir, "/germination.postQC.tsv", "'.\nPlease edit that file to set up correct grouping for your experiment.\n"))
} else {
  cat("No seed germination analysis files found in that directory.\n")
}
