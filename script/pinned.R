cache <- Sys.getenv("SF001_INPUTS", "downloaded_data/sf001")
one_input <- function(pattern) {
  f <- Sys.glob(file.path(cache,pattern))
  stopifnot(length(f)==1L)
  f
}
bindr <- function(...) as.data.frame(dplyr::bind_rows(...))
fix_name <- function(x,case="") {
  x <- trimws(gsub("[[:space:]]+"," ",x)); x[x==""] <- NA_character_
  if (case=="title") stringr::str_to_title(x) else x
}
