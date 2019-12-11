# cleanup_rootgrowth_data.R -
#
#   imports data from root growth macro and cleans it up a bit.
#   after running this script, adjust the groups in the file output.tsv, 
#   then run process_rootgrowth_data.R to get statistics.

# pixel_radius is the distance from primary coords that determine whether a branch is a primary root
pixel_radius <- 15

library(dplyr)
library(zoo)
library(ggplot2)

# debug stuff:
rawfile <- step1 <- step2 <- step3 <- step4 <- step5 <- NULL

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
  b <- basename(file)
  GID <- paste0(unlist(strsplit(b, ' ', fixed=TRUE))[1], '_', unlist(strsplit(b, ' ', fixed=TRUE))[2])
  r$GID <- GID
  unlist(strsplit(r$Slice.name, '-', fixed=TRUE)) -> params
  r$date <- as.POSIXct(strptime(paste0(params[seq(2, length(params), 4)], params[seq(3, length(params), 4)]), format='%Y%m%d%H%M%S'))
  r$PR <- FALSE
  r$UID <- paste0(GID, '_', r$ROI)
  rawfile <<- r
  slices <- unique(r$Slice.no.)
  
  # add elapsed times
  r %>% group_by(UID) %>%
    arrange(date) %>%
    mutate(elapsed=elapsed(date[1], date)) -> r
  
  # check if root coords match primary x/y and set PR variable accordingly
  r$PR[abs(r$ROI.mid.X - r$V1.x) < pixel_radius & 5 + r$V1.y < pixel_radius] <- TRUE
  r$PR[abs(r$ROI.mid.X - r$V2.x) < pixel_radius & 5 + r$V2.y < pixel_radius] <- TRUE

  # the entire skeleton is a PR if any branch is a PR
  r %>% group_by(UID, elapsed, Skeleton.ID) %>%
    mutate(PR = max(PR)) -> r
  
  # remove non-primary roots
  r %>% filter(PR == TRUE) -> r
  
  # out of roi detection
  r$outofroi <- FALSE
  r$outofroi[which(r$V1.y >= r$ROI.full.Y - 5 | r$V2.y >= r$ROI.full.Y - 5)] <- TRUE
  r$outofroi[which(r$V1.x <= 5 | r$V2.x <= 5)] <- TRUE
  r$outofroi[which(r$V1.x >= 2*r$ROI.mid.X - 5 | r$V2.x >= 2*r$ROI.mid.X - 5)] <- TRUE
  
  # the entire skeleton is out of ROI if any part of it is
  r %>% group_by(UID, elapsed, Skeleton.ID) %>%
    mutate(outofroi = max(outofroi)) -> r
  
  dbg1 <<- r
  
  # remove skeletons that go out of the roi
  # r %>% filter(outofroi != TRUE) -> r

  dbg2 <<- r
  
  # summarize skeleton lengths
  r %>% group_by(UID, elapsed, Skeleton.ID) %>%
    mutate(Branch.length=sum(Branch.length), outofroi=max(outofroi)) %>%
    slice(1) -> r

  dbg3 <<- r
  
  # keep only the longest skeleton
  r %>% group_by(UID, elapsed) %>%
    arrange(desc(Branch.length)) %>%
    slice(1) -> r

  dbg4 <<- r

  # r$outofroi[which(r$PR == FALSE)] <- NA
  # 
  # remove non-PR's
  # r <- r[r$PR == TRUE,]
  
  # tst <<- r %>% arrange(elapsed) %>% group_by(UID, elapsed) %>% summarize(Branch.length = sum(Branch.length))
  # 
  # step1 <<- r
  # 
  # r$Branch.length[which(r$outofroi == TRUE)] <- NA
  # 
  # step2 <<- r
  # 
  # r %>% filter(PR == TRUE) %>%
  #   group_by(UID, date) %>%
  #   summarize(Branches = n(), GID = GID[1], 
  #             Skeletons = length(unique(Skeleton.ID)), 
  #             Branch.length = sum(Branch.length), 
  #             elapsed=elapsed[1],
  #             SliceNo = Slice.no.[1]) -> r
  
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
    mutate(signsum = rollapply(mablsign, 9, sum, na.rm=T, align="left", fill=NA)) -> r
  
  # if we have more than eight consecutive increases of average root length, we assume growth has started
  r$growing <- NA
  r$growing[r$signsum > 8] <- TRUE
  
  # if root starts to grow, it is considered to be growing for the remaining datapoints
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    mutate(growing = na.locf(growing, na.rm=F)) -> r
  
  step3 <<- r
  
  # remove timepoints before root growth start
  r %>% group_by(UID) %>%
    filter(growing == TRUE) -> r
  
  # construct a normalized elapsed time value based on root growth start
  r %>% group_by(UID) %>% 
    mutate(normtime = elapsed - elapsed[1], dbg=elapsed[1]) -> r
  
  # # remove data points with several PR's
  # r$Branch.length[r$Skeletons != 1] <- NA

  # calculate branch length with LOCF
  r %>% group_by(UID) %>%
    mutate(Branch.length.locf=na.locf(Branch.length, na.rm=F)) -> r
  
  # difference to previous point
  r$diff <- ave(r$Branch.length.locf, r$UID, FUN=function(x) c(0, diff(x)))
  
  step4 <<- r
  
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

  step5 <<- r

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

