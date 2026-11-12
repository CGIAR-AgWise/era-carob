# SF-001 v0.1 review package (unpublished)

Scope: pinned code, aggregate validation evidence and reproduction instructions. The local wide table is an exploratory harmonisation output. No climate-enriched model data or rights-cleared combined database is released.

## ERA source version

The 12 May 2025 agronomy bundle contains the observation input `agronomic_majestic-hippo-2020-2025-04-11.1_industrious-elephant-2023-2025-05-09.2.json`. The vocabulary input is `era_master_codes-2025-05-12.json`. The archive's internal version CSV lists an earlier master-code filename dated 23 April. These identifiers follow the actual files extracted from the checksum-verified archive.

## Reproduce

Check out the PR revision using the [README commands](../README.md#build-and-inspect-the-candidate). Keep the repository history for the June replay. From repository root, with network access, Python 3.9+, Git, curl, R and Pandoc:

```sh
export SF001_INPUTS="$PWD/downloaded_data/sf001"
python3 audit/prepare.py "$SF001_INPUTS"
Rscript audit/replay.R "$SF001_INPUTS"
Rscript audit/extract.R "$SF001_INPUTS"
python3 audit/compare.py "$SF001_INPUTS"
Rscript audit/build.R
Rscript audit/check_snapshot.R "$SF001_INPUTS/sf001-review.rds"
Rscript script/era_carob_mapping.R
Rscript audit/meta_example.R
Rscript -e 'rmarkdown::render("README.Rmd"); rmarkdown::render("README.Rmd",output_format="html_document")'
```

Install R packages dplyr, tidyr, jsonlite, stringr, data.table, knitr, rmarkdown and openxlsx. [Tested environment](session.txt). The historical replay pins LC_COLLATE=C and two carobiner helpers by Git commit. It reuses the original transform without its mutable download preamble; it does not use the older March RData in ERA_data. Allow several GB of RAM. The historical output RDS and corrected sf001-review.rds stay in the cache. [Archive URLs and SHA-256](inputs.json) fail closed on replacement. ERA tarball also matches historical Git blob 52076f1b8e78268a4d4e42235ec5339508c398eb. The Carob archive is the agronomy CC collection with internal files dated 4 June, not the later 202606 or latest collection. Preserve the pinned bytes internally if URLs change.

## Validation and limitations

- See the [rendered report](../README.md), [join ledger](../report/audit/historical_joins.csv), [crop ledger](../report/audit/crop_labels.csv), [yield units](../report/audit/yield_units.csv) and [eligibility counts](../report/audit/eligibility.csv). Source ordinals identify rows within these exact archives, not independent experimental units. No guessed trial IDs; no automatic publication-level deduplication.
- Only exact, unambiguous plant products in the ERA vocabulary enter the identity comparison. Compound labels remain visible; no yield is allocated across components. The June ledger does not resolve every Carob name. Domain review can change the partition. ERA nutrient, treatment, density and management fields have not been certified as model predictors.
- Transform scalar yield units only for explicit kg/ha, Mg/ha, t/ha or g/m2. Keep original value and case-sensitive unit. Dry/fresh basis, yield part, measurement protocol, moisture, treatment comparisons, shared controls and cross-source record equivalence must be agreed for a specified model. Separate validation folds by study/trial once links are adjudicated.
- Date/coordinate screening uses original precision, rejects malformed/aggregate coordinates, zero pair and year-only dates. It cannot establish coordinate accuracy or weather coverage. Source planting years differ by 68–71 years from the first recorded season year in the exact-date subset. No offsets applied. Carob's eligible count is a preliminary screen, not a training set. Its screening window used the historical ERA snapshot cut-off (2025). A second crop cycle, cross-year seasons, year ranges or partial dates need explicit rules.
- Historical count sensitivity: C collation 244,041 ERA rows; C.UTF-8 243,998. The old row-number pivot and sorted full joins are order-sensitive. Original 244,094 could not be recovered in tested environments. Cedric/Namita: original session info, cached pre-pivot data or saved dwf would settle the residual.

## Publication gates and credit

1. Namita Joshi: supply revision or artifact for climate integration and updated schema, provider/version/variables/units, grid/CRS, spatial method, season window and sample keyed extracts. Confirm date origin against source records. No parallel climate extraction has been started.
2. Namita and Cedric Ngakou: validate counts by source, year, crop and country; one climate feature vector per eligible source key; no fan-out, missing coverage explained, sample points/dates/values independently checked against source grids. Review compound mappings and model-specific inclusion/exclusion rules. Model owner must name response, predictors, sampling unit and minimum coverage before sign-off.
3. Maintainers and data owners: approve authors, affiliation, contributors, software license and intended deposit. The upstream repository has no detected top-level software license. Do not assign a blanket license. Preserve each Carob dataset's URI, data_citation and license in pinned metadata, and confirm ERA terms. Source metadata includes noncommercial, share-alike and no-derivatives records, including CC-BY-NC-ND-4.0. Code, validation outputs and observations require separate rights decisions. Do not upload the merged table or source archives under an inferred license.
4. After approval merge reviewed changes, run regression checks on the selected commit, tag v0.1 there, publish the GitHub release with checksums and metadata, and archive approved files only. Verify the peeled tag SHA against the release commit, then verify the public Zenodo record, file checksums, version DOI resolution and reciprocal repository link. Drafts, preregistrations and reserved DOIs are not release evidence. Pete owns reporting.

Citation pending approval: Cedric Ngakou and Namita Joshi, *ERA × Carob: agronomic data transformation and SF-001 validation*, CGIAR Sustainable Farming Science Program (IITA and Alliance of Bioversity International and CIAT), repository and exact reviewed commit. No publication date or DOI assigned. See [CITATION.cff](../CITATION.cff).

## Assemble the review package

From a clean checkout run `python3 audit/package_review.py HEAD sf001-v0.1-review.tar.gz`. The command reads the file list and contents at the specified commit and prints its SHA-256. The package contains the workbook, worked examples, scripts and aggregate checks. Source archives and the combined RDS stay in the local input cache. The [package manifest](package-files.txt) defines the review archive.

## Climate handoff

Namita and the model user supply a feature-window CSV with one row per specified variable and the following columns:

| Column | Meaning |
|---|---|
| variable, units, provider_version | Feature identifier, physical units and pinned source version, matching the extraction |
| start_anchor, end_anchor | Each independently takes `planting` or `harvest` |
| start_days, end_days | Signed integer offsets in calendar days from the corresponding observed date, inclusive |

Run `Rscript audit/check_climate.R candidate.rds climate.csv feature_windows.csv coverage.csv`. Each climate record gives source and source_row, original point coordinates, planting date, start and end dates, variable, units, value, grid ID and provider version. The checker derives the expected dates from the source row and the feature definition. A one-year shift fails even when both submitted dates are internally consistent. Coverage counts include zero matches for a specified feature absent from the handoff. Each denominator includes all retained rows in its source, country, crop and year group. A separate comparison against the provider grid is needed to verify the extracted values. The synthetic example in `audit/test_climate.R` demonstrates the interface. Production window definitions and weather observations are pending.
