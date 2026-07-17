# Document and apply a population flag

Population flags (SAFFL, ITTFL, PPROTFL, and custom flags) are
first-class objects in `lineager`. Every flag must carry its inclusion
criteria, exclusion criteria, and plain-English definition : the
information needed to reconstruct the Reviewer's Guide population
section automatically.

## Usage

``` r
lg_population(
  data,
  flag_var,
  label,
  definition,
  incl_criteria,
  excl_criteria = NULL,
  included_value = "Y"
)
```

## Arguments

- data:

  An `lg_df` containing the flag variable.

- flag_var:

  Character. The flag variable name (e.g. `"SAFFL"`).

- label:

  Character. Human label (e.g. `"Safety Analysis Flag"`).

- definition:

  Character. Plain-English definition for regulatory reviewers (e.g.
  `"All randomised subjects who received at least one dose of study medication"`).

- incl_criteria:

  Character vector of inclusion criteria as R expressions or plain
  English. At least one required.

- excl_criteria:

  Character vector of explicit exclusion criteria. `NULL` if there are
  none beyond failing inclusion.

- included_value:

  The value of `flag_var` that denotes inclusion. Defaults to `"Y"` (the
  CDISC convention), but `lineager` is general-purpose : if your flag is
  a logical column, pass `included_value = TRUE`; for any other custom
  coding, pass the actual included-value directly. Using the wrong value
  here silently produces incorrect included/excluded counts (e.g. a
  logical `TRUE`/`FALSE` flag compared against `"Y"` will count every
  row as excluded).

## Value

`data`, invisibly (for pipe use).

## Details

The flag variable must already exist in `data`. `lg_population()`
documents it; it does not compute it. Compute the flag first with
[`lg_derive()`](https://reprostats.org/lineager/reference/lg_derive.md),
then call `lg_population()` to register its definition.

## See also

[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md),
[`lg_disposition()`](https://reprostats.org/lineager/reference/lg_disposition.md),
[`lg_report()`](https://reprostats.org/lineager/reference/lg_report.md)

## Examples

``` r
lg_start()
#> lineager: session started
adsl <- lg_tag(
  data.frame(
    USUBJID = c("01", "02", "03"),
    RANDFL = c("Y", "N", "Y"), EXOCCUR = c("Y", "N", "Y"),
    SAFFL = c("Y", "N", "Y")
  ),
  dataset_id = "ADSL"
)
#> lineager: tagged 'ADSL' — 3 rows, 4 cols

lg_population(
  adsl,
  flag_var = "SAFFL",
  label = "Safety Analysis Flag",
  definition = "All randomised subjects who received at least one dose",
  incl_criteria = c("RANDFL == 'Y'", "EXOCCUR == 'Y'"),
  excl_criteria = "No study drug administered (EXOCCUR != 'Y')"
)
#> lineager: population 'SAFFL' (Safety Analysis Flag) — 2 included, 1 excluded
```
