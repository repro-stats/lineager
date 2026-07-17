# Getting started with lineager

You build an analysis dataset. Along the way rows disappear — filtered
out, dropped in joins, excluded by criteria. Later someone asks: *“Which
records were removed, why, and what happened to row 42 between source
and analysis?”*

Without `lineager`, that answer requires manual reconstruction. With
`lineager`, it is a single function call.

`lineager` tags every row of every dataset with a unique lineage
identifier that survives filters, joins, and derivations. Every row
removal requires a documented reason. At any point,
[`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md)
returns any row’s complete journey across the pipeline.
[`lg_report()`](https://reprostats.org/lineager/reference/lg_report.md)
compiles everything into a structured provenance document.

## 1. Start a session

All `lineager` state lives in a session store reset by
[`lg_start()`](https://reprostats.org/lineager/reference/lg_start.md).
Call it once at the top of your analysis.

``` r

lg_start(study_id = "PROJECT-001", analysis_id = "primary")
#> lineager: session started [study: PROJECT-001] [analysis: primary]
```

The optional `study_id` and `analysis_id` appear in reports. They can be
any strings — or omitted entirely.

## 2. Tag your source datasets

[`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md) is the
entry point. It assigns a `lineage_id` (lineage ID) to every row at
position 1. This ID persists through all operations.

``` r

patients <- data.frame(
  USUBJID = c("P001", "P002", "P003", "P004", "P005", "P006"),
  age = c(34L, 19L, 52L, 28L, 61L, 44L),
  group = c("A", "B", "A", "B", "A", "B"),
  eligible = c(TRUE, FALSE, TRUE, TRUE, FALSE, TRUE),
  stringsAsFactors = FALSE
)

tagged <- lg_tag(patients,
  dataset_id = "PATIENTS",
  label = "Patient registry"
)
#> lineager: tagged 'PATIENTS' — 6 rows, 4 cols

tagged
#> <lg_df> 'PATIENTS'  [6 × 5]
#>   USUBJID age group eligible
#> 1    P001  34     A     TRUE
#> 2    P002  19     B    FALSE
#> 3    P003  52     A     TRUE
#> 4    P004  28     B     TRUE
#> 5    P005  61     A    FALSE
#> 6    P006  44     B     TRUE
```

The lineage ID format embeds the dataset ID and a zero-padded sequence.
When a `USUBJID` column is present (CDISC datasets), it is also embedded
for human readability:

    PATIENTS_000001   ← non-CDISC: dataset + sequence
    DM_0001_01-042    ← CDISC: dataset + sequence + USUBJID

### Tagging multiple datasets

Tag all source datasets before any transformations:

``` r

labs <- data.frame(
  USUBJID = c("P001", "P001", "P003", "P004", "P006"),
  test = c("ALT", "AST", "ALT", "ALT", "ALT"),
  value = c(28.4, 31.2, 45.1, 22.8, 38.6),
  stringsAsFactors = FALSE
)

labs_tagged <- lg_tag(labs, dataset_id = "LABS", label = "Laboratory results")
#> lineager: tagged 'LABS' — 5 rows, 3 cols

cat("Patients tagged:", nrow(tagged), "rows\n")
#> Patients tagged: 6 rows
cat("Labs tagged:    ", nrow(labs_tagged), "rows\n")
#> Labs tagged:     5 rows
```

## 3. Derive new variables

