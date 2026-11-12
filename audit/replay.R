# From repository root after prepare.py. Run in a clean R session.
library(dplyr)
library(tidyr)
cache <- normalizePath(commandArgs(TRUE)[1], mustWork=TRUE)
stopifnot(!is.na(Sys.setlocale("LC_COLLATE","C")))
ref <- "81eef14c11437bddf8bb5914436e4525b45c6cce"
helper <- "a366c29ba1cdcf7e184299cbeabdc4f762bcb26c"
for (f in c("fix_name.R","utils.R")) {
  dest <- tempfile()
  download.file(sprintf("https://raw.githubusercontent.com/carob-data/carobiner/%s/R/%s", helper,f),dest,quiet=TRUE)
  source(dest)
}
era_merge <- jsonlite::fromJSON(Sys.glob(file.path(cache,"agronomic_*.json")))
s <- system2("git", c("show", paste0(ref,":script/era_carob.R")),stdout=TRUE)
s <- s[which(startsWith(s,"### Baseline data")):length(s)]
# Call the same two pinned carobiner functions, without installing the entire package.
s <- gsub("carobiner::", "",s,fixed=TRUE)
steps <- list()
merge <- function(x,y,by,...) {
  z <- base::merge(x,y,by=by,...)
  steps[[length(steps)+1L]] <<- data.frame(input=nrow(x), lookup=NROW(as.data.frame(y)), output=nrow(z), keys=paste(by,collapse="|"))
  z
}
eval(parse(text=s))
write.csv(do.call(rbind,steps),"report/audit/historical_joins.csv",row.names=FALSE)
saveRDS(dwf,file.path(cache,"june.rds"))
