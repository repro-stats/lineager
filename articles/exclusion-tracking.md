# Exclusion tracking and subject tracing

The ability to say exactly which rows were excluded, why, and what
happened to a specific row across the whole pipeline is one of the
primary values of `lineager`. This vignette covers all the tools for
that:
[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
in depth, the exclusion registry, disposition tables, and subject-level
tracing.

## Setup: a realistic multi-stage pipeline

We build a cohort through three exclusion stages — a pattern common to
clinical trials, epidemiological studies, machine learning pipelines,
and observational research.

``` r

lg_start(study_id = "COHORT-001", analysis_id = "main-analysis")
#> lineager: session started [study: COHORT-001] [analysis: main-analysis]

# Simulate a patient registry
set.seed(42)
n <- 20L

raw <- data.frame(
  USUBJID    = sprintf("PT-%03d", seq_len(n)),
  age        = sample(15:75, n, replace = TRUE),
  sex        = sample(c("M", "F"), n, replace = TRUE),
  diagnosis  = sample(c("Y", "N", "N"), n, replace = TRUE),
  consent    = sample(c("Y", "Y", "Y", "N"), n, replace = TRUE),
  prior_drug = sample(c("Y", "N", "N", "N"), n, replace = TRUE),
  biomarker  = round(runif(n, 0.5, 8.5), 2),
  outcome    = ifelse(runif(n) > 0.4, round(rnorm(n, 50, 12), 1), NA_real_),
  stringsAsFactors = FALSE
)

registry <- lg_tag(raw, dataset_id = "REGISTRY",
                   label = "Patient registry — all screened")
#> lineager: tagged 'REGISTRY' — 20 rows, 8 cols

cat("Screened: ", nrow(registry), "patients\n")
#> Screened:  20 patients
```

## 1. lg_filter() in depth

### Mandatory reason

Every call to
[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
requires a `reason`. The reason becomes the canonical documentation for
that exclusion step — it appears in
[`lg_exclusions()`](https://reprostats.org/lineager/reference/lg_exclusions.md),
[`lg_disposition()`](https://reprostats.org/lineager/reference/lg_disposition.md),
[`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md),
and
[`lg_report()`](https://reprostats.org/lineager/reference/lg_report.md).

``` r

# This would error:
# lg_filter(registry, age >= 18L)
# Error: A `reason` is required.

# Correct:
adults <- lg_filter(registry,
  age >= 18L,
  reason = "Under minimum age threshold (age < 18 years)"
)
#> lineager: [REGISTRY] filter 'Under minimum age threshold (age < 18 years)' — 20 in, 19 out, 1 excluded
```

### reason_code: machine-readable classification

`reason_code` provides a short, controlled-vocabulary label for the
exclusion — useful for grouping similar exclusions programmatically.

``` r

consented <- lg_filter(adults,
  consent == "Y",
  reason      = "Did not provide written informed consent",
  reason_code = "NO_CONSENT"
)
#> lineager: [REGISTRY] filter 'Did not provide written informed consent' — 19 in, 15 out, 4 excluded

diagnosed <- lg_filter(consented,
  diagnosis == "Y",
  reason      = "Does not meet diagnostic criteria per protocol section 3.1",
  reason_code = "NO_DIAGNOSIS"
)
#> lineager: [REGISTRY] filter 'Does not meet diagnostic criteria per protocol section 3.1' — 15 in, 2 out, 13 excluded
```

### population: grouping exclusions by analysis set

`population` groups exclusions into named cohorts — corresponding to
analysis set flags in clinical data (SAFFL, ITTFL, etc.) or cohort
definitions in epidemiology.

``` r

no_prior <- lg_filter(diagnosed,
  prior_drug == "N",
  reason      = "Received prohibited prior medication within wash-out period",
  reason_code = "PRIOR_MED",
  population  = "ELIGIBLE_SET"
)
#> lineager: [REGISTRY] filter 'Received prohibited prior medication within wash-out period' — 2 in, 2 out, 0 excluded

biomarker_pos <- lg_filter(no_prior,
  biomarker >= 2.0,
  reason      = "Biomarker below threshold (< 2.0) per protocol section 4.3",
  reason_code = "LOW_BIOMARKER",
  population  = "BIOMARKER_POS"
)
#> lineager: [REGISTRY] filter 'Biomarker below threshold (< 2.0) per protocol section 4.3' — 2 in, 2 out, 0 excluded

analysis_set <- lg_filter(biomarker_pos,
  !is.na(outcome),
  reason      = "Missing primary outcome measurement",
  reason_code = "MISSING_OUTCOME",
  population  = "ANALYSIS_SET"
)
#> lineager: [REGISTRY] filter 'Missing primary outcome measurement' — 2 in, 1 out, 1 excluded

cat("Screened:     ", nrow(registry),     "\n")
#> Screened:      20
cat("Adults:       ", nrow(adults),       "\n")
#> Adults:        19
cat("Consented:    ", nrow(consented),    "\n")
#> Consented:     15
cat("Diagnosed:    ", nrow(diagnosed),    "\n")
#> Diagnosed:     2
cat("No prior med: ", nrow(no_prior),     "\n")
#> No prior med:  2
cat("Biomarker+:   ", nrow(biomarker_pos),"\n")
#> Biomarker+:    2
cat("Analysis set: ", nrow(analysis_set), "\n")
#> Analysis set:  1
```

## 2. The exclusion registry

Every excluded row is captured in the session store as a structured
record.
[`lg_exclusions()`](https://reprostats.org/lineager/reference/lg_exclusions.md)
retrieves the full registry as a data frame.

``` r

excl <- lg_exclusions()
#> lineager: 19 exclusion(s) retrieved
cat("Total exclusions:", nrow(excl), "\n")
#> Total exclusions: 19
names(excl)
#> [1] "excl_id"     "op_id"       "dataset_id"  "lid"         "usubjid"    
#> [6] "reason"      "reason_code" "population"  "excluded_at"
```

### Filter by population

``` r

# Only exclusions related to the final analysis set
analysis_excl <- lg_exclusions(population = "ANALYSIS_SET")
#> lineager: 1 exclusion(s) retrieved
analysis_excl[, c("usubjid", "reason", "reason_code")]
#>   usubjid                              reason     reason_code
#> 1  PT-013 Missing primary outcome measurement MISSING_OUTCOME
```

### Filter by dataset

When multiple datasets are tagged and filtered, query by dataset:

``` r

lg_exclusions(dataset_id = "REGISTRY")[,
  c("usubjid", "reason_code", "population")]
#> lineager: 19 exclusion(s) retrieved
#>    usubjid     reason_code   population
#> 1   PT-003            <NA>         <NA>
#> 2   PT-007      NO_CONSENT         <NA>
#> 3   PT-012      NO_CONSENT         <NA>
#> 4   PT-017      NO_CONSENT         <NA>
#> 5   PT-018      NO_CONSENT         <NA>
#> 6   PT-001    NO_DIAGNOSIS         <NA>
#> 7   PT-002    NO_DIAGNOSIS         <NA>
#> 8   PT-004    NO_DIAGNOSIS         <NA>
#> 9   PT-005    NO_DIAGNOSIS         <NA>
#> 10  PT-008    NO_DIAGNOSIS         <NA>
#> 11  PT-009    NO_DIAGNOSIS         <NA>
#> 12  PT-010    NO_DIAGNOSIS         <NA>
#> 13  PT-011    NO_DIAGNOSIS         <NA>
#> 14  PT-014    NO_DIAGNOSIS         <NA>
#> 15  PT-015    NO_DIAGNOSIS         <NA>
#> 16  PT-016    NO_DIAGNOSIS         <NA>
#> 17  PT-019    NO_DIAGNOSIS         <NA>
#> 18  PT-020    NO_DIAGNOSIS         <NA>
#> 19  PT-013 MISSING_OUTCOME ANALYSIS_SET
```

### The exclusion record structure

Each exclusion record contains:

| Field | Content |
|----|----|
| `excl_id` | Unique exclusion identifier (`op_0001_excl_0001`) |
| `op_id` | Which [`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md) operation caused this |
| `dataset_id` | Which dataset the row was removed from |
| `lid` | The `.__lid__` of the excluded row |
| `usubjid` | Subject identifier (from USUBJID column if present) |
| `reason` | The documented exclusion reason |
| `reason_code` | Short code for programmatic grouping |
| `population` | Which population/cohort this relates to |
| `excluded_at` | UTC timestamp of exclusion |

## 3. Disposition tables

[`lg_disposition()`](https://reprostats.org/lineager/reference/lg_disposition.md)
aggregates the exclusion registry into a grouped summary — the data
behind a CONSORT flow diagram or study disposition table.

### Group by reason

``` r

lg_disposition(by = "reason")
#>                                                        group n_excluded
#> 1 Does not meet diagnostic criteria per protocol section 3.1         13
#> 2                   Did not provide written informed consent          4
#> 3                        Missing primary outcome measurement          1
#> 4               Under minimum age threshold (age < 18 years)          1
```

### Group by population

``` r

lg_disposition(by = "population")
#>          group n_excluded
#> 1 ANALYSIS_SET          1
```

### Group by dataset

Useful when multiple source datasets are filtered:

``` r

lg_disposition(by = "dataset")
#>      group n_excluded
#> 1 REGISTRY         19
```

## 4. Subject tracing

[`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md)
returns the complete history of a row identified by its USUBJID or any
substring matching its lineage ID. This is `lineager`’s most distinctive
capability.

### Tracing an excluded subject

``` r

# Find a subject who was excluded
excluded_id <- lg_exclusions()$usubjid[[1L]]
#> lineager: 19 exclusion(s) retrieved
cat("Tracing excluded subject:", excluded_id, "\n")
#> Tracing excluded subject: PT-003

lg_trace(excluded_id)
#> 
#> ── lineager trace: USUBJID 'PT-003' ──
#> 
#>   Appears in: REGISTRY
#> 
#>   Operations:
#>     [FILTER] REGISTRY: Under minimum age threshold (age < 18 years) (20→19)
#>     [FILTER] REGISTRY: Did not provide written informed consent (19→15)
#>     [FILTER] REGISTRY: Does not meet diagnostic criteria per protocol section 3.1 (15→2)
#>     [FILTER] REGISTRY: Received prohibited prior medication within wash-out period (2→2)
#>     [FILTER] REGISTRY: Biomarker below threshold (< 2.0) per protocol section 4.3 (2→2)
#>     [FILTER] REGISTRY: Missing primary outcome measurement (2→1)
#> 
#>   Exclusions (1):
#>     ✗ [REGISTRY] Under minimum age threshold (age < 18 years)
```

The trace shows: - Which tagged datasets contain this row - Which
operations (in order) touched datasets containing this row - All
exclusion records for this row, with reasons and population

### Tracing an included subject

``` r

included_id <- analysis_set$USUBJID[[1L]]
cat("Tracing included subject:", included_id, "\n")
#> Tracing included subject: PT-006

lg_trace(included_id)
#> 
#> ── lineager trace: USUBJID 'PT-006' ──
#> 
#>   Appears in: REGISTRY
#> 
#>   Operations:
#>     [FILTER] REGISTRY: Under minimum age threshold (age < 18 years) (20→19)
#>     [FILTER] REGISTRY: Did not provide written informed consent (19→15)
#>     [FILTER] REGISTRY: Does not meet diagnostic criteria per protocol section 3.1 (15→2)
#>     [FILTER] REGISTRY: Received prohibited prior medication within wash-out period (2→2)
#>     [FILTER] REGISTRY: Biomarker below threshold (< 2.0) per protocol section 4.3 (2→2)
#>     [FILTER] REGISTRY: Missing primary outcome measurement (2→1)
#> 
#>   Exclusions: none
```

For included subjects, the exclusions section will be empty — they
passed every filter.

### Tracing a subject not found

``` r

result <- lg_trace("PT-999", verbose = FALSE)
cat("Datasets found in:", length(result$datasets), "\n")
#> Datasets found in: 0
```

### Using the trace result programmatically

[`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md)
returns its result invisibly — capture it for programmatic use:

``` r

result <- lg_trace(excluded_id, verbose = FALSE)

cat("Subject:       ", result$usubjid,           "\n")
#> Subject:        PT-003
cat("Found in:      ", paste(result$datasets, collapse = ", "), "\n")
#> Found in:       REGISTRY
cat("Operations:    ", nrow(result$operations),  "\n")
#> Operations:     6
cat("Exclusions:    ", nrow(result$exclusions),  "\n")
#> Exclusions:     1

if (nrow(result$exclusions) > 0L) {
  cat("Excluded by:   ", result$exclusions$reason[[1L]], "\n")
  cat("Population:    ", result$exclusions$population[[1L]], "\n")
}
#> Excluded by:    Under minimum age threshold (age < 18 years) 
#> Population:     NA
```

## 5. The operation log

[`lg_operations()`](https://reprostats.org/lineager/reference/lg_operations.md)
returns the full sequence of operations as a data frame — useful for
understanding the pipeline structure and for automating documentation.

``` r

ops <- lg_operations()
ops[, c("op_id", "op_type", "dataset_id", "description",
        "rows_in", "rows_out")]
#>     op_id op_type dataset_id
#> 1 op_0001  FILTER   REGISTRY
#> 2 op_0002  FILTER   REGISTRY
#> 3 op_0003  FILTER   REGISTRY
#> 4 op_0004  FILTER   REGISTRY
#> 5 op_0005  FILTER   REGISTRY
#> 6 op_0006  FILTER   REGISTRY
#>                                                   description rows_in rows_out
#> 1                Under minimum age threshold (age < 18 years)      20       19
#> 2                    Did not provide written informed consent      19       15
#> 3  Does not meet diagnostic criteria per protocol section 3.1      15        2
#> 4 Received prohibited prior medication within wash-out period       2        2
#> 5  Biomarker below threshold (< 2.0) per protocol section 4.3       2        2
#> 6                         Missing primary outcome measurement       2        1
```

The difference between `rows_in` and `rows_out` is the number of rows
excluded by that operation — matching the exclusion records registered
at that step.

``` r

# Verify: total excluded == sum of (rows_in - rows_out) across FILTER ops
filter_ops <- ops[ops$op_type == "FILTER", ]
total_via_ops  <- sum(filter_ops$rows_in - filter_ops$rows_out)
total_via_excl <- nrow(lg_exclusions())
#> lineager: 19 exclusion(s) retrieved
cat("Excluded via ops:  ", total_via_ops,  "\n")
#> Excluded via ops:   19
cat("Excluded via excl: ", total_via_excl, "\n")
#> Excluded via excl:  19
cat("Match:             ", total_via_ops == total_via_excl, "\n")
#> Match:              TRUE
```

## 6. Visualise exclusions as a lineage graph

After building a pipeline,
[`lg_lineage()`](https://reprostats.org/lineager/reference/lg_lineage.md)
produces a visual summary showing each filter step, how many rows it
removed, and where exclusion branches occur — complementing the tabular
output of
[`lg_exclusions()`](https://reprostats.org/lineager/reference/lg_exclusions.md)
and
[`lg_disposition()`](https://reprostats.org/lineager/reference/lg_disposition.md).

``` r

lin <- lg_lineage()
print(lin)
#> <lg_lineage>  1 source dataset(s), 6 operation(s), 4 exclusion branch(es)
#> Use lg_plot(lin) to render. DOT source:
#> 
#> digraph lineage {
#>   rankdir = TB;
#>   graph [fontname="Helvetica", splines=ortho, nodesep=0.4, ranksep=0.6];
#>   node  [fontname="Helvetica", fontsize=10, margin="0.15,0.08"];
#>   edge  [fontname="Helvetica", fontsize=9, color="#6b6f80"];
#> 
#>   SRC_REGISTRY [label="REGISTRY\nn = 20", shape=box, style="filled,rounded", fillcolor="#e8effe", color="#1a56db", fontcolor="#0f1117"];
#>   OP_op_0001 [label="FILTER\nUnder minimum age threshold (age...\n−1 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
#>   DS_REGISTRY_op_0001 [label="REGISTRY\nn = 19", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   EXCL_op_0001 [label="excluded\nn = 1", shape=plaintext, fontcolor="#dc2626", fontsize=9];
#>   OP_op_0002 [label="FILTER\nDid not provide written informed...\n−4 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
#>   DS_REGISTRY_op_0002 [label="REGISTRY\nn = 15", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   EXCL_op_0002 [label="excluded\nn = 4", shape=plaintext, fontcolor="#dc2626", fontsize=9];
#>   OP_op_0003 [label="FILTER\nDoes not meet diagnostic criteri...\n−13 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
#>   DS_REGISTRY_op_0003 [label="REGISTRY\nn = 2", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   EXCL_op_0003 [label="excluded\nn = 13", shape=plaintext, fontcolor="#dc2626", fontsize=9];
#>   OP_op_0004 [label="FILTER\nReceived prohibited prior medica...\n−0 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
#>   DS_REGISTRY_op_0004 [label="REGISTRY\nn = 2", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   OP_op_0005 [label="FILTER\nBiomarker below threshold (< 2.0...\n−0 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
#>   DS_REGISTRY_op_0005 [label="REGISTRY\nn = 2", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   OP_op_0006 [label="FILTER\nMissing primary outcome measurement\n−1 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
#>   DS_REGISTRY_op_0006 [label="REGISTRY\nn = 1", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   EXCL_op_0006 [label="excluded\nn = 1", shape=plaintext, fontcolor="#dc2626", fontsize=9];
#> 
#>   SRC_REGISTRY -> OP_op_0001 [label=" n=20 "];
#>   OP_op_0001 -> DS_REGISTRY_op_0001;
#>   OP_op_0001 -> EXCL_op_0001;
#>   DS_REGISTRY_op_0001 -> OP_op_0002 [label=" n=19 "];
#>   OP_op_0002 -> DS_REGISTRY_op_0002;
#>   OP_op_0002 -> EXCL_op_0002;
#>   DS_REGISTRY_op_0002 -> OP_op_0003 [label=" n=15 "];
#>   OP_op_0003 -> DS_REGISTRY_op_0003;
#>   OP_op_0003 -> EXCL_op_0003;
#>   DS_REGISTRY_op_0003 -> OP_op_0004 [label=" n=2 "];
#>   OP_op_0004 -> DS_REGISTRY_op_0004;
#>   DS_REGISTRY_op_0004 -> OP_op_0005 [label=" n=2 "];
#>   OP_op_0005 -> DS_REGISTRY_op_0005;
#>   DS_REGISTRY_op_0005 -> OP_op_0006 [label=" n=2 "];
#>   OP_op_0006 -> DS_REGISTRY_op_0006;
#>   OP_op_0006 -> EXCL_op_0006;
#> }
```

``` r

lg_plot(lin)
```

## 7. Common patterns

### Cascaded filters with verbose tracking

``` r

lg_start()
#> lineager: session started

cohort <- lg_tag(
  data.frame(
    id = sprintf("S%02d", 1:10),
    enrolled = c(rep(TRUE, 8), FALSE, FALSE),
    treated  = c(rep(TRUE, 6), FALSE, FALSE, FALSE, FALSE),
    complete = c(rep(TRUE, 4), FALSE, FALSE, rep(FALSE, 4)),
    stringsAsFactors = FALSE
  ),
  dataset_id = "COHORT"
)
#> lineager: tagged 'COHORT' — 10 rows, 4 cols

step1 <- lg_filter(cohort,  enrolled == TRUE,
                   reason = "Not enrolled in study")
#> lineager: [COHORT] filter 'Not enrolled in study' — 10 in, 8 out, 2 excluded
step2 <- lg_filter(step1,   treated  == TRUE,
                   reason = "Did not receive study treatment")
#> lineager: [COHORT] filter 'Did not receive study treatment' — 8 in, 6 out, 2 excluded
step3 <- lg_filter(step2,   complete == TRUE,
                   reason = "Did not complete the study")
#> lineager: [COHORT] filter 'Did not complete the study' — 6 in, 4 out, 2 excluded

cat("Enrolled:  ", nrow(step1), "\n")
#> Enrolled:   8
cat("Treated:   ", nrow(step2), "\n")
#> Treated:    6
cat("Completed: ", nrow(step3), "\n")
#> Completed:  4

lg_disposition(by = "reason")
#>                             group n_excluded
#> 1      Did not complete the study          2
#> 2 Did not receive study treatment          2
#> 3           Not enrolled in study          2
```

``` r

lg_end()
#> lineager: session ended — 3 operation(s), 6 exclusion(s), 0 population(s), 0 var spec(s)
```

Continue to
[`vignette("populations-and-reporting")`](https://reprostats.org/lineager/articles/populations-and-reporting.md)
for population flag registration and report generation.
