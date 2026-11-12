# Regression checks only for the May 2025 ERA and June 2026 Carob inputs.
library(data.table)
args <- commandArgs(TRUE)
if (length(args)!=1L) stop("Usage: Rscript audit/check_snapshot.R path/to/sf001-review.rds")
m <- as.data.table(readRDS(args[1]))
e <- m[source=="era"]
crows <- m[source=="carob"]
crop_set <- function(x) unique(x[!is.na(x) & nzchar(x)])
ec <- crop_set(e$crop)
cc <- crop_set(crows$crop)
sets <- c(length(setdiff(ec,cc)),length(intersect(ec,cc)),length(setdiff(cc,ec)))
stopifnot(nrow(e)==110277L,nrow(crows)==246993L,nrow(m)==357270L,
          all(is.na(e$trial_id)),sum(!is.na(e$yield))==42283L,all(is.na(e$planting_date)),
          all(sets==c(98L,52L,11L)))
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
