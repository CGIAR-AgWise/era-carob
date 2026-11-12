source("script/era_carob.R")
source("script/era_carob_merge.R")
source("audit/verify.R")
source("script/era_carob_report.R")
# Replace the last usable build only after serialisation succeeds.
candidate <- tempfile(tmpdir=cache)
saveRDS(merged,candidate)
stopifnot(file.rename(candidate,file.path(cache,"sf001-review.rds")))
