# cleanup_rootgrowth_data.R -

pixel_radius <- 5

library(dplyr)
library(zoo)

# debug stuff:
rawfile <- step1 <- step2 <- step3 <- NULL

# return elapsed time in hours from two datetime strings
elapsed <- function(from, to) {
  f <- strptime(from, format="%Y-%m-%d %H:%M:%S")
  t <- strptime(to, format="%Y-%m-%d %H:%M:%S")
  return(as.numeric(difftime(t, f, units='hours')))
}

minus <- function(vals) {
  return(vals[2] - vals[1])
}

processfile <- function(file) {
  r <- read.delim(file, stringsAsFactors=FALSE)
  b <- basename(f)
  GID <- paste0(unlist(strsplit(b, ' ', fixed=TRUE))[1], '_', unlist(strsplit(b, ' ', fixed=TRUE))[2])
  r$GID <- GID
  unlist(strsplit(r$Slice.name, '-', fixed=TRUE)) -> params
  r$date <- as.POSIXct(strptime(paste0(params[seq(2, length(params), 4)], params[seq(3, length(params), 4)]), format='%Y%m%d%H%M%S'))
  r$PR <- FALSE
  rawfile <<- r
  r$UID <- paste0(GID, '_', r$ROI)
  # check if root coords match primary x/y and set PR variable accordingly
  r$PR[abs(r$Primary.X - r$V1.x) < pixel_radius & abs(r$Primary.Y - r$V1.y) < pixel_radius] <- TRUE
  r$PR[abs(r$Primary.X - r$V2.x) < pixel_radius & abs(r$Primary.Y - r$V2.y) < pixel_radius] <- TRUE

  # add elapsed times
  r %>% group_by(UID) %>%
    arrange(date) %>%
    mutate(elapsed=elapsed(date[1], date)) -> r
  step1 <<- r
  
  # the entire skeleton is a PR if any branch is a PR
  r %>% group_by(UID, elapsed, Skeleton.ID) %>%
    mutate(PR = max(PR)) -> r
  
  r %>% filter(PR == TRUE) %>%
    group_by(UID, date) %>%
    summarize(Branches = n(), GID = GID[1], Skeletons = length(unique(Skeleton.ID)), BranchLength = sum(Branch.length), elapsed=elapsed[1]) -> r
  # r %>% group_by(ROI, date, Skeleton.ID) %>%
  #   filter(PR == TRUE) %>%
  #   filter(Branch.length == max(Branch.length)) %>%
  #   mutate(n=n(), maxlength = max(Branch.length)) -> r
  step2 <<- r
  
  # remove data points with several PR's
  r$BranchLength[r$Skeletons > 1] <- NA
  
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    mutate(mabl=rollapply(BranchLength, 10, mean, na.rm=T, align="right", fill=NA)) %>%
    filter(BranchLength > mabl) -> r
  
  # add difference to previous
  r$diff <- ave(r$BranchLength, r$UID, FUN=function(x) c(0, diff(x)))
  r$pctchange <- r$diff / r$BranchLength
  step3 <<- r

  r[abs(r$diff) > 0.5,] -> suspects

  if (length(suspects$UID) > 0) {
    suspects %>%
      group_by(UID) %>%
      summarize(elapsed=min(elapsed)) -> suspects
    for (i in seq(1, length(suspects$UID))) {
      s <- suspects[i,]
      print(paste0('Removing anomalous value from UID ', s$UID, ' at timepoint ', s$elapsed))
      r$BranchLength[r$UID == s$UID & r$elapsed >= s$elapsed] <- NA
    }
  }
  step4 <<- r
  return(r)
}

# there is no support for directory picker under non-windows platforms
if (.Platform$OS.type == 'unix') {
  dir <- readline(prompt = "Enter directory: ")
} else {
  dir <- choose.dir(getwd(), "Choose folder to process")
}

# get all .tsv files in the directory
files <- list.files(path = dir, pattern = 'root analysis.tsv$', full.names = TRUE, recursive = TRUE, ignore.case = TRUE, no.. = TRUE)

allout <- NULL

for (f in files) {
  out <- processfile(f)
  allout <- rbind(allout, out)
}

write.table(allout, file=paste0(dir, "/root-output.tsv"), sep='\t', row.names=FALSE)
