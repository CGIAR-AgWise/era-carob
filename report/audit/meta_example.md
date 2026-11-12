# Worked maize grain yield contrasts

Run `Rscript audit/meta_example.R` after the pinned build to compare archive records, harmonised yields and published results.

## Pit planting plus mulch in Malawi

ERA study AC0017 identifies Tembwe EPA, maize variety MH31, and the nine years 2011 through 2019 in one time field. Table 1 gives arm means across the 2010/11–2018/19 seasons. The source keys below refer to the May 2025 archive.

| ERA source row | Treatment | Mean (kg/ha) | ERA-labelled SE (kg/ha) | ERA treatment replication count |
|---:|---|---:|---:|---:|
| 182 | FP, farmer practice | 1840 | 21 | 6 |
| 184 | PPM, pit planting plus mulch | 3990 | 24 | 6 |

The observed difference is **+2150 kg/ha** (PPM minus FP). Both means match the published values after converting Mg/ha to kg/ha.

Use one study-period contrast. The two rows are arm means and the six replications do not identify individual plots. ERA classifies the reported ± values as standard errors. Table 1 does not explicitly define that error statistic. This comparison estimates the combined pit-planting and mulching package. A confidence interval for the difference requires a design-adjusted contrast error or the within-block covariance. Other treatments in Table 1 share the FP comparator. Joint analysis of those contrasts must account for their shared control. [Study methods and Table 1](https://pmc.ncbi.nlm.nih.gov/articles/PMC8035666/)

## Source discrepancy in South Africa

ERA study NN0421, Nelspruit, labels the maize harvest year 2013. The paper identifies the 2012/13 season. At zero applied nitrogen, ERA rows 568 (maize after maize, M-0) and 572 (maize after black gram, BG-M(0)) cite Figure 2. The primary article also prints numeric yields for this comparison.

| Source | Maize after maize (kg/ha) | Maize after black gram (kg/ha) | Difference (kg/ha) |
|---|---:|---:|---:|
| ERA figure extraction | 1615.385 | 2134.615 | +519.23 |
| Published N0 results text | 1671 | 2046 | +375 |

Both estimates describe the same experiment. Keep their provenance together and flag the discrepancy for curator review before pooling. ERA labels the arm errors as standard errors with four replications. An inverse-variance weight requires an error estimate for the contrast under the experimental design. [Primary article, rotation results and Figures 1–2](https://doi.org/10.3389/fsufs.2020.00094)
