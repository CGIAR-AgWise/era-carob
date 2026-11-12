# Run in the same R session as era_carob.R. No publication-level row deletion.
source("script/pinned.R")
carob <- data.table::fread(one_input("carob_agronomy-cc.csv"), data.table=FALSE,
                          na.strings=c("", "NA"), colClasses=c(dataset_id="character"))
stopifnot(!anyDuplicated(names(carob)),!anyDuplicated(names(dwf)),!anyDuplicated(dwf$era_source_row))
# Keep a source-scoped archive row ordinal; preserve Carob's own record and trial IDs.
carob$source_row <- seq_len(nrow(carob))
dwf$source_row <- dwf$era_source_row
carob$crop_raw <- carob$crop
carob_crosswalk <- current_crop_crosswalk(era_master,carob$crop_raw)
carob$crop <- carob_crosswalk[["resolved product"]][match(crop_key(carob$crop_raw), carob_crosswalk[["raw label"]])]
# Preserve suspect planting dates for source checking; exclude them from model fields.
dwf$planting_date_raw <- dwf$planting_date
time <- era_merge$Data.Out$Time[dwf$source_row]
dwf$planting_date <- season_planting_date(dwf$planting_date_raw,time)
common <- intersect(names(carob),names(dwf))
prov <- unique(c("uri","yield_raw","yield_unit_raw","planting_date_raw",era_provenance_cols))
keep <- union(common, intersect(prov,names(dwf)))
crows <- nrow(carob); erows <- nrow(dwf)
# Preserve date precision as text; partial Carob dates cannot be converted to Date.
for (k in names(carob)) if (inherits(carob[[k]],"Date")) carob[[k]] <- as.character(carob[[k]])
merged <- data.table::rbindlist(list(carob=carob,era=dwf[keep]),use.names=TRUE,fill=TRUE,idcol="source")
stopifnot(nrow(merged)==crows+erows,!anyDuplicated(merged[,.(source,source_row)]))
