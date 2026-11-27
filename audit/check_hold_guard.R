# Exercise the real corrected candidate through the climate CLI without weather extraction.
args <- commandArgs(TRUE)
if (length(args)!=1L) stop("Usage: Rscript audit/check_hold_guard.R issue94-candidate.rds")
library(data.table)
candidate <- readRDS(args[1])
holds <- attr(candidate,"era_date_holds")
held_rows <- as.integer(holds$merged_row[holds$table=="Data.Out"])
eligible <- candidate[source=="era" & !is.na(planting_date) &
                        is.finite(latitude) & is.finite(longitude) &
                        abs(latitude)<=90 & abs(longitude)<=180 & (latitude!=0 | longitude!=0)]
held <- eligible[source_row %in% held_rows][1]
clear <- eligible[!source_row %in% held_rows][1]
stopifnot(!is.na(held$source_row),!is.na(clear$source_row))
# Only the two selected outcomes enter this synthetic handoff; retain the full
# original ledger and pin metadata, including holds on other tables/outcomes.
m <- rbind(held,clear)
attr(m,"input_archives") <- attr(candidate,"input_archives")
attr(m,"era_date_holds") <- holds
dir <- tempfile(); dir.create(dir)
paths <- file.path(dir,c("candidate.rds","climate.csv","rules.csv","coverage.csv"))
fwrite(data.table(variable="rain",units="mm",provider_version="synthetic-test",
                  start_anchor="planting",start_days=0L,end_anchor="planting",end_days=0L),paths[3])
check <- function(x,row) {
  saveRDS(x,paths[1])
  fwrite(row[,.(source,source_row,latitude,longitude,planting_date,
                window_start=planting_date,window_end=planting_date,
                variable="rain",units="mm",value=1,grid_id="synthetic-test",provider_version="synthetic-test")],paths[2])
  system2("Rscript",c("audit/check_climate.R",shQuote(paths)),stdout=FALSE,stderr=FALSE)
}
stopifnot(check(m,held)!=0L,check(m,clear)==0L)
lost <- copy(m); attr(lost,"input_archives") <- NULL; attr(lost,"era_date_holds") <- NULL
stopifnot(check(lost,held)!=0L,check(lost,clear)!=0L)
for (bad in list(holds[0],holds[-1],copy(holds)[1,status:="resolved"])) {
  changed <- copy(m); attr(changed,"era_date_holds") <- bad
  stopifnot(check(changed,held)!=0L,check(changed,clear)!=0L)
}
reordered <- copy(m); attr(reordered,"era_date_holds") <- holds[rev(seq_len(nrow(holds)))]
stopifnot(check(reordered,held)!=0L,check(reordered,clear)==0L)
cat("Real held ERA row",held$source_row,"blocked; unheld row",clear$source_row,"accepted.\n")
cat("Missing, empty, truncated and altered ledger metadata rejected; reordering preserves checks.\n")
unlink(dir,recursive=TRUE)
