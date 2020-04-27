# common.R -
# some functions common to other scripts


spiro_common_included <- function() {
  return(TRUE)
}

choose_dir <- function() {
  # there is no support for directory picker under non-windows platforms
  if (.Platform$OS.type == 'unix') {
    dir <- readline(prompt = "Enter directory: ")
  } else {
    dir <- choose.dir(getwd(), "Choose folder to process")
  }
  return(dir)
}

