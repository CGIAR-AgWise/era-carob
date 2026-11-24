# Pin-specific regression checks. Historical expectations remain opt-in.
library(data.table)
args <- commandArgs(TRUE)
if (!length(args) || length(args)>2L) stop("Usage: Rscript audit/check_snapshot.R candidate.rds [issue94|historical]")
profile <- if (length(args)==2L) args[2] else "issue94"
stopifnot(profile %in% c("issue94","historical"))
candidate <- readRDS(args[1])
m <- as.data.table(candidate)
e <- m[source=="era"]
crows <- m[source=="carob"]
crop_set <- function(x) unique(x[!is.na(x) & nzchar(x)])
ec <- crop_set(e$crop)
cc <- crop_set(crows$crop)
sets <- c(length(setdiff(ec,cc)),length(intersect(ec,cc)),length(setdiff(cc,ec)))
stopifnot(nrow(e)==110277L,nrow(crows)==246993L,nrow(m)==357270L,
          all(is.na(e$trial_id)),sum(!is.na(e$yield))==42283L,
          all(sets==c(98L,52L,11L)))
if (profile=="historical") {
  stopifnot(all(is.na(e$planting_date)))
} else {
  pins <- attr(candidate,"input_archives")
  stopifnot(identical(pins[["era_agronomy_bundle_2026-11-23-issue94.tar.gz"]][[2]],
                     "c8cd1eac0f2fa3686519b5cc4f26b7ab72d4bdcc7945caad4944eb9eb376d717"),
            sum(!is.na(e$planting_date))==40655L,
            sum(!is.na(e$planting_date_raw))==70161L)
  holds <- attr(candidate,"era_date_holds")
  stopifnot(!is.null(holds),nrow(holds)==900L,
            sum(holds$status=="unresolved_year")==282L,
            all(is.na(e$planting_date[e$source_row %in% as.integer(holds$merged_row[
              holds$table=="Data.Out" & holds$field=="PD.Plant.Start"])])),
            sum(!is.na(e$planting_date) & e$source_row %in% as.integer(
              holds$merged_row[holds$table=="Data.Out"]))==8L)
  # EO0115 has valid planting dates but held harvest dates; preserve the former
  # while keeping those eight outcomes out of unreviewed climate handoffs.
  source("script/date_holds.R")
  held <- e[source_row %in% as.integer(holds$merged_row[holds$table=="Data.Out"])]
  stopifnot(inherits(try(check_climate_date_holds(candidate,held),silent=TRUE),"try-error"))
}
s <- jsonlite::fromJSON("report/audit/summary.json")
stopifnot(all(s$raw==c(678,54,33)),all(s$resolved==c(133,57,6)),
          s$era_rows==244041,s$merged==491034,s$doi_edges==21,s$doi_studies==14)
cat("Current crop partitions, yield counts and historical replay checks passed.\n")

# Source-linked examples detect dimensional or semantic errors that row counts miss.
soil <- e[dataset_id=="AC0016" & source_row==118L]
taro <- e[dataset_id=="NJ0010" & source_row==80341L]
active <- e[irrigation_method %in% c("drip","flood","sprinkler")]
stopifnot(nrow(soil)==1L, soil$era_unit_raw=="g/kg",isTRUE(all.equal(soil$soil_SOC,0.48)),
          nrow(taro)==1L, taro$yield==6300,taro$yield_part_raw=="Corm (Unspecified)",
          is.na(taro$yield_part),taro$era_n_replicates==3L,is.na(taro$rep),
          nrow(active)>0L, !any(active$irrigated==FALSE,na.rm=TRUE),
          all(is.na(e$rain)),any(!is.na(e$era_site_map_raw)))
cat("Pinned taro, carbon, irrigation, replication and rainfall checks passed.\n")
