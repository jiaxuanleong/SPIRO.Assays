# cleanup_germination_data.R -
#
#   imports data from germination macro and cleans it up a bit.
#   after running this script, adjust the groups in the file germination.postQC.tsv, 
#   then run process_germination_data.R to get statistics.

library(dplyr)
library(foreach)
library(doParallel)
library(readr)

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
                                          col_types=c(Area=col_double(), `Perim.`=col_double(), Slice=col_integer(),
                                                      UID=col_character(), Group=col_character()), 
                                          progress=FALSE))

  if ("X1" %in% names(resultfile)) {
    resultfile <- select(resultfile, -X1)
  }
  resultfile <- as.data.frame(resultfile)
  print(str(resultfile))
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
  data <- check_duplicates(data, paste0(logdir, '/', basename(file), '.log'))
  return(data)
}

check_duplicates <- function(data, logfile) {
  # check for rois with duplicate measurements
  error_uids <- error_types <- NULL

  for(uid in unique(data$UID)) {
    # check data per uid (will only be one group per file)
    # ds = data subset
    ds <- data[which(data$UID == uid),]

    # trim data to first occurence of large area
    largearea <- which(ds$Area > upper_area_threshold)
    if (length(largearea)) {
      ds <- ds[1:largearea[1]-1,]
      if(largearea[1] < 50) {
        error_uids <- c(error_uids, uid)
        error_types <- c(error_types, 'EARLY_LARGE_AREA')
      }
    }

    # filter out large and small objects
    ds %>% filter(Area >= lower_area_threshold) %>% filter(Area <= upper_area_threshold) -> ds
    
    # we want remove this seed if there are multiple measurements left for any slice
    ds %>% group_by(Slice) %>% mutate(n=n()) -> ds

    # remove this uid from data, so we can add modified subset in its place
    data <- data[data$UID != uid,]

    # if there are anomalous objects in the first slice, remove the seed from analysis
    if(max(ds$n) > 1) {
      # we have some slices left with multiple measurements -- remove the seed
      error_uids <- c(error_uids, uid)
      error_types <- c(error_types, 'DUPE')
    } else {
      ds <- select(ds, -n)
      # need to cast to data frame or this fails
      data <- rbind(as.data.frame(data), as.data.frame(ds))
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

allout <- toolarge <- err_largeobj <- err_multiobj <- NULL

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
      cat('Affected seeds: \n')
      cat(paste0(log$UID[log$Type == 'EARLY_LARGE_AREA']), '\n')
      cat('\n')
      err_largeobj <- data.frame(UID=log$UID[log$Type == 'EARLY_LARGE_AREA'], Note='Large non-seed object detected in ROI. Time range was truncated.')
    } else if (errtype == 'DUPE') {
      cat('Multiple objects remained after filtering. Affected seeds were removed from analysis.\n')
      cat('Affected seeds: \n')
      cat(paste0(log$UID[log$Type == 'DUPE'], '\n'))
      cat('\n')
      err_multiobj <- data.frame(UID=log$UID[log$Type == 'DUPE'], Note='Multiple objects remained after filtering. Seed was removed from analysis.')
    }
  }
  errors <- rbind(err_largeobj, err_multiobj)
  errors$UID <- as.character(errors$UID)
  errors$Note <- as.character(errors$Note)
}

if (length(files) > 0) {
  # round off ElapsedHours to ensure compatibility with spreadsheet software
  allout$ElapsedHours <- round(allout$ElapsedHours, 4)
  allout <- allout[,c(1:2, 8, 3:7)]
  
  write.table(allout, file=paste0(outdir, "/germination.postQC.tsv"), sep='\t', row.names=F)
  cat(paste0("Saving cleaned and collated data to '", outdir, "/germination.postQC.tsv", "'.\nPlease edit that file to set up correct grouping for your experiment.\n"))
  
  # create error log
  seedlog <- data.frame(UID=unique(allout$UID), Note='Seed processed normally.')
  seedlog$UID <- as.character(seedlog$UID)
  seedlog$Note <- as.character(seedlog$Note)
  if (nrow(errors) > 0) {
    seedlog <- merge(seedlog, errors, by="UID", all=T)
  }
  seedlog %>% mutate(Note = coalesce(Note.x, Note.y)) %>% select(c(UID, Note)) -> seedlog
  write.table(seedlog, file=paste0(outdir, "/germination.postQC.log.tsv"), sep='\t', row.names=F)
} else {
  cat("No seed germination analysis files found in that directory.\n")
}
