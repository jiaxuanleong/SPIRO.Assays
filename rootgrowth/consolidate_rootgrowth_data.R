# consolidate_rootgrowth_data.R -

library(dplyr)
library(ggplot2)
library(zoo)

# clean slate
rm(list=ls())
source('common/common.R')

# function for plotting unprocessed data
plotfile <- function(file) {
  r <- read.delim(file, stringsAsFactors=FALSE)
  names(r) <- c('Slice', 'Label', 'Rootno', 'Length')
  d <- dirname(file)
  dirparams <- unlist(strsplit(d, '/', fixed=T))
  r$GID <- paste0(dirparams[length(dirparams)-1], '_', dirparams[length(dirparams)])
  r$UID <- paste0(r$GID, '_', r$Rootno)
  params <- unlist(strsplit(r$Label, '-', fixed=TRUE))
  r$date <- as.POSIXct(strptime(paste0(params[seq(2, length(params), 4)], params[seq(3, length(params), 4)]), format='%Y%m%d%H%M%S'))
  
  # add elapsed times
  r %>% group_by(UID) %>%
    arrange(date) %>%
    mutate(elapsed=elapsed(date[1], date)) -> r
  
  return(ggplot(r, aes(x=elapsed, y=Length, color=UID, group=UID)) + 
           geom_point() + 
           geom_line() +
           labs(title=paste0("Unprocessed graph for ", r$GID), x="Elapsed time (h)", y="Root length (cm)"))
}

processfile <- function(file, expname) {
  r <- read.delim(file, stringsAsFactors=FALSE)
  names(r) <- c('Slice', 'Label', 'Rootno', 'Length')
  d <- dirname(file)
  dirparams <- unlist(strsplit(d, '/', fixed=T))
  r$GID <- paste0(dirparams[length(dirparams)-1], '_', dirparams[length(dirparams)])
  r$UID <- paste0(r$GID, '_', r$Rootno, '_exp:', expname)
  params <- unlist(strsplit(r$Label, '-', fixed=TRUE))
  r$date <- as.POSIXct(strptime(paste0(params[seq(2, length(params), 4)], params[seq(3, length(params), 4)]), format='%Y%m%d%H%M%S'))
  
  # add elapsed times
  r %>% group_by(UID) %>%
    arrange(date) %>%
    mutate(elapsed=elapsed(date[1], date)) -> r

  r %>% mutate(delta = Length - lag(Length),
               signdelta = sign(delta),
               absdelta = abs(delta)) -> r

  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    mutate(mablright = rollapply(Length, 5, mean, align="left", fill=NA),
           mabldelta = mablright - lag(mablright),
           mablsign = sign(mabldelta)) -> r
  
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    mutate(signsum = rollapply(mablsign, 9, sum, na.rm=T, align="left", fill=NA)) -> r

  # if we have more than eight consecutive increases of average root length, we assume growth has started
  r$growing <- NA
  r$growing[r$signsum > 8] <- TRUE

  # if root starts to grow, it is considered to be growing for the remaining datapoints
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    mutate(growing = na.locf(growing, na.rm=F)) -> r
  
  # remove timepoints before growth starts
  r %>% filter(growing==TRUE) -> r
  
  # construct a normalized elapsed time value based on root growth start
  r %>% group_by(UID) %>% 
    mutate(normtime = elapsed - elapsed[1], dbg=elapsed[1]) -> r

  # identify plateaus:
  # if there is exactly zero growth for 7 consecutive timepoints, it is a plateau
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    mutate(still=rollapply(mablsign, 7, function(x) { return(all(x == 0)) }, align="left", fill=NA)) -> r
  #truncate after plateau detected
  r$still[which(r$still == FALSE)] <- NA
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    mutate(still=na.locf(still, na.rm=F)) -> r
  r$still[which(is.na(r$still))] <- FALSE
  r %>% filter(still!=TRUE) -> r

  # mark big jumps (length increase > 0.5 cm)
  r$jump <- NA
  r$jump[abs(r$delta) > 0.5] <- TRUE
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    mutate(jump = na.locf(jump, na.rm=F)) -> r
  r$jump[which(is.na(r$jump))]<-FALSE
  r %>% filter(jump!=TRUE) -> r
  
  # find roots which "start growing" when they are really long and remove them
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    summarize(startlength=Length[1]) ->> startlengths
  
  toolong <<- startlengths[startlengths$startlength>1,]
  if(length(toolong$UID) > 0) {
    r %>% filter(! UID %in% toolong$UID) -> r
  }

  return(r)
}

dir <- choose_dir()

resultsdir <- paste0(dir, '/Results')
outdir <- paste0(resultsdir, '/Root Growth')
rundir <- paste0(outdir, '/Pre-analysis')
if (!dir.exists(rundir)) {
  dir.create(rundir)
}

# get all .tsv files in the directory
files <- list.files(path = outdir, pattern = ' rootgrowthmeasurement.tsv$', full.names = TRUE, recursive = TRUE, ignore.case = TRUE, no.. = TRUE)

if (length(files) < 1) {
  cat("No suitable root analysis results files found in that directory.\n")
  stop()
}

allout <- NULL

d <- unlist(strsplit(dir, '/', fixed=T))
expname <- d[length(d)]
cat(paste0("Performing root growth QC for experiment << ", expname, " >>\n\n"))

cat("Processing files, please wait...\n")

for (f in files) {
  # clean up file
  out <- processfile(f, expname)
  allout <- rbind(allout, out)
  
  # plot unpropcessed data
  d <- dirname(f)
  dirparams <- unlist(strsplit(d, '/', fixed=T))
  GID <- paste0(dirparams[length(dirparams)-1], '_', dirparams[length(dirparams)])
  ggsave(plotfile(f), filename=paste0(rundir, '/', GID, '_preQC.pdf'), width=25, height=15, units='cm')
  
  # plot processed data
  p <- ggplot(out, aes(x=elapsed, y=Length, color=UID, group=UID)) + 
    geom_point() +
    geom_line() +
    labs(title=paste0("Processed graph for ", GID), x="Elapsed time (h)", y="Root length (cm)")
  ggsave(p, filename=paste0(rundir, '/', GID, '_postQC.pdf'), width=25, height=15, units='cm')
  p <- ggplot(out, aes(x=normtime, y=Length, color=UID, group=UID)) + 
    geom_point() +
    geom_line() +
    labs(title=paste0("Processed graph for ", GID), x="Relative elapsed time (h)", y="Root length (cm)")
  ggsave(p, filename=paste0(rundir, '/', GID, '_postQC_normalized.pdf'), width=25, height=15, units='cm')
}

allout %>% arrange(GID, UID, normtime) %>% 
  select(c(UID, GID, elapsed, normtime, Length, date)) -> allout

names(allout)[2] <- 'Group'
names(allout)[3] <- 'ElapsedHours'
names(allout)[4] <- 'RelativeElapsedHours'
names(allout)[5] <- 'PrimaryRootLength'
names(allout)[6] <- 'Date'

write.table(allout, file=paste0(outdir, "/rootgrowth.postQC.tsv"), sep='\t', row.names=FALSE)
cat(paste0("Output saved to ", outdir, "/rootgrowth.postQC.tsv", 
           ". Adjust groups and remove problematic seedlings from this file, then run process_rootgrowth_data.R.\n"))
cat(paste0("Graphs are available for each group in the directory ", rundir, "\n"))
