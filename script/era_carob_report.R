# Run after the pinned merge. Summary counts do not infer cross-source trial identity.
stopifnot(exists("merged"))
known <- function(x) !is.na(x) & nzchar(trimws(as.character(x)))
coverage <- merged[, .(wide_rows=.N, datasets=data.table::uniqueN(dataset_id[known(dataset_id)]),
                       identified_trials=data.table::uniqueN(.SD[known(dataset_id) & known(trial_id),.(dataset_id,trial_id)]),
                       identified_trial_rows=sum(known(trial_id)), resolved_products=data.table::uniqueN(crop[known(crop)]),
                       numeric_yield_rows=sum(is.finite(as.numeric(yield)))), by=source]
data.table::fwrite(coverage,"report/audit/current_coverage.csv")
keys <- merged[!is.na(crop) & nzchar(crop),.(era=any(source=="era"),carob=any(source=="carob")),by=crop]
data.table::fwrite(keys[order(crop)],"report/audit/current_products.csv")
# Reconcile retained source labels against the vocabulary used in this build.
labels <- merged[,.(rows=.N),by=.(source,crop_raw,crop)]
data.table::fwrite(labels[order(source,crop_raw)],"report/audit/current_crop_labels.csv")
e <- merged[source=="era"]
holds <- attr(merged,"era_date_holds")
date_fields <- c("planting_date","planting_date_raw","transplanting_date","harvest_date")
dates <- list(input_archives=attr(merged,"input_archives"),
              era_rows=nrow(e),carob_rows=nrow(merged[source=="carob"]),
              populated=lapply(setNames(date_fields,date_fields),function(f) sum(known(e[[f]]))),
              screened_raw_planting_dates=sum(known(e$planting_date_raw) & !known(e$planting_date)),
              accepted_dates_missing_coordinates=sum(known(e$planting_date) & (is.na(e$latitude)|is.na(e$longitude))),
              hold_field_findings=if (is.null(holds)) 0L else nrow(holds),
              accepted_planting_dates_on_held_outcomes=if (is.null(holds)) 0L else
                sum(known(e$planting_date) & e$source_row %in% as.integer(holds$merged_row[holds$table=="Data.Out"])),
              holds_by_status=if (is.null(holds)) list() else as.list(table(holds$status)),
              climate_validation="pending; date counts do not establish climate or model readiness")
jsonlite::write_json(dates,"report/audit/date_snapshot.json",auto_unbox=TRUE,pretty=TRUE)
