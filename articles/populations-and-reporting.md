# Populations, variable specifications, and reporting

After tagging, filtering, and deriving, two tasks remain before the
provenance record is complete:

1.  **Documenting populations** — the definitions and criteria for each
    analysis set or cohort
    ([`lg_population()`](https://reprostats.org/lineager/reference/lg_population.md))
2.  **Documenting variable derivations** — linking each output variable
    back to its source
    ([`lg_spec()`](https://reprostats.org/lineager/reference/lg_spec.md))

Both feed directly into
[`lg_report()`](https://reprostats.org/lineager/reference/lg_report.md),
which compiles everything into a structured HTML provenance report.

## Setup: a complete pipeline

We build a session with tagging, derivation, filtering, and multiple
analysis populations to demonstrate the full reporting workflow.

``` r

lg_start(study_id = "TRIAL-001", analysis_id = "primary-efficacy")
#> lineager: session started [study: TRIAL-001] [analysis: primary-efficacy]

# Source data — patients and lab measurements
patients <- data.frame(
  USUBJID = sprintf("PT-%03d", 1:15),
  age = c(
    22L, 45L, 38L, 61L, 29L, 55L, 43L, 17L, 52L,
    34L, 48L, 27L, 66L, 39L, 51L
  ),
  sex = rep(c("M", "F", "M"), 5L),
  arm = c(
    "TRT", "TRT", "CTL", "TRT", "CTL", "CTL", "TRT", "TRT",
    "CTL", "TRT", "CTL", "TRT", "CTL", "CTL", "TRT"
  ),
  enrolled = c(rep(TRUE, 13), FALSE, FALSE),
  dosed = c(rep(TRUE, 10), FALSE, TRUE, TRUE, FALSE, FALSE),
  stringsAsFactors = FALSE
)

labs <- data.frame(
  USUBJID = sprintf("PT-%03d", c(1:10, 12:13)),
  baseline = round(c(
    24.1, 31.8, 28.4, 22.9, 35.2, 26.7,
    29.1, 33.4, 27.8, 25.5, 30.2, 28.9
  ), 1),
  endpoint = round(c(
    18.4, 27.1, 24.6, 19.8, NA, 22.3,
    25.4, 28.1, NA, 21.7, 26.4, 24.1
  ), 1),
  stringsAsFactors = FALSE
)

# Tag
pts <- lg_tag(patients, dataset_id = "PATIENTS", label = "Patient registry")
#> lineager: tagged 'PATIENTS' — 15 rows, 6 cols
labs_tagged <- lg_tag(labs, dataset_id = "LABS", label = "Laboratory measurements")
#> lineager: tagged 'LABS' — 12 rows, 3 cols

cat("Patients:", nrow(pts), "\n")
#> Patients: 15
cat("Labs:    ", nrow(labs_tagged), "\n")
#> Labs:     12
```

### Derive analysis variables

``` r

# Adult flag
pts <- lg_derive(pts,
  adult = age >= 18L,
  description = "adult: TRUE if age >= 18 years"
)
#> lineager: [PATIENTS] derive — adult: TRUE if age >= 18 years

# Derive population flags
pts <- lg_derive(pts,
  ENRLFL = ifelse(enrolled, "Y", "N"),
  DOSEFL = ifelse(enrolled & dosed, "Y", "N"),
  description = "ENRLFL: enrolled; DOSEFL: enrolled AND received study treatment"
)
#> lineager: [PATIENTS] derive — ENRLFL: enrolled; DOSEFL: enrolled AND received study treatment

# Join lab measurements
pts_labs <- lg_join(pts, labs_tagged,
  by          = "USUBJID",
  type        = "left",
  description = "Merge baseline and endpoint lab measurements from LABS"
)
#> lineager: [PATIENTS + LABS] left join — 15 rows out

# Derive analysis variables
analysis_ds <- lg_derive(pts_labs,
  CHG = endpoint - baseline,
  PCHG = round((endpoint - baseline) / baseline * 100, 2),
  description = paste(
    "CHG: absolute change from baseline (endpoint - baseline);",
    "PCHG: percent change from baseline"
  )
)
#> lineager: [PATIENTS] derive — CHG: absolute change from baseline (endpoint - baseline); PCHG: percent change from baseline

# Filter to enrolled, adult, dosed patients with complete endpoint
final <- analysis_ds |>
  lg_filter(enrolled == TRUE, adult == TRUE,
    reason      = "Not enrolled or under 18",
    reason_code = "NOT_ENROLLED"
  ) |>
  lg_filter(dosed == TRUE,
    reason      = "Did not receive study treatment",
    reason_code = "NOT_DOSED",
    population  = "SAFETY_SET"
  ) |>
  lg_filter(!is.na(endpoint),
    reason      = "Missing primary endpoint measurement",
    reason_code = "MISSING_EP",
    population  = "ANALYSIS_SET"
  )
#> lineager: [PATIENTS] filter 'Not enrolled or under 18' — 15 in, 12 out, 3 excluded
#> lineager: [PATIENTS] filter 'Did not receive study treatment' — 12 in, 11 out, 1 excluded
#> lineager: [PATIENTS] filter 'Missing primary endpoint measurement' — 11 in, 9 out, 2 excluded

cat("Final analysis set:", nrow(final), "patients\n")
#> Final analysis set: 9 patients
```

## 1. lg_population(): documenting analysis sets

[`lg_population()`](https://reprostats.org/lineager/reference/lg_population.md)
registers the formal definition of a population flag. It requires that
the flag variable already exists in the dataset — compute it first with
[`lg_derive()`](https://reprostats.org/lineager/reference/lg_derive.md),
then register the definition.

``` r

lg_population(pts,
  flag_var      = "ENRLFL",
  label         = "Enrolled Set",
  definition    = "All patients who met eligibility criteria and were enrolled in the study",
  incl_criteria = "enrolled == TRUE AND age >= 18"
)
#> lineager: population 'ENRLFL' (Enrolled Set) — 13 included, 2 excluded
```

### Multiple populations

``` r

lg_population(pts,
  flag_var      = "DOSEFL",
  label         = "Safety Set",
  definition    = "All enrolled patients who received at least one dose of study treatment",
  incl_criteria = c("enrolled == TRUE", "dosed == TRUE"),
  excl_criteria = "Enrolled but did not receive study treatment (dosed == FALSE)"
)
#> lineager: population 'DOSEFL' (Safety Set) — 12 included, 3 excluded
```

### What lg_population() records

``` r

env <- getFromNamespace(".lg", "lineager")
pop <- env$populations[["DOSEFL"]]
cat("Flag:       ", pop$flag_var, "\n")
#> Flag:        DOSEFL
cat("Label:      ", pop$label, "\n")
#> Label:       Safety Set
cat("N included: ", pop$n_included, "\n")
#> N included:  12
cat("N excluded: ", pop$n_excluded, "\n")
#> N excluded:  3
cat("N total:    ", pop$n_total, "\n")
#> N total:     15
```

The `n_included` and `n_excluded` counts come from the `flag_var` column
in the dataset at the time
[`lg_population()`](https://reprostats.org/lineager/reference/lg_population.md)
is called. Pass the most complete dataset (before any
population-specific filtering) so the counts reflect the full enrolled
cohort.

### print method

``` r

print(pop)
#> <lg_population> DOSEFL — Safety Set
#>   Definition : All enrolled patients who received at least one dose of study treatment
#>   N included : 12
#>   N excluded : 3
#>   Inclusion  : enrolled == TRUE; dosed == TRUE
#>   Exclusion  : Enrolled but did not receive study treatment (dosed == FALSE)
```

## 2. lg_spec(): documenting variable derivations

[`lg_spec()`](https://reprostats.org/lineager/reference/lg_spec.md)
registers a structured derivation specification linking an output
variable back to its source. Think of it as the “Variable Derivations”
section of an analysis plan, expressed as structured R objects rather
than prose.

``` r

lg_spec(
  adam_dataset  = "ANALYSIS",
  adam_var      = "CHG",
  label         = "Change from Baseline",
  source_domain = "LABS",
  source_var    = "endpoint / baseline",
  derivation    = "endpoint - baseline; NA when endpoint is missing"
)

lg_spec(
  adam_dataset  = "ANALYSIS",
  adam_var      = "PCHG",
  label         = "Percent Change from Baseline",
  source_domain = "LABS",
  source_var    = "endpoint / baseline",
  derivation    = "(endpoint - baseline) / baseline * 100, rounded to 2 decimal places",
  conditions    = "Only computed when baseline is non-missing and non-zero"
)
```

### Documenting flag derivations

``` r

lg_spec(
  adam_dataset  = "PATIENTS",
  adam_var      = "ENRLFL",
  label         = "Enrolled Flag",
  source_domain = "PATIENTS",
  source_var    = "enrolled",
  derivation    = "Y if enrolled == TRUE; N otherwise"
)

lg_spec(
  adam_dataset  = "PATIENTS",
  adam_var      = "DOSEFL",
  label         = "Safety Flag",
  source_domain = "PATIENTS",
  source_var    = "enrolled / dosed",
  derivation    = "Y if enrolled == TRUE AND dosed == TRUE; N otherwise"
)
```

### Overwriting a spec

If you call
[`lg_spec()`](https://reprostats.org/lineager/reference/lg_spec.md) with
the same `adam_dataset` and `adam_var`, the prior spec is replaced —
useful during iterative analysis:

``` r

# Refine the CHG derivation description
lg_spec(
  adam_dataset  = "ANALYSIS",
  adam_var      = "CHG",
  label         = "Change from Baseline",
  source_domain = "LABS",
  source_var    = "endpoint / baseline",
  derivation    = "endpoint - baseline. LOCF applied when endpoint missing at Week 12 only.",
  conditions    = "LOCF from Week 8 visit applied per SAP section 7.2"
)
```

## 3. lg_report(): generating the provenance report

[`lg_report()`](https://reprostats.org/lineager/reference/lg_report.md)
compiles the full session into a self-contained HTML document. It draws
from everything accumulated during the session:

| Report section | Source |
|----|----|
| Dataset Inventory | All [`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md) calls |
| Subject Disposition | All [`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md) exclusions |
| Population Definitions | All [`lg_population()`](https://reprostats.org/lineager/reference/lg_population.md) registrations |
| Variable Derivations | All [`lg_spec()`](https://reprostats.org/lineager/reference/lg_spec.md) registrations |
| Operation Log | All [`lg_derive()`](https://reprostats.org/lineager/reference/lg_derive.md), [`lg_join()`](https://reprostats.org/lineager/reference/lg_join.md), [`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md) calls |
| Exclusion Listing | Full exclusion registry |

### In-memory report (inspect without writing to disk)

``` r

html <- lg_report(
  output   = NULL,
  title    = "Data Provenance Report",
  study_id = "TRIAL-001",
  author   = "Ndoh Penn"
)

cat("Report size:", nchar(html), "characters\n")
#> Report size: 7109 characters
cat("Sections found:\n")
#> Sections found:
sections <- c(
  "Dataset Inventory", "Subject Disposition",
  "Population Flag", "Variable Derivation",
  "Operation Log", "Exclusion Listing"
)
for (s in sections) {
  cat(
    " ", if (grepl(s, html, ignore.case = TRUE)) "[YES]" else "[NO]",
    s, "\n"
  )
}
#>   [YES] Dataset Inventory 
#>   [YES] Subject Disposition 
#>   [YES] Population Flag 
#>   [YES] Variable Derivation 
#>   [YES] Operation Log 
#>   [YES] Exclusion Listing
```

### Write to file

``` r

lg_report(
  output   = "outputs/provenance_TRIAL001_primary.html",
  title    = "Data Provenance Report — TRIAL-001 Primary Analysis",
  study_id = "TRIAL-001",
  sponsor  = "Example Pharma Ltd",
  author   = "Ndoh Penn, Biostatistician",
  date     = as.Date("2026-06-23")
)
```

The report is entirely self-contained HTML — no external CSS, no
JavaScript, no internet connection required at render time. It opens in
any browser and can be attached to a regulatory submission package.

### Report arguments

| Argument | Default | Purpose |
|----|----|----|
| `format` | `"html"` | Output format (currently only HTML) |
| `output` | `NULL` | File path; `NULL` returns the HTML string |
| `title` | `"Data Provenance Report"` | Report title |
| `study_id` | Session `study_id` | Study identifier for header |
| `sponsor` | `NULL` | Sponsor name |
| `author` | `NULL` | Analyst name |
| `date` | [`Sys.Date()`](https://rdrr.io/r/base/Sys.time.html) | Report date |

## 4. A note on CDISC-specific usage

All functions in this vignette work identically for CDISC clinical data.
For pharmaceutical users:

- Pass `domain = "DM"` etc. in
  [`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md) —
  domain appears in dataset inventory and distinguishes SDTM domains
  from ADaM datasets
- `USUBJID` column is detected automatically and embedded in `.__lid__`
  values for human readability
- [`lg_population()`](https://reprostats.org/lineager/reference/lg_population.md)
  naturally documents SAFFL, ITTFL, PPROTFL — the labels and definitions
  become the Reviewer’s Guide population section
- [`lg_spec()`](https://reprostats.org/lineager/reference/lg_spec.md)
  documents SDTM-to-ADaM variable mappings — the report output aligns
  with the “Variable Derivations” section of the Reviewer’s Guide

For non-CDISC users, these arguments and features are entirely optional.
The core workflow — tag, filter, trace, report — works without any
CDISC-specific configuration.

## 5. Visualise the pipeline lineage

[`lg_lineage()`](https://reprostats.org/lineager/reference/lg_lineage.md)
builds a graph of the complete pipeline — source datasets, all
derive/join/filter operations, and exclusion branches — as a Graphviz
DOT string.
[`lg_plot()`](https://reprostats.org/lineager/reference/lg_plot.md)
renders it inline or writes it to a file.

``` r

lin <- lg_lineage()
print(lin)
#> <lg_lineage>  2 source dataset(s), 7 operation(s), 3 exclusion branch(es)
#> Use lg_plot(lin) to render. DOT source:
#> 
#> digraph lineage {
#>   rankdir = TB;
#>   graph [fontname="Helvetica", splines=ortho, nodesep=0.4, ranksep=0.6];
#>   node  [fontname="Helvetica", fontsize=10, margin="0.15,0.08"];
#>   edge  [fontname="Helvetica", fontsize=9, color="#6b6f80"];
#> 
#>   SRC_PATIENTS [label="PATIENTS\nn = 15", shape=box, style="filled,rounded", fillcolor="#e8effe", color="#1a56db", fontcolor="#0f1117"];
#>   SRC_LABS [label="LABS\nn = 12", shape=box, style="filled,rounded", fillcolor="#e8effe", color="#1a56db", fontcolor="#0f1117"];
#>   OP_op_0001 [label="DERIVE\nadult: TRUE if age >= 18 years", shape=ellipse, style="filled,rounded", fillcolor="#fff8e1", color="#f59e0b", fontcolor="#0f1117"];
#>   DS_PATIENTS_op_0001 [label="PATIENTS\nn = 15", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   OP_op_0002 [label="DERIVE\nENRLFL: enrolled; DOSEFL: enroll...", shape=ellipse, style="filled,rounded", fillcolor="#fff8e1", color="#f59e0b", fontcolor="#0f1117"];
#>   DS_PATIENTS_op_0002 [label="PATIENTS\nn = 15", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   OP_op_0003 [label="JOIN (left)\nby: USUBJID", shape=diamond, style="filled,rounded", fillcolor="#e8f5e9", color="#0e7a4f", fontcolor="#0f1117"];
#>   DS_PATIENTS_op_0003 [label="PATIENTS\nn = 15", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   OP_op_0004 [label="DERIVE\nCHG: absolute change from baseli...", shape=ellipse, style="filled,rounded", fillcolor="#fff8e1", color="#f59e0b", fontcolor="#0f1117"];
#>   DS_PATIENTS_op_0004 [label="PATIENTS\nn = 15", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   OP_op_0005 [label="FILTER\nNot enrolled or under 18\n−3 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
#>   DS_PATIENTS_op_0005 [label="PATIENTS\nn = 12", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   EXCL_op_0005 [label="excluded\nn = 3", shape=plaintext, fontcolor="#dc2626", fontsize=9];
#>   OP_op_0006 [label="FILTER\nDid not receive study treatment\n−1 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
#>   DS_PATIENTS_op_0006 [label="PATIENTS\nn = 11", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   EXCL_op_0006 [label="excluded\nn = 1", shape=plaintext, fontcolor="#dc2626", fontsize=9];
#>   OP_op_0007 [label="FILTER\nMissing primary endpoint measure...\n−2 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
#>   DS_PATIENTS_op_0007 [label="PATIENTS\nn = 9", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   EXCL_op_0007 [label="excluded\nn = 2", shape=plaintext, fontcolor="#dc2626", fontsize=9];
#> 
#>   SRC_PATIENTS -> OP_op_0001;
#>   OP_op_0001 -> DS_PATIENTS_op_0001;
#>   DS_PATIENTS_op_0001 -> OP_op_0002;
#>   OP_op_0002 -> DS_PATIENTS_op_0002;
#>   DS_PATIENTS_op_0002 -> OP_op_0003 [label=" x "];
#>   SRC_LABS -> OP_op_0003 [label=" y "];
#>   OP_op_0003 -> DS_PATIENTS_op_0003;
#>   DS_PATIENTS_op_0003 -> OP_op_0004;
#>   OP_op_0004 -> DS_PATIENTS_op_0004;
#>   DS_PATIENTS_op_0004 -> OP_op_0005 [label=" n=15 "];
#>   OP_op_0005 -> DS_PATIENTS_op_0005;
#>   OP_op_0005 -> EXCL_op_0005;
#>   DS_PATIENTS_op_0005 -> OP_op_0006 [label=" n=12 "];
#>   OP_op_0006 -> DS_PATIENTS_op_0006;
#>   OP_op_0006 -> EXCL_op_0006;
#>   DS_PATIENTS_op_0006 -> OP_op_0007 [label=" n=11 "];
#>   OP_op_0007 -> DS_PATIENTS_op_0007;
#>   OP_op_0007 -> EXCL_op_0007;
#> }
```

``` r

# Render inline (requires DiagrammeR)
lg_plot(lin)

# Export DOT for Graphviz or https://dreampuf.github.io/GraphvizOnline/
lg_plot(lin, output = "outputs/pipeline.dot")
```

The lineage graph for this pipeline shows the two source datasets
(PATIENTS and LABS) flowing through four derive steps, a left join, and
three filter steps with exclusion branches at each stage.

## 6. End the session

``` r

lg_end()
#> lineager: session ended — 7 operation(s), 6 exclusion(s), 2 population(s), 4 var spec(s)
```
