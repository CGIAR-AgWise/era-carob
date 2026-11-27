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

date_hold_fingerprint <- function(holds) {
  columns <- c("table", "field", "source_row", "merged_row", "B.Code", "raw", "date", "status")
  if (!is.data.frame(holds) || !setequal(names(holds), columns) ||
      anyDuplicated(names(holds)) || !all(vapply(holds, is.character, logical(1))))
    stop("Source-date hold ledger has an invalid schema")
  holds <- as.data.frame(holds)
  keys <- c("table", "field", "merged_row")
  if (anyNA(holds[keys]) || anyDuplicated(as.data.frame(holds)[keys]))
    stop("Source-date hold ledger has missing or duplicate keys")
  rows <- order(holds$table, holds$merged_row, holds$field, method="radix")
  # Versioned, locale-independent encoding: fixed column order, sorted rows,
  # UTF-8 byte lengths, and -1: for NA (distinct from an empty string).
  parts <- unlist(lapply(columns, function(field) {
    value <- enc2utf8(holds[[field]][rows])
    ifelse(is.na(value), "-1:", paste0(nchar(value, type="bytes"), ":", value))
  }), use.names=FALSE)
  digest::digest(paste0("era-date-holds-v1\n", nrow(holds), "\n",
                        paste0(parts, collapse="")), algo="sha256", serialize=FALSE)
}

validate_date_hold_ledger <- function(holds, contract) {
  if (is.null(holds) || !is.data.frame(holds) || nrow(holds) != contract$rows ||
      !identical(date_hold_fingerprint(holds), contract$canonical_sha256))
    stop("Source-date holds are missing, incomplete or changed for the pinned input")
  invisible(TRUE)
}

check_climate_date_holds <- function(candidate, proposed) {
  if (!any(proposed$source == "era")) return(invisible(TRUE))
  holds <- attr(candidate,"era_date_holds")
  pins <- attr(candidate,"input_archives")
  current <- jsonlite::fromJSON("audit/inputs.json", simplifyVector=FALSE)
  historical <- jsonlite::fromJSON("audit/inputs-historical.json", simplifyVector=FALSE)
  if (identical(pins, current)) {
    contract <- jsonlite::fromJSON("audit/date-holds.json", simplifyVector=FALSE)
    if (!identical(pins[[contract$archive]][[2]], contract$archive_sha256))
      stop("Source-date hold contract does not match the current input pin")
    validate_date_hold_ledger(holds, contract)
  } else if (!identical(pins, historical)) {
    stop("ERA climate handoff requires recognized input archive provenance")
  } else if (!is.null(holds)) {
    stop("Historical input has an unexpected source-date hold ledger")
  }
  if (!is.null(holds)) {
    held_rows <- as.integer(holds$merged_row[holds$table=="Data.Out"])
    if (any(proposed$source=="era" & proposed$source_row %in% held_rows))
      stop("Climate handoff uses an ERA outcome with unresolved source-date holds")
  }
  invisible(TRUE)
}
