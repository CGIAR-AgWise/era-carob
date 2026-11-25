# Holds refer to exact source-table row ordinals, not Carob rows or study joins.
validate_date_holds <- function(holds, source) {
  required <- c("table","field","merged_row","B.Code","raw","date","status")
  stopifnot(all(required %in% names(holds)),
            !anyDuplicated(holds[,c("table","field","merged_row"),with=FALSE]))
  for (i in seq_len(nrow(holds))) {
    h <- holds[i]
    tab <- source[[h$table]]
    row <- suppressWarnings(as.integer(h$merged_row))
    stopifnot(!is.null(tab),h$field %in% names(tab),!is.na(row),row>0L,row<=nrow(tab),
              identical(as.character(tab$B.Code[row]),h$B.Code))
    actual <- as.character(tab[[h$field]][row])
    expected <- h$date
    # Upstream audit formats early Date years without zero padding (5 vs 0005).
    # Compare the same calendar text; never infer a century or edit the hold.
    if (!is.na(expected) && grepl("^[0-9]{1,3}-[0-9]{2}-[0-9]{2}$",expected)) {
      pieces <- strsplit(expected,"-",fixed=TRUE)[[1]]
      expected <- paste(sprintf("%04d",as.integer(pieces[1])),pieces[2],pieces[3],sep="-")
    }
    stopifnot((is.na(actual) && is.na(expected)) || identical(actual,expected))
  }
  invisible(TRUE)
}

check_climate_date_holds <- function(candidate, proposed) {
  holds <- attr(candidate,"era_date_holds")
  pins <- attr(candidate,"input_archives")
  if (any(grepl("issue94",names(pins))) && is.null(holds))
    stop("Corrected snapshot is missing its source-date holds")
  if (!is.null(holds)) {
    held_rows <- as.integer(holds$merged_row[holds$table=="Data.Out"])
    if (any(proposed$source=="era" & proposed$source_row %in% held_rows))
      stop("Climate handoff uses an ERA outcome with unresolved source-date holds")
  }
  invisible(TRUE)
}
