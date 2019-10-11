# cleanup_rootgrowth_data.R -
#
#   imports data from root growth macro and cleans it up a bit.
#   after running this script, adjust the groups in the file output.tsv, 
#   then run process_rootgrowth_data.R to get statistics.

# pixel_radius is the distance from primary coords that determine whether a branch is a primary root
pixel_radius <- 5

library(dplyr)
library(zoo)
library(ggplot2)

# debug stuff:
rawfile <- step1 <- step2 <- step3 <- NULL

# return elapsed time in hours from two datetime strings
elapsed <- function(from, to) {
  f <- strptime(from, format="%Y-%m-%d %H:%M:%S")
  t <- strptime(to, format="%Y-%m-%d %H:%M:%S")
  return(as.numeric(difftime(t, f, units='hours')))
}

# pickymean returns a mean if less than 40% of the values are NA's, otherwise it returns NA
pickymean <- function(vals) {
  if (length(which(is.na(vals))) > 0.4*length(vals)) {
    return(NA)
    } else {
      return(mean(vals, na.rm=T))
  }
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

  # the entire skeleton is a PR if any branch is a PR
  r %>% group_by(UID, elapsed, Skeleton.ID) %>%
    mutate(PR = max(PR)) -> r
  
  r$outofroi <- NA
  r$outofroi[which(r$V1.x <= 5 | r$V2.x <= 5)] <- TRUE
  r$outofroi[which(r$V1.y <= 5 | r$V2.y <= 5)] <- TRUE
  r$outofroi[which(r$V1.y >= 2*r$Primary.Y - 5 | r$V2.y >= 2*r$Primary.Y - 5)] <- TRUE
  r$outofroi[which(r$PR == FALSE)] <- NA
  
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    mutate(outofroi = na.locf(outofroi, na.rm=F)) -> r
  
  r$Branch.length[which(r$outofroi == TRUE)] <- NA
  
  r %>% filter(PR == TRUE) %>%
    group_by(UID, date) %>%
    summarize(Branches = n(), GID = GID[1], 
              Skeletons = length(unique(Skeleton.ID)), 
              Branch.length = sum(Branch.length), 
              elapsed=elapsed[1],
              SliceNo = Slice.no.[1]) -> r
  
  r$Branch.length[r$Branch.length < 0.1] <- NA
  
  r %>% mutate(delta = Branch.length - lag(Branch.length),
               signdelta = sign(delta),
               absdelta = abs(delta)) -> r
  
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    mutate(mablright = rollapply(Branch.length, 5, pickymean, align="left", fill=NA),
           mablleft = rollapply(Branch.length, 5, pickymean, align="right", fill=NA),
           mabldelta = mablright - lag(mablright),
           mablsign = sign(mabldelta)) -> r
  
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    mutate(signsum = rollapply(mablsign, 8, sum, na.rm=T, align="left", fill=NA)) -> r
  
  # if we have more than six consecutive increases of average root length, we assume growth has started
  r$growing <- NA
  r$growing[r$signsum > 6] <- TRUE
  
  # if root starts to grow, it is considered to be growing for the remaining datapoints
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    mutate(growing = na.locf(growing, na.rm=F)) -> r
  
  # remove timepoints before root growth start
  r %>% group_by(UID) %>%
    filter(growing == TRUE) -> r
  
  # construct a normalized elapsed time value based on root growth start
  r %>% group_by(UID) %>% 
    mutate(normtime = elapsed - elapsed[1], dbg=elapsed[1]) -> r
  
  # remove data points with several PR's
  r$Branch.length[r$Skeletons != 1] <- NA

  # difference to previous point
  r$diff <- ave(r$Branch.length, r$UID, FUN=function(x) c(0, diff(x)))

  # if an absolute difference of >0.3 cm is detected, remove all following data points
  # it is often caused by another root growing into the roi
  r[which(abs(r$diff) > 0.3),] -> suspects
  if (length(suspects$UID) > 0) {
    suspects %>%
      group_by(UID) %>%
      summarize(elapsed=min(elapsed)) -> suspects
    for (i in seq(1, length(suspects$UID))) {
      s <- suspects[i,]
      r$Branch.length[which(r$UID == s$UID & r$elapsed >= s$elapsed)] <- NA
    }
  }

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

for (gid in unique(allout$GID)) {
  p <- ggplot(allout[allout$GID == gid,], aes(x=elapsed, y=Branch.length, color=UID, group=UID)) +
    geom_point(alpha=.5, size=.5) +
    geom_line() +
    labs(x="Time (h)", 
         y="Primary root length (cm)",
         title=paste0("Per-seedling graph for group ", gid))
  suppressWarnings(ggsave(filename=paste0(outdir, "/preanalysis.rootgrowth-", gid, ".pdf"), width=25, height=15, units='cm'))

  p <- ggplot(allout[allout$GID == gid,], aes(x=normtime, y=Branch.length, color=UID, group=UID)) +
    geom_point(alpha=.5, size=.5) +
    geom_line() +
    labs(x="Time since root emergence (h)", 
         y="Primary root length (cm)",
         title=paste0("Per-seedling graph for group ", gid))
  suppressWarnings(ggsave(filename=paste0(outdir, "/preanalysis.rootgrowth-normalized-", gid, ".pdf"), width=25, height=15, units='cm'))
}

allout %>% arrange(GID, UID, normtime) %>% 
  select(-c(dbg, diff, growing, signsum, mablsign, mablleft, mablright, mabldelta, absdelta, signdelta, delta, Skeletons, Branches)) -> allout

write.table(allout, file=paste0(outdir, "/rootgrowth.postQC.tsv"), sep='\t', row.names=FALSE)
print(paste0("Output saved to ", outdir, "/rootgrowth.postQC.tsv", 
             ". Adjust groups and remove problematic seedlings from this file, then run process_rootgrowth_data.R"))
