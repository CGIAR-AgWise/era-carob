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
