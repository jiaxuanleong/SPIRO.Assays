# cleanup_germination_data.R -
#
#   imports data from germination macro and cleans it up a bit.
#   after running this script, adjust the groups in the file output.tsv, 
#   then run process_data.R to get statistics.

library(dplyr)

# below are cutoffs for area filtering
upper_area_threshold = 0.008
lower_area_threshold = 0.002

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

# find the mode of a vector of numbers
getmode <- function(x) {
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

# main function for extracting data from files
processfile <- function(file) {
  r <- SeedPos <- Date <- ImgSource <- startdate <- ElapsedHours <- plates <- NULL
  resultfile <- read.delim(file, row.names=1, stringsAsFactors = FALSE)
  resultfile <- resultfile[resultfile$Area >= lower_area_threshold & resultfile$Area <= upper_area_threshold,]
  for (i in 1:dim(resultfile)[1]) {
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

# there is no support for directory picker under non-windows platforms
if (.Platform$OS.type == 'unix') {
  dir <- readline(prompt = "Enter directory: ")
} else {
  dir <- choose.dir(getwd(), "Choose folder to process")
}

# get all .txt files in the directory
files <- list.files(path = dir, pattern = 'txt$', full.names = TRUE, recursive = TRUE, ignore.case = TRUE, no.. = TRUE)

allout <- NULL
for (f in files) {
  print(paste("Processing file", f))
  out <- processfile(f)
  allout <- rbind(allout, out)
}

allout <- select(allout, -X.1)

write.table(allout, file=paste0(dir, "/output.tsv"), sep='\t', row.names=F)
