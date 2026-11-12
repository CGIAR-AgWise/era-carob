# Run in the session that built merged, so checks inspect data, not only reports.
stopifnot(!anyDuplicated(merged[,.(source,source_row)]))
e <- merged[source=="era"]; c <- merged[source=="carob"]
orig <- era_merge$Data.Out[e$source_row,]
stopifnot(all(e$dataset_id==orig$B.Code),identical(as.character(e$crop_raw),as.character(orig$P.Product)),
          nrow(e)==110277L,nrow(c)==246993L, nrow(merged)==357270L,
          all(is.na(e$trial_id)),sum(!is.na(e$yield))==42283L,
          all(is.na(e$planting_date)), all(is.na(e$yield) | e$yield>=0))
# Joining duplicated or unknown keys must not multiply rows or transfer information.
x <- data.frame(era_source_row=1:4,k=c(1L,2L,3L,NA))
y <- data.frame(k=c(1L,2L,2L,NA),v=c(5,6,7,8))
z <- safe_lookup(x,y,"k")
stopifnot(identical(z$v,c(5,NA_real_,NA_real_,NA_real_)))
s <- jsonlite::fromJSON("report/audit/summary.json")
stopifnot(all(s$raw==c(678,54,33)),all(s$resolved==c(133,57,6)),
          s$era_rows==244041,s$merged==491034,s$doi_edges==21,s$doi_studies==14)
print("Pinned data, joins, yields, crop sets, provenance and count checks passed.")
