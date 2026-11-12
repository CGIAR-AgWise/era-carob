# The published workbook must keep the source schema, candidate provenance and units distinct.
path <- "report/era_carob_mapping.xlsx"
sheets <- openxlsx::getSheetNames(path)
stopifnot(identical(sheets, c("ERA-Carob Mapping", "Candidate fields", "Legend")))
schema <- openxlsx::read.xlsx(path, sheet = 1)
extra <- openxlsx::read.xlsx(path, sheet = 2)
field <- function(table, key) {
  rows <- which(table[[1]] == key)
  stopifnot(length(rows) == 1L)
  table[rows, , drop = FALSE]
}
stopifnot(nrow(schema) == 320L, !anyDuplicated(schema[[1]]),
          !any(extra[[1]] %in% schema[[1]]),
          field(schema, "yield")$carob_unit == "kg/ha",
          field(schema, "rain")$era_rows_present == 0L,
          field(schema, "rep")$era_rows_present == 0L,
          field(schema, "soil_N")$mapping_status == "No ERA mapping",
          field(schema, "soil_N")$era_rows_present == 0L,
          field(schema, "soil_N_total")$era_rows_present > 0L,
          field(extra, "era_site_map_raw")$era_variable == "Site.MAP",
          field(extra, "era_n_replicates")$era_rows_present > 0L)
