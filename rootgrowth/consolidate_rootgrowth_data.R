# consolidate_rootgrowth_data.R -

library(dplyr)
library(ggplot2)
library(zoo)

# return elapsed time in hours from two datetime strings
elapsed <- function(from, to) {
  f <- strptime(from, format="%Y-%m-%d %H:%M:%S")
  t <- strptime(to, format="%Y-%m-%d %H:%M:%S")
  return(as.numeric(difftime(t, f, units='hours')))
}

processfile <- function(file) {
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
  
  # mark big jumps (length increase > 1 cm)
  r$jump <- NA
  r$jump[abs(r$delta) > 1] <- TRUE
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    mutate(jump = na.locf(jump, na.rm=F)) -> r
  r$jump[which(is.na(r$jump))]<-FALSE
  r %>% filter(jump!=TRUE) -> r
  
  # find roots which start growing when they are really long and remove them
  r %>% arrange(elapsed) %>%
    group_by(UID) %>%
    summarize(startlength=Length[1]) ->> startlengths
  
  toolong <<- startlengths[startlengths$startlength>1,]
  if(length(toolong$UID) > 0) {
    r %>% filter(! UID %in% toolong$UID) -> r
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
outdir <- paste0(resultsdir, '/Root Growth')

# get all .tsv files in the directory
files <- list.files(path = outdir, pattern = ' rootgrowthmeasurement.tsv$', full.names = TRUE, recursive = TRUE, ignore.case = TRUE, no.. = TRUE)

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

# example of how to plot all groups:
ggplot(allout, aes(x=elapsed, y=Length, color=UID, group=UID)) + 
  geom_point() + 
  geom_line() + 
  facet_wrap(~GID) + 
  theme(legend.position="none")

# example of how to plot a single group:
ggplot(allout[allout$GID=='plate2PE_1',], aes(x=elapsed, y=Length, color=UID, group=UID)) + 
  geom_point() + 
  geom_line()

# example of how to plot a single seedling:
ggplot(allout[allout$UID=='plate2PE_1_24',], aes(x=elapsed, y=Length, color=UID, group=UID)) + 
  geom_point() + 
  geom_line()
