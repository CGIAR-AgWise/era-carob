ERA × Carob: SF-001 validation
================

**Review candidate, not a released model dataset.** This CGIAR
[Sustainable Farming Science
Program](https://www.cgiar.org/cgiar-research-portfolio-2025-2030/sustainable-farming)
collaboration involves IITA and the Alliance of Bioversity International
and CIAT. Cedric Ngakou developed the ERA-to-Carob transformation and
merge; Namita Joshi contributed integration, reporting and fixes and
leads climate integration.

### ERA data version

Both the historical replay and the corrected pipeline use the **ERA
Agronomy bundle dated 12 May 2025**. Its agronomic JSON combines
**Majestic Hippo 2020 (2025-04-11.1)** and **Industrious Elephant 2023
(2025-05-09.2)**. Crop harmonisation uses the bundled master codes dated
**2025-05-12**. The bundle also contains a compiled Parquet file
labelled v1.0. The observation counts come from the agronomic JSON. The
proposed v0.1 version refers to the ERA–Carob pipeline. [Pinned archive
and SHA-256](audit/inputs.json)

### Build and inspect the candidate

Use the PR revision while the changes are under review. From a terminal
with Git, curl, Python 3 and R installed:

``` sh
git clone https://github.com/CGIAR-AgWise/era-carob.git
cd era-carob
git fetch origin refs/pull/2/head
git switch --detach FETCH_HEAD
git rev-parse HEAD
Rscript -e 'install.packages(c("dplyr","tidyr","stringr","jsonlite","data.table"), repos="https://cloud.r-project.org")'
export SF001_INPUTS="$PWD/downloaded_data/sf001"
python3 audit/prepare.py "$SF001_INPUTS"
Rscript audit/build.R
Rscript -e 'd <- as.data.frame(readRDS(file.path(Sys.getenv("SF001_INPUTS"),"sf001-review.rds"))); print(table(d$source)); print(head(d[c("source","source_row","dataset_id","crop_raw","crop","yield")]))'
```

Preparation verifies the two archives. The build resolves crops against
the supplied ERA vocabulary, checks each retained row against its source
and writes the review dataset locally. For the June replay, exact
snapshot checks and workbook generation, follow the [reproduction
instructions](audit/RELEASE.md#reproduce).

### What the pinned comparison measures

Each retained ERA row has a distinct ordinal in the source archive’s
`Data.Out` outcome table. Each Carob row is one record in the June
agronomy wide table. These units differ. A dataset ID counts a source
study in ERA or a dataset in Carob. A Carob trial is a nonblank
**(dataset_id, trial_id)** pair; study, location or row number cannot
substitute for a trial ID in ERA.

| Pinned candidate | ERA | Carob |
|:---|---:|---:|
| Input rows (ERA source outcomes / Carob wide records) | 110,534 | 246,993 |
| Retained rows | 110,277 | 246,993 |
| Distinct source study / dataset IDs | 1,622 | 201 |
| Identifiable trials | Unknown (no trial IDs) | 41,631 |
| Crop yield rows with numeric kg/ha | 42,283 | 221,165 |

Together these sources contribute **357,270 stacked rows**; this is not
a count of independent observations or trials. Carob trial IDs are
populated on 244,783 rows. Publication-DOI matching gives **21 dataset
links for 14 ERA studies** in the historical comparison; for example,
DK0071 links to three Carob datasets. A shared article flags possible
overlap, not duplicate measurements. Do not subtract 21 rows or discard
all data from these studies. [Study
links](report/audit/publication_links.csv)

| Crop counting rule | ERA only | Both | Carob only |
|:---|---:|---:|---:|
| June replay: distinct nonblank crop strings, trimmed and lowercased | 678 | 54 | 33 |
| June replay: resolved ERA product identities only | 133 | 57 | 6 |
| Corrected pipeline: resolved identities on retained rows | 98 | 52 | 11 |

**678 was a count of labels, not new crops.** The June transform used
`P.Product` before the later crop substitutions. The conservative
comparison uses the bundled ERA master `prod` vocabulary: whole product,
simple product or scientific name must resolve to one plant product. A
small spelling/synonym list aligns labels such as *faba bean / fava
bean*, *sweetpotato / sweet potato* and *lucerne / alfalfa*. Maize
occurs in both; avocado is ERA-only and hazelnut Carob-only among
resolved June products. A product is not necessarily a botanical
species. “Only” means only among resolved observations in these two
inputs.

The [label ledger](report/audit/crop_labels.csv) shows counts and
decisions on both sides. Bamboo–maize is a compound, not another crop;
variety names require parent crop context. Do not assign yield to the
first member of a mixture or conflate rice bean with rice. Ambiguous and
unknown labels stay unresolved. Missing crop accounts for 40,247 ERA and
820 Carob rows in the historical replay. [Current product
list](report/audit/current_products.csv) and [current label
counts](report/audit/current_crop_labels.csv)

### Why the historical totals changed

The [June
report](https://github.com/CGIAR-AgWise/era-carob/tree/81eef14c11437bddf8bb5914436e4525b45c6cce)
recorded 244,094 ERA rows and 491,087 stacked rows across 321 columns.
Replay gives **244,041 and 491,034**, respectively, with the same
246,993 Carob baseline, 1,720 ERA IDs and 17 ERA-only country strings.
This run pins R collation to C. Under C.UTF-8 the same inputs produced
243,998 ERA rows (490,991 stacked). Row-order pairing makes counts
sensitive to sort order; the original environment and the remaining
53-row difference are unverified; do not cite either historical total as
new observations. The baseline has 320 fields before the source
indicator.

The old full joins used all common column names as keys and included
unmatched lookup records. Soil joined only on study and site, increasing
182,835 rows to 259,438 before filtering and reshaping. Then the outcome
pivot paired observations by within-variable row number. [Stage-by-stage
keys and counts](report/audit/historical_joins.csv). The corrected build
starts with outcomes, attaches only unambiguous complete lookup keys,
keeps the source ordinal through reshaping and flags unresolved crops.
This sacrifices ambiguous attributes to preserve outcome identity.
Review treatment, replication and unit assumptions before analysis.

### Reusing treatment means

Study AC0017 illustrates what the merged data can support. In Malawi,
maize grain yield averaged 3,990 kg/ha under pit planting plus mulch and
1,840 kg/ha under farmer practice. The **2,150 kg/ha difference** agrees
with the paper’s table across nine seasons. Treat the pair as one
study-period contrast. The reported replication count and arm errors
alone cannot establish its sampling variance. For NN0421, the ERA figure
extraction and the paper’s results text disagree. Review that
discrepancy before pooling the contrast. [Worked examples and primary
sources](report/audit/meta_example.md)

Use the [field dictionary](report/field_dictionary.xlsx) or its [CSV edition](report/field_dictionary.csv) for definitions, units, source coverage and study-specific exceptions. It compares the merged fields with [Terminag](https://github.com/controvoc/terminag) and links the contributing [Carob project](https://github.com/carob-data).

The [schema workbook](report/era_carob_mapping.xlsx) gives field sources
and the number of populated rows. The candidate preserves ERA’s original
outcome, value, unit, uncertainty and harvest-part label beside
harmonised fields. Soil carbon concentration and stock have different
units. An irrigation method can establish irrigation use even when the
water quantity is unknown. ERA’s mean annual site rainfall has its own
field because Carob defines rainfall over the crop season.

### Climate and model readiness

This screen uses original ERA outcomes and Carob wide rows, before any
climate join. Coordinate checks require a finite, in-range pair other
than (0,0); dates require a valid day and a plausible planting year. For
ERA we also require a unique recorded season year matching the planting
year. A full season window, grid-cell match and observed weather are
**not** established by this screen.

| test | ERA Data.Out rows | Carob wide rows |
|:---|---:|---:|
| exact planting date | 16,363 | 121,558 |
| nonnegative yield convertible to kg/ha | 42,283 | 221,165 |
| plausible planting date | 0 | 121,536 |
| resolved crop | 95,639 | 240,559 |
| rows | 110,534 | 246,993 |
| screened yield rows outside publication overlap | 0 | 104,542 |
| valid coordinate pair | 105,862 | 242,037 |
| valid location and date | 0 | 120,656 |

Example: study AG0003 records season 2014 but planting date 2084-06-02.
Do not infer a universal offset. The candidate retains the source
planting date for audit and suppresses unmatched dates in the harmonised
field. No reviewed climate output is available in this repository.
Enrichment coverage is **unmeasured**, and no climate-enriched model
dataset is certified. Namita owns climate provenance and date
resolution; Cedric reviews the transformation. See [reproduction, rights
and release gates](audit/RELEASE.md).
