# Run from the repository root after audit/build.R. SF001_INPUTS points to the prepared archives.
library(openxlsx)
source("script/pinned.R")

carob_fields <- names(data.table::fread(one_input("carob_agronomy-cc.csv"), nrows = 0L))
candidate <- readRDS(file.path(cache, "sf001-review.rds"))
catalogue <- read.csv("script/era_field_sources.csv", stringsAsFactors = FALSE, na.strings = "")
stopifnot(!anyDuplicated(carob_fields), !anyDuplicated(names(candidate)),
          !anyDuplicated(catalogue$field), all(carob_fields %in% names(candidate)))

present <- function(x) !is.na(x) & (if (is.character(x)) nzchar(trimws(x)) else TRUE)
count_source <- function(x, source) sum(present(x[candidate$source == source]))
extension_fields <- setdiff(names(candidate), carob_fields)
fields <- c(carob_fields, extension_fields)
ids <- match(fields, catalogue$field)
era_counts <- vapply(fields, function(f) count_source(candidate[[f]], "era"), integer(1))
carob_counts <- vapply(fields, function(f) count_source(candidate[[f]], "carob"), integer(1))
unknown <- fields[is.na(ids) & (era_counts > 0 | fields %in% extension_fields)]
if (length(unknown)) stop("Document source fields in script/era_field_sources.csv: ", paste(unknown, collapse = ", "))

mapping <- data.frame(
  carob_variable = fields, era_table = catalogue$era_table[ids],
  era_variable = catalogue$era_variable[ids],
  mapping_status = ifelse(is.na(ids), "No ERA mapping", ifelse(era_counts > 0, "Mapped", "Mapped, no values")),
  notes = catalogue$notes[ids], era_rows_present = unname(era_counts),
  carob_rows_present = unname(carob_counts), check.names = FALSE
)
# The terms file comes from the same pinned ZIP as the wide header.
terms_file <- unz(one_input("carob_agronomy-cc.zip"), "carob_agronomy_terms.csv")
terms <- read.csv(terms_file, stringsAsFactors = FALSE, na.strings = "")
# The archive lists two unit spellings for soil_CEC; retain both verbatim.
collapse_terms <- function(values) paste(unique(values[!is.na(values)]), collapse = " / ")
terms <- aggregate(terms[c("unit","description")], list(name = terms$name), collapse_terms)
index <- match(fields, terms$name)
mapping$carob_unit <- terms$unit[index]
mapping$carob_definition <- terms$description[index]
mapping$notes[fields == "soil_N"] <- "ERA Soil Nitrogen leaves the extractable fraction unspecified. Its outcome name, value and unit remain in the raw fields."
mapping$notes[fields == "rain"] <- "ERA site mean annual precipitation is retained separately as era_site_map_raw."
mapping$notes[fields == "rep"] <- "ERA replication counts are retained in era_n_replicates and the two raw replication fields."
wb <- createWorkbook(creator = "ERA–Carob")
header <- createStyle(fontColour = "#FFFFFF", fgFill = "#2d6a4f", halign = "LEFT", textDecoration = "Bold")
write_mapping <- function(title, data) {
  addWorksheet(wb, title)
  writeData(wb, title, data, headerStyle = header, withFilter = TRUE)
  freezePane(wb, title, firstRow = TRUE, firstCol = TRUE)
  setColWidths(wb, title, cols = 1:9, widths = c(29, 24, 54, 23, 70, 21, 21, 18, 80))
  colors <- c("Mapped" = "#d8f3dc", "Mapped, no values" = "#fff3b0", "No ERA mapping" = "#ffd6d6")
  for (status in names(colors)) {
    rows <- which(data$mapping_status == status) + 1L
    if (length(rows)) addStyle(wb, title, createStyle(fgFill = colors[[status]]), rows = rows, cols = 4)
  }
}
write_mapping("ERA-Carob Mapping", mapping[seq_along(carob_fields), ])
extensions <- mapping[mapping$carob_variable %in% extension_fields, ]
names(extensions)[1] <- "candidate_variable"
write_mapping("Candidate fields", extensions)
addWorksheet(wb, "Legend")
legend <- data.frame(
  item = c("ERA-Carob Mapping", "Candidate fields", "Source vocabulary", "Mapped", "Mapped, no values",
           "No ERA mapping", "Rows present", "Source tables"),
  meaning = c("Original fields of the pinned Carob agronomy wide CSV, in source order.",
              "Additional output fields for provenance and review.",
              "ERA Agronomy bundle, 12 May 2025. Archive URLs and SHA-256 are in audit/inputs.json.",
              "ERA source field has a documented mapping and at least one populated output row.",
              "The mapping is documented but the current candidate has zero populated ERA rows.",
              "No ERA mapping is documented for this field in the candidate.",
              "Number of retained rows with a populated value, including zero and FALSE. Counts do not assess model fitness.",
              "Data.Out denotes the compiled ERA outcome table. Lookup table names indicate attributes attached by the transformation.")
)
writeData(wb, "Legend", legend, headerStyle = header)
setColWidths(wb, "Legend", 1:2, c(28, 118))
path <- "report/era_carob_mapping.xlsx"
dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
saveWorkbook(wb, path, overwrite = TRUE)
stopifnot(identical(read.xlsx(path, sheet = 1, cols = 1)[[1]], carob_fields),
          identical(read.xlsx(path, sheet = 2, cols = 1)[[1]], extension_fields))
message("Wrote ", length(carob_fields), " Carob fields and ", length(extension_fields), " candidate fields to ", path)
