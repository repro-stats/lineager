# lineager <img src="man/figures/logo.png" align="right" height="139" alt="" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/repro-stats/lineager/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/repro-stats/lineager/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/repro-stats/lineager/graph/badge.svg)](https://app.codecov.io/gh/repro-stats/lineager)
<!-- badges: end -->

**Row-Level Data Provenance and Exclusion Tracking**

You build an analysis dataset. You filter it, join it, derive new
variables, and produce results. Somewhere along the way rows disappear.
Later, someone asks: *"Which records were excluded, why, and what
happened to record 01-042 between source and analysis?"*

Without `lineager`, that answer requires manual reconstruction.
With `lineager`, it is a single function call.

`lineager` tags every row of every dataset with a unique lineage
identifier that survives filters, joins, and derivations. Every row
removal must carry a documented reason. At any point, `lg_trace()`
returns any row's complete journey across the entire pipeline.
`lg_lineage()` visualises the full pipeline graph. `lg_report()`
compiles everything into a structured provenance document.

`lineager` is general-purpose: clinical data, machine learning,
financial modelling, epidemiology — any pipeline where row-level
accountability matters. CDISC-specific features (domain codes,
population flags, SDTM-to-ADaM mapping, Reviewer's Guide output) are
available as optional enrichment for pharmaceutical users.

## Installation

```r
# Install from GitHub
> pak::pak("repro-stats/lineager")
```

## Quick start

```r
library(lineager)

lg_start(study_id = "TRIAL-001", analysis_id = "primary")

# Tag source data
adsl <- lg_tag(haven::read_sas("sdtm/dm.sas7bdat"),
               dataset_id = "DM", domain = "DM")

# Derive variables with documented descriptions
adsl <- lg_derive(adsl,
  RANDFL = ifelse(ARMCD != "SCRNFAIL", "Y", "N"),
  SAFFL  = ifelse(ARMCD != "SCRNFAIL" & EXOCCUR == "Y", "Y", "N"),
  description = "RANDFL: not screen failure. SAFFL: randomised AND dosed."
)

# Filter with mandatory exclusion reasons
adsl_safety <- lg_filter(
  adsl,
  SAFFL == "Y",
  reason      = "Not in safety population (SAFFL != 'Y')",
  reason_code = "NOT_SAFETY",
  population  = "SAFFL"
)

# Trace any subject across the pipeline
lg_trace("01-042")

# Exclusion registry and disposition table
lg_exclusions()
lg_disposition(by = "reason")

# Visualise the pipeline
lin <- lg_lineage()
lg_plot(lin)

# Generate provenance report
lg_report(
  output  = "outputs/provenance.html",
  title   = "Data Provenance Report",
  sponsor = "Example Pharma Ltd",
  author  = "Your name"
)

lg_end()
```

## Key functions

| Function | Purpose |
|---|---|
| `lg_start()` / `lg_end()` | Session lifecycle |
| `lg_tag()` | Tag a dataset with row-level lineage IDs |
| `lg_filter()` | Filter with mandatory exclusion reason |
| `lg_derive()` | Derive variables with documented description |
| `lg_join()` | Tracked join with bilateral row-ID tracing |
| `lg_population()` | Register a population or cohort definition |
| `lg_spec()` | Document a source-to-analysis variable derivation |
| `lg_trace()` | Trace a row's complete lineage journey |
| `lg_exclusions()` | Retrieve the full exclusion registry |
| `lg_disposition()` | Grouped exclusion summary table |
| `lg_operations()` | Full pipeline operation log |
| `lg_lineage()` | Build a pipeline lineage graph |
| `lg_plot()` | Render the lineage graph inline or export |
| `lg_report()` | Generate a structured HTML provenance report |

## The lineage ID

Every row carries a `.__lid__` column. For CDISC datasets with USUBJID:

```
DM_0001_01-042    # row 1 from DM domain, subject 01-042
ADLB_0047_01-042  # row 47 from ADLB, same subject
```

For general datasets:

```
patients_000001   # row 1 from the patients dataset
```

This ID persists through `lg_filter()`, `lg_derive()`, and `lg_join()`,
forming the traceable thread from any output row back to its source.

## CDISC features

For pharmaceutical and clinical users, `lineager` additionally supports:

- `domain` argument in `lg_tag()` for CDISC domain codes
- `lg_population()` for SAFFL, ITTFL, PPROTFL flag documentation
- `lg_spec()` for SDTM-to-ADaM variable derivation mapping
- `lg_report()` output aligned with CDISC Reviewer's Guide requirements

None of these are required for general use.

## Integration with regulog

`lineager` and `regulog` are complementary. Use `regulog` for a
tamper-evident session-level audit trail (who ran what, when, and why),
and `lineager` for row-level data provenance within that session. The
`lg_report()` output can be referenced in the `regulog` audit trail via
`log_action()`.