if (length(files) < 1) {
  cat("No suitable root analysis results files found in that directory.\n")
  stop()
}

allout <- NULL

cat("Processing files, please wait...\n")

for (f in files) {
  out <- processfile(f)
  allout <- rbind(allout, out)
}

# remove outliers
ostats <- allout %>%
  arrange(elapsed) %>%
  group_by(UID) %>%
  summarize(GID=GID[1], 
            starttime = min(elapsed-normtime),
            firstlength = Branch.length[1],
            n=length(which(!is.na(Branch.length))))

outlieruids <- NULL
for (gid in unique(allout$GID)) {
  # early start times go away
  q <- quantile(ostats$starttime[ostats$GID == gid], probs=c(0.25,0.75), na.rm=T)
  iqr <- abs(q[2] - q[1])
  cutoff <- q[1] - 1.5*iqr
  # get list of uids which have start times that are low outliers
  outlieruids <- c(outlieruids,
                   ostats$UID[which(ostats$starttime < cutoff & ostats$GID == gid)])

  # large early root length
  q <- quantile(ostats$firstlength[ostats$GID == gid], probs=c(0.25,0.75), na.rm=T)
  iqr <- abs(q[2] - q[1])
  cutoff <- q[2] + 1.5*iqr
  outlieruids <- c(outlieruids, 
                   ostats$UID[which(ostats$firstlength > cutoff & ostats$GID == gid)])

  # low number of measurements for root length
  q <- quantile(ostats$n[ostats$GID == gid], probs=c(0.25,0.75), na.rm=T)
  iqr <- abs(q[2] - q[1])
  cutoff <- q[1] - 1.5*iqr
  outlieruids <- c(outlieruids, 
                   ostats$UID[which(ostats$n < cutoff & ostats$GID == gid)])
}
outlieruids <- unique(outlieruids)
cat(paste0("Removing ", paste0(outlieruids), '\n'))
allout <- allout %>% filter(! UID %in% outlieruids)

allout.backup <- allout
# remove parts of the graph where coverage is very low (<3 individual seedlings)
# bin the data into 25 separate bins according to normalized time
allout <- allout%>% group_by(GID) %>% mutate(bin = ntile(normtime, 25))
# remove all NA values before counting
allout %>% filter(!is.na(Branch.length)) -> allout.filt
# count unique seedlings per bin
allout.filt %>% group_by(GID, bin) %>% summarize(n_obs=n_distinct(UID)) -> binstats
# now remove everything with less than 3 unique seedlings
sparse_bins <- binstats[binstats$n_obs < 3,]
if (length(sparse_bins$bin) > 1) {
  for (i in 1:length(sparse_bins$bin)) {
    allout$Branch.length[allout$GID == sparse_bins$GID[i] & allout$bin == sparse_bins$bin[i]] <- NA
  }
}

for (gid in unique(allout$GID)) {
  p <- ggplot(allout[allout$GID == gid,], aes(x=elapsed, y=Branch.length, color=UID, group=UID)) +
    geom_point(alpha=.5, size=.5) +
    geom_line() +
    labs(x="Time (h)", 
         y="Primary root length (cm)",
         title=paste0("Per-seedling graph for group ", gid))
  suppressWarnings(ggsave(p, filename=paste0(outdir, "/preanalysis.rootgrowth-", gid, ".pdf"), width=25, height=15, units='cm'))

  p <- ggplot(allout[allout$GID == gid,], aes(x=normtime, y=Branch.length, color=UID, group=UID)) +
    geom_point(alpha=.5, size=.5) +
    geom_line() +
    labs(x="Time since root emergence (h)", 
         y="Primary root length (cm)",
         title=paste0("Per-seedling graph for group ", gid))
  suppressWarnings(ggsave(p, filename=paste0(outdir, "/preanalysis.rootgrowth-normalized-", gid, ".pdf"), width=25, height=15, units='cm'))
}

dbg.a <- allout

allout %>% arrange(GID, UID, normtime) %>% 
#  select(-c(dbg, diff, growing, signsum, mablsign, mablleft, mablright, mabldelta, absdelta, signdelta, delta)) -> allout
  select(c(UID, GID, elapsed, normtime, Branch.length, date)) -> allout

names(allout)[2] <- 'Group'
names(allout)[3] <- 'ElapsedHours'
names(allout)[4] <- 'RelativeElapsedHours'
names(allout)[5] <- 'PrimaryRootLength'
names(allout)[6] <- 'Date'

write.table(allout, file=paste0(outdir, "/rootgrowth.postQC.tsv"), sep='\t', row.names=FALSE)
cat(paste0("Output saved to ", outdir, "/rootgrowth.postQC.tsv", 
           ". Adjust groups and remove problematic seedlings from this file, then run process_rootgrowth_data.R.\n"))