[`lg_derive()`](https://reprostats.org/lineager/reference/lg_derive.md)
works like
[`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)
but requires a `description` argument that is recorded in the operation
log.

``` r

derived <- lg_derive(tagged,
  age_group = ifelse(age >= 40L, ">=40", "<40"),
  adult = age >= 18L,
  description = "age_group: >=40 vs <40 from age; adult: age >= 18"
)
#> lineager: [PATIENTS] derive — age_group: >=40 vs <40 from age; adult: age >= 18

derived[, c("USUBJID", "age", "age_group", "adult")]
#> <lg_df> 'PATIENTS'  [6 × 4]
#>   USUBJID age age_group adult
#> 1    P001  34       <40  TRUE
#> 2    P002  19       <40  TRUE
#> 3    P003  52      >=40  TRUE
#> 4    P004  28       <40  TRUE
#> 5    P005  61      >=40  TRUE
#> 6    P006  44      >=40  TRUE
```

The `lineage_id` column is preserved unchanged through derivations:

``` r

all(derived[["lineage_id"]] == tagged[["lineage_id"]])
#> [1] TRUE
```

Chain derivations naturally:

``` r

derived2 <- lg_derive(derived,
  label = paste0(USUBJID, " (", group, ")"),
  description = "Display label combining USUBJID and group"
)
#> lineager: [PATIENTS] derive — Display label combining USUBJID and group

derived2[, c("lineage_id", "USUBJID", "group", "label")]
#> <lg_df> 'PATIENTS'  [6 × 4]
#>   USUBJID group    label
#> 1    P001     A P001 (A)
#> 2    P002     B P002 (B)
#> 3    P003     A P003 (A)
#> 4    P004     B P004 (B)
#> 5    P005     A P005 (A)
#> 6    P006     B P006 (B)
```

Each call adds one `DERIVE` operation to the session log.

## 4. Join datasets with lineage tracking

[`lg_join()`](https://reprostats.org/lineager/reference/lg_join.md)
performs a tracked join. It preserves `lineage_id` from the left dataset
and adds `lineage_id_y` to record which rows from the right dataset
contributed — enabling bilateral tracing.

``` r

joined <- lg_join(tagged, labs_tagged,
  by          = "USUBJID",
  type        = "left",
  description = "Merge ALT lab values from LABS onto PATIENTS"
)
#> lineager: [PATIENTS + LABS] left join — 7 rows out

joined[, c("lineage_id", "USUBJID", "eligible", "test", "value", "lineage_id_y")]
#> <lg_df> 'PATIENTS'  [7 × 6]
#>   USUBJID eligible test value   lineage_id_y
#> 1    P001     TRUE  ALT  28.4 LABS_0001_P001
#> 2    P001     TRUE  AST  31.2 LABS_0002_P001
#> 3    P002    FALSE <NA>    NA           <NA>
#> 4    P003     TRUE  ALT  45.1 LABS_0003_P003
#> 5    P004     TRUE  ALT  22.8 LABS_0004_P004
#> 6    P005    FALSE <NA>    NA           <NA>
#> # … 1 more rows
```

The `lineage_id_y` column shows which LABS row contributed to each
PATIENTS row. Rows with no matching lab record have `NA` in
`lineage_id_y`.

Supported join types:

``` r

lg_join(x, y, by = "USUBJID", type = "left") # all rows of x
lg_join(x, y, by = "USUBJID", type = "inner") # only matching rows
lg_join(x, y, by = "USUBJID", type = "full") # all rows of both
lg_join(x, y, by = "USUBJID", type = "right") # all rows of y
```

## 5. Filter with mandatory exclusion reasons

[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
works like
[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
but the `reason` argument is **mandatory with no default**. Every row
removal must be documented.

Excluded rows and their IDs are captured in the session exclusion
registry automatically.

``` r

eligible_only <- lg_filter(tagged,
  eligible == TRUE,
  reason = "Not eligible for analysis (eligible != TRUE)"
)
#> lineager: [PATIENTS] filter 'Not eligible for analysis (eligible != TRUE)' — 6 in, 4 out, 2 excluded

cat("Before:", nrow(tagged), "\n")
#> Before: 6
cat("After: ", nrow(eligible_only), "\n")
#> After:  4
```

Optional arguments enrich the exclusion record:

| Argument | Purpose | Example |
|----|----|----|
| `reason` | Why these rows are excluded (required) | `"Under age threshold"` |
| `reason_code` | Short controlled-vocabulary code | `"UNDERAGE"` |
| `population` | Which population/cohort this relates to | `"ANALYSIS_SET"` |

``` r

# reason_code and population enrich the exclusion record
step1 <- lg_filter(tagged,
  eligible == TRUE,
  reason = "Screening criteria not met (eligible != TRUE)",
  reason_code = "SCREEN_FAIL",
  population = "ELIGIBLE_SET"
)
#> lineager: [PATIENTS] filter 'Screening criteria not met (eligible != TRUE)' — 6 in, 4 out, 2 excluded

step2 <- lg_filter(step1,
  age >= 18L,
  reason = "Under minimum age threshold (age < 18)",
  reason_code = "UNDERAGE",
  population = "ADULT_SET"
)
#> lineager: [PATIENTS] filter 'Under minimum age threshold (age < 18)' — 4 in, 4 out, 0 excluded

cat("Enrolled: ", nrow(tagged), "\n")
#> Enrolled:  6
cat("Eligible: ", nrow(step1), "\n")
#> Eligible:  4
cat("Adult:    ", nrow(step2), "\n")
#> Adult:     4
```

## 6. The session operation log

Every
[`lg_derive()`](https://reprostats.org/lineager/reference/lg_derive.md),
[`lg_join()`](https://reprostats.org/lineager/reference/lg_join.md), and
[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
call adds an entry to the session operation log. Retrieve it with
[`lg_operations()`](https://reprostats.org/lineager/reference/lg_operations.md):

``` r

ops <- lg_operations()
#> lineager: 6 operation(s) in log
ops[, c("op_id", "op_type", "description", "rows_in", "rows_out")]
#>     op_id   op_type                                       description rows_in
#> 1 op_0001    DERIVE age_group: >=40 vs <40 from age; adult: age >= 18       6
#> 2 op_0002    DERIVE         Display label combining USUBJID and group       6
#> 3 op_0003 JOIN_LEFT      Merge ALT lab values from LABS onto PATIENTS       6
#> 4 op_0004    FILTER      Not eligible for analysis (eligible != TRUE)       6
#> 5 op_0005    FILTER     Screening criteria not met (eligible != TRUE)       6
#> 6 op_0006    FILTER            Under minimum age threshold (age < 18)       4
#>   rows_out
#> 1        6
#> 2        6
#> 3        7
#> 4        4
#> 5        4
#> 6        4
```

The operation log is the backbone of the provenance report — it shows
the complete sequence of transformations applied to the data.

## 7. End the session

``` r

lg_end()
#> lineager: session ended — 6 operation(s), 4 exclusion(s), 0 population(s), 0 var spec(s)
```

[`lg_end()`](https://reprostats.org/lineager/reference/lg_end.md) marks
the session inactive and prints a summary. The store remains in memory
and is still queryable via
[`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md),
[`lg_exclusions()`](https://reprostats.org/lineager/reference/lg_exclusions.md),
etc. until
[`lg_start()`](https://reprostats.org/lineager/reference/lg_start.md) is
called again.

## 8. Complete minimal workflow

``` r

lg_start(study_id = "DEMO")
#> lineager: session started [study: DEMO]

# Source data
raw <- data.frame(
  id = sprintf("P%03d", 1:8),
  value = c(12.4, NA, 8.1, 15.2, 9.8, NA, 11.3, 7.4),
  group = rep(c("treatment", "control"), 4),
  include = c(TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, TRUE),
  stringsAsFactors = FALSE
)

# Tag, derive, filter
ds <- lg_tag(raw, dataset_id = "RAW", label = "Raw analysis dataset")
#> lineager: tagged 'RAW' — 8 rows, 4 cols

ds <- lg_derive(ds,
  log_value = log(value),
  value_cat = ifelse(!is.na(value) & value >= 10, "high", "low/missing"),
  description = "Log-transform value; categorise as high (>=10) vs low/missing"
)
#> lineager: [RAW] derive — Log-transform value; categorise as high (>=10) vs low/missing

ds_clean <- ds |>
  lg_filter(include == TRUE,
    reason = "Excluded by study protocol (include != TRUE)"
  ) |>
  lg_filter(!is.na(value),
    reason = "Missing primary endpoint value"
  )
#> lineager: [RAW] filter 'Excluded by study protocol (include != TRUE)' — 8 in, 6 out, 2 excluded
#> lineager: [RAW] filter 'Missing primary endpoint value' — 6 in, 4 out, 2 excluded

cat("Rows after cleaning:", nrow(ds_clean), "\n")
#> Rows after cleaning: 4

# Visualise the pipeline
lin <- lg_lineage()
print(lin)
#> <lg_lineage>  1 source dataset(s), 3 operation(s), 2 exclusion branch(es)
#> Use lg_plot(lin) to render. DOT source:
#> 
#> digraph lineage {
#>   rankdir = TB;
#>   graph [fontname="Helvetica", splines=ortho, nodesep=0.4, ranksep=0.6];
#>   node  [fontname="Helvetica", fontsize=10, margin="0.15,0.08"];
#>   edge  [fontname="Helvetica", fontsize=9, color="#6b6f80"];
#> 
#>   SRC_RAW [label="RAW\nn = 8", shape=box, style="filled,rounded", fillcolor="#e8effe", color="#1a56db", fontcolor="#0f1117"];
#>   OP_op_0001 [label="DERIVE\nLog-transform value; categorise ...", shape=ellipse, style="filled,rounded", fillcolor="#fff8e1", color="#f59e0b", fontcolor="#0f1117"];
#>   DS_RAW_op_0001 [label="RAW\nn = 8", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   OP_op_0002 [label="FILTER\nExcluded by study protocol (incl...\n−2 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
#>   DS_RAW_op_0002 [label="RAW\nn = 6", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   EXCL_op_0002 [label="excluded\nn = 2", shape=plaintext, fontcolor="#dc2626", fontsize=9];
#>   OP_op_0003 [label="FILTER\nMissing primary endpoint value\n−2 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
#>   DS_RAW_op_0003 [label="RAW\nn = 4", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   EXCL_op_0003 [label="excluded\nn = 2", shape=plaintext, fontcolor="#dc2626", fontsize=9];
#> 
#>   SRC_RAW -> OP_op_0001;
#>   OP_op_0001 -> DS_RAW_op_0001;
#>   DS_RAW_op_0001 -> OP_op_0002 [label=" n=8 "];
#>   OP_op_0002 -> DS_RAW_op_0002;
#>   OP_op_0002 -> EXCL_op_0002;
#>   DS_RAW_op_0002 -> OP_op_0003 [label=" n=6 "];
#>   OP_op_0003 -> DS_RAW_op_0003;
#>   OP_op_0003 -> EXCL_op_0003;
#> }

lg_end()
#> lineager: session ended — 3 operation(s), 4 exclusion(s), 0 population(s), 0 var spec(s)
```

## 9. Visualise the pipeline

[`lg_lineage()`](https://reprostats.org/lineager/reference/lg_lineage.md)
builds a complete lineage graph of the pipeline — every dataset,
operation, and exclusion branch — and returns a Graphviz DOT string.
Render it inline or export to a file.

``` r

lg_start()
#> lineager: session started
raw <- lg_tag(
  data.frame(
    USUBJID = sprintf("P%02d", 1:6),
    group = rep(c("A", "B"), 3L),
    flag = c(TRUE, TRUE, FALSE, TRUE, FALSE, TRUE),
    stringsAsFactors = FALSE
  ),
  dataset_id = "RAW"
)
#> lineager: tagged 'RAW' — 6 rows, 3 cols
raw <- lg_derive(raw,
  group_n = ifelse(group == "A", 1L, 2L),
  description = "Numeric group code"
)
#> lineager: [RAW] derive — Numeric group code
lg_filter(raw, flag == TRUE, reason = "Flag not set")
#> lineager: [RAW] filter 'Flag not set' — 6 in, 4 out, 2 excluded
#> <lg_df> 'RAW'  [4 × 5]
#>   USUBJID group flag group_n
#> 1     P01     A TRUE       1
#> 2     P02     B TRUE       2
#> 3     P04     B TRUE       2
#> 4     P06     B TRUE       2

lin <- lg_lineage()
print(lin)
#> <lg_lineage>  1 source dataset(s), 2 operation(s), 1 exclusion branch(es)
#> Use lg_plot(lin) to render. DOT source:
#> 
#> digraph lineage {
#>   rankdir = TB;
#>   graph [fontname="Helvetica", splines=ortho, nodesep=0.4, ranksep=0.6];
#>   node  [fontname="Helvetica", fontsize=10, margin="0.15,0.08"];
#>   edge  [fontname="Helvetica", fontsize=9, color="#6b6f80"];
#> 
#>   SRC_RAW [label="RAW\nn = 6", shape=box, style="filled,rounded", fillcolor="#e8effe", color="#1a56db", fontcolor="#0f1117"];
#>   OP_op_0001 [label="DERIVE\nNumeric group code", shape=ellipse, style="filled,rounded", fillcolor="#fff8e1", color="#f59e0b", fontcolor="#0f1117"];
#>   DS_RAW_op_0001 [label="RAW\nn = 6", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   OP_op_0002 [label="FILTER\nFlag not set\n−2 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
#>   DS_RAW_op_0002 [label="RAW\nn = 4", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   EXCL_op_0002 [label="excluded\nn = 2", shape=plaintext, fontcolor="#dc2626", fontsize=9];
#> 
#>   SRC_RAW -> OP_op_0001;
#>   OP_op_0001 -> DS_RAW_op_0001;
#>   DS_RAW_op_0001 -> OP_op_0002 [label=" n=6 "];
#>   OP_op_0002 -> DS_RAW_op_0002;
#>   OP_op_0002 -> EXCL_op_0002;
#> }
lg_end()
#> lineager: session ended — 2 operation(s), 2 exclusion(s), 0 population(s), 0 var spec(s)
```

``` r

# Render inline (requires DiagrammeR)
lg_plot(lin)

# Export DOT file for Graphviz / online renderers
lg_plot(lin, output = "outputs/pipeline.dot")
```

**Node colour legend:**

| Colour | Shape | Meaning |
|----|----|----|
| Blue | Box | Source dataset from [`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md) |
| Yellow | Ellipse | [`lg_derive()`](https://reprostats.org/lineager/reference/lg_derive.md) operation |
| Green | Diamond | [`lg_join()`](https://reprostats.org/lineager/reference/lg_join.md) operation |
| Orange | Ellipse | [`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md) operation |
| Red label | — | Rows excluded at that filter step |
| White | Box | Dataset state after each operation |

The next two vignettes cover exclusion tracking and reporting in depth:

- [`vignette("exclusion-tracking")`](https://reprostats.org/lineager/articles/exclusion-tracking.md)
  —
  [`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md),
  [`lg_exclusions()`](https://reprostats.org/lineager/reference/lg_exclusions.md),
  [`lg_disposition()`](https://reprostats.org/lineager/reference/lg_disposition.md),
  and
  [`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md)
  with detailed examples
- [`vignette("populations-and-reporting")`](https://reprostats.org/lineager/articles/populations-and-reporting.md)
  —
  [`lg_population()`](https://reprostats.org/lineager/reference/lg_population.md),
  [`lg_spec()`](https://reprostats.org/lineager/reference/lg_spec.md),
  [`lg_report()`](https://reprostats.org/lineager/reference/lg_report.md),
  and
  [`lg_lineage()`](https://reprostats.org/lineager/reference/lg_lineage.md)
  / [`lg_plot()`](https://reprostats.org/lineager/reference/lg_plot.md)
  for structured documentation and pipeline visualisation
