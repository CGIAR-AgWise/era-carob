# Dataset-independent checks for every build.
stopifnot(!anyDuplicated(merged[,.(source,source_row)]))
era_check <- merged[source=="era"]
carob_check <- merged[source=="carob"]
original <- era_merge$Data.Out[era_check$source_row,]
stopifnot(identical(era_check$source_row, dwf$era_source_row),
          identical(carob_check$source_row,seq_len(nrow(carob))),
          identical(as.character(era_check$dataset_id),as.character(original$B.Code)),
          identical(as.character(era_check$crop_raw),as.character(original$P.Product)),
          all(is.na(era_check$yield) | (is.finite(era_check$yield) & era_check$yield>=0)))
dated <- !is.na(era_check$planting_date)
stopifnot(all(era_check$planting_date[dated]==era_check$planting_date_raw[dated]))
# Unknown or conflicting keys must never transfer attributes or multiply outcomes.
x <- data.frame(era_source_row=1:4,k=c(1L,2L,3L,NA))
y <- data.frame(k=c(1L,2L,2L,NA),v=c(5,6,7,8))
z <- safe_lookup(x,y,"k")
stopifnot(identical(z$v,c(5,NA_real_,NA_real_,NA_real_)))
cat("Source identity, crop provenance and join checks passed.\n")
