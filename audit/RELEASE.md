# SF-001 and SF-003: shared publication plan (unpublished)

Scope: SF-001 contains pinned software, aggregate validation evidence and reproduction instructions; SF-003 contains the [schema documentation](../docs/SF-003.md). Both use one GitHub repository and one planned CGSpace record. The two review archives are component selections, not separate deposit requirements. [Shared publication metadata](publication.json). [Product metadata, proposed versions and credits](packages.json). The local wide table is an exploratory harmonisation output. No climate-enriched model data or rights-cleared combined database is released.

## ERA source version

The current pin is `era_agronomy_bundle_2026-11-23-issue94.tar.gz`, published
24 November 2026, SHA-256 `c8cd1eac0f2fa3686519b5cc4f26b7ab72d4bdcc7945caad4944eb9eb376d717`.
Its observation member ends in `_issue94-2026-11-23.json`; its vocabulary is
`era_master_codes-2025-05-12.json`. The bundle includes the row-linked date
audit, holds and manifest. It corrects dates only; compiled comparison Parquet,
vocabulary, non-date values and row order are unchanged. The original May
2025 bundle remains pinned in `inputs-historical.json` for historical replay.

## Reproduce

Check out the selected commit using the [README commands](https://github.com/CGIAR-AgWise/era-carob#build-and-inspect-the-candidate); PRs #2 and #3 are merged. Keep the repository history for the June replay. From repository root, with network access, Python 3.9+, Git, curl, R and Pandoc:

```sh
# Historical replay and original pin-specific expectations.
export SF001_INPUTS="$PWD/downloaded_data/sf001-historical"
python3 audit/prepare.py "$SF001_INPUTS" --inputs audit/inputs-historical.json
Rscript audit/replay.R "$SF001_INPUTS"
Rscript audit/extract.R "$SF001_INPUTS"
python3 audit/compare.py "$SF001_INPUTS"
Rscript audit/build.R
Rscript audit/check_snapshot.R "$SF001_INPUTS/sf001-review.rds" historical

# Current date-only successor; use another cache to prevent mixed inputs.
export SF001_INPUTS="$PWD/downloaded_data/sf001-issue94"
python3 audit/prepare.py "$SF001_INPUTS"
Rscript audit/build.R
Rscript audit/check_snapshot.R "$SF001_INPUTS/sf001-review.rds" issue94
Rscript audit/check_hold_guard.R "$SF001_INPUTS/sf001-review.rds"
Rscript audit/check_date_successor.R downloaded_data/sf001-historical/sf001-review.rds "$SF001_INPUTS/sf001-review.rds"
Rscript audit/meta_example.R
Rscript -e 'rmarkdown::render("README.Rmd"); rmarkdown::render("README.Rmd",output_format="html_document")'
```

Install R packages dplyr, tidyr, jsonlite, stringr, data.table, digest, knitr, rmarkdown and openxlsx. [Tested environment](session.txt). The historical replay pins LC_COLLATE=C and two carobiner helpers by Git commit. It reuses the original transform without its mutable download preamble; it does not use the older March RData in ERA_data. Allow several GB of RAM. The historical output RDS and corrected sf001-review.rds stay in the cache. [Archive URLs and SHA-256](inputs.json) fail closed on replacement. The original May 2025 ERA tarball matches historical Git blob 52076f1b8e78268a4d4e42235ec5339508c398eb. The Carob archive is the exact checksum-pinned agronomy CC collection. Its ZIP member timestamps read 3 June 2026 when inspected on 20 November 2026; these are archive metadata, not a verified publication date. Do not substitute a similarly named monthly or latest collection. Preserve the pinned bytes internally if URLs change.

## Validation and limitations

- See the [rendered software report](https://github.com/CGIAR-AgWise/era-carob#readme), [join ledger](../report/audit/historical_joins.csv), [crop ledger](../report/audit/crop_labels.csv), [yield units](../report/audit/yield_units.csv) and [eligibility counts](../report/audit/eligibility.csv). Source ordinals identify rows within these exact archives, not independent experimental units. No guessed trial IDs; no automatic publication-level deduplication.
- Only exact, unambiguous plant products in the ERA vocabulary enter the identity comparison. Compound labels remain visible; no yield is allocated across components. The June ledger does not resolve every Carob name. Domain review can change the partition. ERA nutrient, treatment, density and management fields have not been certified as model predictors.
- Transform scalar yield units only for explicit kg/ha, Mg/ha, t/ha or g/m2. Keep original value and case-sensitive unit. Dry/fresh basis, yield part, measurement protocol, moisture, treatment comparisons, shared controls and cross-source record equivalence must be agreed for a specified model. Separate validation folds by study/trial once links are adjudicated.
- Date/coordinate screening uses original precision, rejects malformed/aggregate coordinates, zero pair and year-only dates. It cannot establish coordinate accuracy or weather coverage. The historical input had shifted/lost dates. The current input uses the published upstream correction; no consumer offsets are applied. Current accepted planting dates exclude year 9999, and source-date holds remain unresolved. Carob's eligible count is a preliminary screen, not a training set. Its screening window used the historical ERA snapshot cut-off (2025). A second crop cycle, cross-year seasons, year ranges or partial dates need explicit rules.
- Historical count sensitivity: C collation 244,041 ERA rows; C.UTF-8 243,998. The old row-number pivot and sorted full joins are order-sensitive. Original 244,094 could not be recovered in tested environments. Cedric/Namita: original session info, cached pre-pivot data or saved dwf would settle the residual.

## Publication gates and credit

1. Namita Joshi: supply revision or artifact for climate integration and updated schema, provider/version/variables/units, grid/CRS, spatial method, season window and sample keyed extracts. Confirm date origin against source records. No parallel climate extraction has been started.
2. Namita and Cedric Ngakou: validate counts by source, year, crop and country; one climate feature vector per eligible source key; no fan-out, missing coverage explained, sample points/dates/values independently checked against source grids. Review compound mappings and model-specific inclusion/exclusion rules. Model owner must name response, predictors, sampling unit and minimum coverage before sign-off.
3. Maintainers and data owners: approve authors, affiliation, contributors, software license and intended deposit. The upstream repository has no detected top-level software license. Do not assign a blanket license. Preserve each Carob dataset's URI, data_citation and license in pinned metadata, and confirm ERA terms. Source metadata includes noncommercial, share-alike and no-derivatives records, including CC-BY-NC-ND-4.0. Code, validation outputs and observations require separate rights decisions. Do not upload the merged table or source archives under an inferred license.
4. After approval of the exact release content, merge reviewed changes, run regression checks on the selected commit, tag v0.1 there and publish one GitHub release with checksums and metadata. Verify the peeled tag SHA against the release commit. Prepare one TIP submission for a shared CGSpace record that describes the schema documentation and links the pipeline/validation evidence. Obtain approval before entry or submission; verify the published handle separately and use it in both deliverables' reporting entries with distinct claims. Zenodo archiving is optional and does not require separate deposits for SF-001/SF-003. If a deposit is later approved, verify its files, checksums and published DOI; drafts and reserved DOIs are not public-release evidence. Pete owns reporting.

Citation pending approval: Cedric Ngakou and Namita Joshi, *ERA × Carob data-to-model pipeline (SF-001)*, CGIAR Sustainable Farming Science Program (IITA and Alliance of Bioversity International and CIAT), repository and exact reviewed commit. No publication date or DOI assigned. See [software CITATION.cff](https://github.com/CGIAR-AgWise/era-carob/blob/main/CITATION.cff).

## Assemble the review packages

From a clean checkout, use the selected Git commit (not uncommitted working files):

```sh
python3 audit/package_review.py HEAD sf001-v0.1-review.tar.gz
python3 audit/package_review.py HEAD sf003-docs-v0.1-review.tar.gz --product sf003
```

The command reads metadata, the allowlist and contents at that commit, verifies
archive membership, and prints the commit and SHA-256. Keep those outputs with
both review artifacts. [Software allowlist](package-files.txt) and
[documentation allowlist](schema-package-files.txt) are explicit. Shared evidence
supports two different claims; it is not two datasets. Source archives and the
combined RDS stay in the local cache. The experimental `audit/era_compile.R`
helper is excluded and is not called by the review pipeline.

## Publication identifiers and route

Agreed publication plan: **one GitHub repository and one CGSpace record for
SF-001 and SF-003**, represented once in [publication.json](publication.json).
The shared record should describe and provide access to the schema documentation
and link to the pipeline, exact Git commit/release and validation evidence.
Use a title and abstract covering both components, with agreed creators and
component-specific credits. Confirm the appropriate record type and current
reporting eligibility with the library/reporting team before submission.

| Deliverable | Use of the shared evidence |
|---|---|
| SF-001 — innovation development | Pipeline code and demonstrated readiness; the shared CGSpace record supports the innovation evidence. Documentation alone does not establish model readiness. |
| SF-003 — knowledge product | Schema definitions, units, mappings, provenance, vocabulary and snapshot described and accessible through that same CGSpace record. |

Record the same verified GitHub URL and CGSpace handle against both deliverables,
identifying the relevant files/sections and their different claims. This is one
innovation and its documentation knowledge product, **not two knowledge products**.
SF-007 remains an SF-001 component, not an additional innovation count.

Separate Zenodo deposits or DOIs are **not required by this plan**. An optional
archive may be considered later if preservation or citation needs justify it;
it is not a prerequisite introduced by these two reporting IDs. The review
manifests remain useful for choosing files and checking scope; they do not
imply two Zenodo or CGSpace records. Track later software/schema changes in
Git and coordinate updates to the same CGSpace record with the library,
retaining version history.

| Identifier/state | What it establishes |
|---|---|
| Git commit / GitHub tag and release | Source revision / published release assets and notes; no automatic reporting acceptance |
| Zenodo version DOI | One published record version; preferred for reproducing an exact package |
| Zenodo concept DOI | The version family of that one product; not a second result |
| Reserved DOI or draft deposition | Preparation only; not evidence of public availability |
| TIP submission ID and review state | Institutional submission/review progress; not public CGSpace publication |
| Published CGSpace handle | Public library record, verified separately after library processing |
| PRMS result ID/state | Separate reporting-system submission and quality assurance |

Zenodo's GitHub integration archives repository releases. A curated allowlist
attachment does **not** prove that the integration will archive only that
attachment. This repository also tracks source data outside our allowlists.
If Zenodo archiving is later requested, approve the selected files and route
first; verify every byte of any automatic repository archive. Neither a manual
deposit nor automatic archiving is part of the current publication requirement.
Do not enable automatic archiving as part of this review. Root `CITATION.cff`
describes software only; do not replace it with the documentation citation.

Current official sources checked 20 November 2026:

- [Zenodo versioning](https://zenodo.org/help/versioning): separate version and concept identifiers.
- [Archive a GitHub release](https://help.zenodo.org/docs/github/archive-software/github-upload/): repository-release archival and verification.
- [Describe software](https://help.zenodo.org/docs/github/describe-software/): `.zenodo.json` takes precedence over `CITATION.cff` when both exist.
- [Describe records](https://help.zenodo.org/docs/deposit/describe-records/): output-specific creators, resource type, rights and contributors.
- [Alliance TIP](https://tip.alliance.cgiar.org) and [CGSpace](https://cgspace.cgiar.org): institutional route and public repository. Live TIP redirected to login and the public CGSpace request was rate-limited during this check. Current authenticated submission requirements could not be reverified; confirm them with the library before entry. No universal DOI prerequisite is established here.

Before TIP entry, search for an existing record covering this work and agree
one record's type, title/abstract, creators/order, rights, files and repository
links. Its description must make the SF-003 documentation identifiable while
also supporting SF-001's distinct innovation claim. Show the complete shared
package for approval before server-side draft saving or submission. Verify the
public CGSpace handle after library review and reconcile that same handle with
both existing reporting records. Keep identifiers unset in the shared metadata
until verified. A shared URL is not proof that either deliverable is complete.

## Date correction and the retired 19 November override

Commit `470def57dee20013204ea14ba93d6c32c134a2d3` added a compiled-Parquet
loader and date override. The loader ignored `SF001_INPUTS`, referenced an
undefined `s3` object and needed an undeclared `arrow` dependency. The override
called nonexistent `gub()`, joined dates only at study level and substituted
year-only text for a missing planting date. It also overwrote the value later
retained as `planting_date_raw`, losing the original date's provenance.

This review removes that override from the production path. It now consumes
the published upstream issue #94 correction through a checksum-pinned JSON,
without using the compiled-Parquet helper or study-level date substitution.
`planting_date_raw` preserves corrected source text; the original tokens remain
in the bundled audit. See [SF-003 date policy](../docs/SF-003.md#date-origin-precision-and-source-holds).

The corrected consumer retains 110,277 ERA and 246,993 Carob rows, with 40,655
accepted and 70,161 raw ERA planting dates. All 900 source row/field holds are
verified against their source and retained as RDS metadata; held outcome rows
cannot pass climate handoff checks. Missing dates on held rows are not an
invitation to impute. Cross-year interpretation and independent climate checks
remain pending. [Current date counts](../report/audit/date_snapshot.json).

Historical eligibility and dictionary/workbook coverage remain explicitly
labelled as May 2025 evidence. Current date counts supersede those date counts;
non-date schema definitions and coverage are unchanged. To regenerate the
mapping workbook for a chosen prepared candidate, run
`Rscript script/era_carob_mapping.R`; its legend records the selected archives.


## Climate handoff

ERA handoffs require exact current or historical archive provenance. For the
current pin, the complete source-date ledger must match the row count and
SHA-256 fingerprint in `audit/date-holds.json`. Missing metadata, an empty or
truncated ledger, and changed findings are rejected before climate validation.
The contract is derived from the checksum-verified published hold CSV; update
it only with a reviewed new input release. `audit/check_hold_guard.R` exercises
real held and unheld candidate rows with synthetic climate values, including
metadata-loss regressions. This is a guard test, not climate-provider validation.

Namita and the model user supply a feature-window CSV with one row per specified variable and the following columns:

| Column | Meaning |
|---|---|
| variable, units, provider_version | Feature identifier, physical units and pinned source version, matching the extraction |
| start_anchor, end_anchor | Each independently takes `planting` or `harvest` |
| start_days, end_days | Signed integer offsets in calendar days from the corresponding observed date, inclusive |

Run `Rscript audit/check_climate.R candidate.rds climate.csv feature_windows.csv coverage.csv`. Each climate record gives source and source_row, original point coordinates, planting date, start and end dates, variable, units, value, grid ID and provider version. The checker derives the expected dates from the source row and the feature definition. A one-year shift fails even when both submitted dates are internally consistent. Coverage counts include zero matches for a specified feature absent from the handoff. Each denominator includes all retained rows in its source, country, crop and year group. A separate comparison against the provider grid is needed to verify the extracted values. The synthetic example in `audit/test_climate.R` demonstrates the interface. Production window definitions and weather observations are pending.
