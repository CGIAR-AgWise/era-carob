# Reproduce two reviewed contrasts from the 12 May 2025 ERA archive.
# Run from repository root after audit/build.R with the same SF001_INPUTS.
source("script/pinned.R")
source_data <- jsonlite::fromJSON(one_input("agronomic_*.json"))$Data.Out
candidate <- as.data.frame(readRDS(file.path(cache, "sf001-review.rds")))
era <- candidate[candidate$source == "era", ]
stopifnot(!anyDuplicated(era$source_row))

# Within each pair the first ordinal identifies the comparator and the second
# identifies the intervention. Ordinals are specific to the pinned archive.
select_arms <- function(ordinals, study, site, season, doi, labels, unit, scale,
                        error, reps, locator) {
  required <- c("era_data_location", "era_season_raw", "era_outcome_error_raw",
                "era_error_type_raw", "era_control_raw", "era_n_replicates")
  stopifnot(all(required %in% names(era)))
  raw <- source_data[ordinals, ]
  built <- era[match(ordinals, era$source_row), ]
  stopifnot(
    all(raw$B.Code == study), all(raw$Site.ID == site), all(raw$Time == season),
    all(raw$B.DOI == doi), all(raw$P.Product == "Maize"),
    all(raw$Out.Subind == "Crop Yield"), all(raw$Out.Unit == unit),
    identical(raw$T.Name, labels), identical(raw$T.Control, c("Yes", "No")),
    all(raw$ED.Data.Loc == locator), all(raw$EX.Design == "RCBD"),
    all(raw$ED.Error.Type == "SE (Standard Error)"),
    isTRUE(all.equal(as.numeric(raw$ED.Error), error)),
    all(as.numeric(raw$T.Reps) == reps),
    identical(as.integer(built$source_row), as.integer(ordinals)),
    all(built$dataset_id == study), all(built$uri == doi),
    identical(built$treatment, labels), all(built$crop == "maize"),
    all(built$era_data_location == locator),all(built$era_season_raw == season),
    identical(built$era_control_raw,raw$T.Control), all(is.na(built$rep)),
    all(built$era_n_replicates == reps),
    identical(built$era_error_type_raw,raw$ED.Error.Type),
    isTRUE(all.equal(as.numeric(built$era_outcome_error_raw),error)),
    all(built$yield_part == "grain"), all(built$yield_unit_raw == unit),
    isTRUE(all.equal(built$yield, as.numeric(raw$ED.Mean.T) * scale))
  )
  list(yield=built$yield, se=as.numeric(raw$ED.Error)*scale)
}

malawi <- select_arms(
  c(182,184), "AC0017", "Tembwe EPA", paste(2011:2019, collapse=".."),
  "10.1016/j.heliyon.2021.e06636", c("FP","PPM"), "Mg/ha", 1000,
  c(0.021,0.024), 6, "Table 1"
)
south_africa <- select_arms(
  c(568,572), "NN0421", "Nelspruit", "2013", "10.3389/fsufs.2020.00094",
  c("M-0","BG-M(0)"), "kg/ha", 1, c(124.26,31.0655), 4, "fig2"
)

# Independently transcribed means from Table 1 and the N0 results paragraph.
malawi_paper <- c(1.84,3.99)*1000
south_africa_paper <- c(1671,2046)
stopifnot(isTRUE(all.equal(malawi$yield,malawi_paper)),
          isTRUE(all.equal(as.numeric(diff(south_africa$yield)),519.23)),
          abs(diff(south_africa_paper)-diff(south_africa$yield))>100)
report <- c(
  "# Worked maize grain yield contrasts",
  "",
  "Run `Rscript audit/meta_example.R` after the pinned build to compare archive records, harmonised yields and published results.",
  "",
  "## Pit planting plus mulch in Malawi",
  "",
  "ERA study AC0017 identifies Tembwe EPA, maize variety MH31, and the nine years 2011 through 2019 in one time field. Table 1 gives arm means across the 2010/11–2018/19 seasons. The source keys below refer to the May 2025 archive.",
  "",
  "| ERA source row | Treatment | Mean (kg/ha) | ERA-labelled SE (kg/ha) | ERA treatment replication count |",
  "|---:|---|---:|---:|---:|",
  sprintf("| 182 | FP, farmer practice | %.0f | %.0f | 6 |",malawi$yield[1],malawi$se[1]),
  sprintf("| 184 | PPM, pit planting plus mulch | %.0f | %.0f | 6 |",malawi$yield[2],malawi$se[2]),
  "",
  sprintf("The observed difference is **+%.0f kg/ha** (PPM minus FP). Both means match the published values after converting Mg/ha to kg/ha.",diff(malawi$yield)),
  "",
  "Use one study-period contrast. The two rows are arm means and the six replications do not identify individual plots. ERA classifies the reported ± values as standard errors. Table 1 does not explicitly define that error statistic. This comparison estimates the combined pit-planting and mulching package. A confidence interval for the difference requires a design-adjusted contrast error or the within-block covariance. Other treatments in Table 1 share the FP comparator. Joint analysis of those contrasts must account for their shared control. [Study methods and Table 1](https://pmc.ncbi.nlm.nih.gov/articles/PMC8035666/)",
  "",
  "## Source discrepancy in South Africa",
  "",
  "ERA study NN0421, Nelspruit, labels the maize harvest year 2013. The paper identifies the 2012/13 season. At zero applied nitrogen, ERA rows 568 (maize after maize, M-0) and 572 (maize after black gram, BG-M(0)) cite Figure 2. The primary article also prints numeric yields for this comparison.",
  "",
  "| Source | Maize after maize (kg/ha) | Maize after black gram (kg/ha) | Difference (kg/ha) |",
  "|---|---:|---:|---:|",
  sprintf("| ERA figure extraction | %.3f | %.3f | %+.2f |",south_africa$yield[1],south_africa$yield[2],diff(south_africa$yield)),
  sprintf("| Published N0 results text | %.0f | %.0f | %+.0f |",south_africa_paper[1],south_africa_paper[2],diff(south_africa_paper)),
  "",
  "Both estimates describe the same experiment. Keep their provenance together and flag the discrepancy for curator review before pooling. ERA labels the arm errors as standard errors with four replications. An inverse-variance weight requires an error estimate for the contrast under the experimental design. [Primary article, rotation results and Figures 1–2](https://doi.org/10.3389/fsufs.2020.00094)"
)
writeLines(report,"report/audit/meta_example.md")
