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

step1 <<- step2 <<- step2.5 <<- step3 <<- step4 <<- NULL

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

  # the entire skeleton is a PR if any branch is a PR
  r %>% group_by(UID, elapsed, Skeleton.ID) %>%
    mutate(PR = max(PR)) -> r
  
  step1 <<- rbind(step1, r)
  
  r %>% filter(PR == TRUE) %>%
    group_by(UID, date) %>%
    summarize(Branches = n(), GID = GID[1], 
              Skeletons = length(unique(Skeleton.ID)), 
              Branch.length = sum(Branch.length), 
              elapsed=elapsed[1],
              SliceNo = Slice.no.[1]) -> r
  
  r %>% mutate(delta = Branch.length - lag(Branch.length),
               signdelta = sign(delta),
               absdelta = abs(delta)) -> r
  
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    mutate(mablright = rollapply(Branch.length, 5, mean, na.rm=T, align="left", fill=NA),
           mabldelta = mablright - lag(mablright),
           mablsign = sign(mabldelta)) -> r
  
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    mutate(signsum = rollapply(mablsign, 8, sum, na.rm=T, align="left", fill=NA)) -> r
  
  r$growing <- NA
  
  # if we have more than six consecutive increases of average root length, we assume growth has started
  r$growing[r$signsum > 6] <- TRUE
  
  # if root starts to grow, it is considered to be growing for the remaining datapoints
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    mutate(growing = na.locf(growing, na.rm=F)) -> r
  
  # construct a normalized elapsed time value based on root growth start
  r %>% group_by(UID) %>% mutate(normtime = elapsed - elapsed[1]) -> r
  
  step2 <<- rbind(step2, r)
  
  # remove data points with several PR's
  r %>% filter(Skeletons == 1) -> r
  
  step2.5 <<- rbind(step2.5, r)
  
  r %>% filter(Branch.length > mablright) -> r
  
  # add difference to previous
  r$diff <- ave(r$Branch.length, r$UID, FUN=function(x) c(0, diff(x)))
  r$pctchange <- r$diff / r$Branch.length
  step3 <<- rbind(step3, r)
  
  r[abs(r$diff) > 0.5,] -> suspects
  
  if (length(suspects$UID) > 0) {
    suspects %>%
      group_by(UID) %>%
      summarize(elapsed=min(elapsed)) -> suspects
    for (i in seq(1, length(suspects$UID))) {
      s <- suspects[i,]
      print(paste0('Removing anomalous values from UID ', s$UID, ' starting at timepoint ', s$elapsed))
      r$Branch.length[r$UID == s$UID & r$elapsed >= s$elapsed] <- NA
    }
  }

  step4 <<- rbind(step4, r)

  return(r)
}

# there is no support for directory picker under non-windows platforms
if (.Platform$OS.type == 'unix') {
  dir <- readline(prompt = "Enter directory: ")
} else {
  dir <- choose.dir(getwd(), "Choose folder to process")
}

resultsdir <- paste0(dir, '/Results')
outdir <- paste0(resultsdir, '/Root growth assay')

# get all .tsv files in the directory
files <- list.files(path = outdir, pattern = 'root analysis.tsv$', full.names = TRUE, recursive = TRUE, ignore.case = TRUE, no.. = TRUE)

allout <- NULL

for (f in files) {
  out <- processfile(f)
  allout <- rbind(allout, out)
}

write.table(allout, file=paste0(outdir, "/root-output.tsv"), sep='\t', row.names=FALSE)
write.table(step1, file=paste0(outdir, "/step1.tsv"), sep='\t', row.names=FALSE)
write.table(step2, file=paste0(outdir, "/step2.tsv"), sep='\t', row.names=FALSE)
write.table(step3, file=paste0(outdir, "/step3.tsv"), sep='\t', row.names=FALSE)
write.table(step4, file=paste0(outdir, "/step4.tsv"), sep='\t', row.names=FALSE)
