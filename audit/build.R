source("script/pinned.R")
if (system2("python3", c("audit/prepare.py", shQuote(cache), "--verify-only")) != 0L)
  stop("Prepare and verify the selected input cache before building")
prepared <- jsonlite::fromJSON(file.path(cache,"prepared-inputs.json"),simplifyVector=FALSE)
source("script/era_carob.R")
source("script/era_carob_merge.R")
source("script/date_holds.R")
attr(merged,"input_archives") <- prepared$archives
if (any(grepl("issue94",names(prepared$archives)))) {
  holds <- data.table::fread(one_input("issue94-date-holds.csv"),colClasses="character",na.strings="")
  validate_date_holds(holds,era_merge)
  attr(merged,"era_date_holds") <- holds
}
source("audit/verify.R")
source("script/era_carob_report.R")
# Replace the last usable build only after serialisation succeeds.
candidate <- tempfile(tmpdir=cache)
saveRDS(merged,candidate)
stopifnot(file.rename(candidate,file.path(cache,"sf001-review.rds")))
