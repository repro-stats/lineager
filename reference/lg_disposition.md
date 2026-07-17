# Generate a subject disposition summary

Produces a CONSORT-style subject disposition table from every documented
exclusion in the active session – both
[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
calls and any
[`lg_join()`](https://reprostats.org/lineager/reference/lg_join.md) call
(`type = "inner"`/`"right"`) that dropped unmatched rows of `x`. Both
are exclusions in the same sense (rows removed from the pipeline with a
mandatory documented reason), so both must be reflected here for the
totals to match
[`lg_exclusions()`](https://reprostats.org/lineager/reference/lg_exclusions.md).

## Usage

``` r
lg_disposition(by = c("reason", "population", "dataset"))
```

## Arguments

- by:

  Character. How to group: `"reason"` (default) returns the exact
  step-by-step funnel. `"population"` groups by population flag.
  `"dataset"` groups by dataset ID.

## Value

A `data.frame`. For `by = "reason"`: columns `step`, `reason`,
`n_excluded`, `n_remaining`. For `by = "population"` or `"dataset"`:
columns `group`, `n_excluded`, `n_remaining`.

## Details

With the default `by = "reason"`, this returns one row **per
contributing step** (filter or row-dropping join), in the exact
chronological order they were executed, with the number of subjects
excluded at that step and the number remaining immediately afterward –
i.e. the actual funnel.

`by = "population"` and `by = "dataset"` aggregate exclusions that share
a population flag or dataset across possibly multiple steps, in the
order each group first appears. Note that
[`lg_join()`](https://reprostats.org/lineager/reference/lg_join.md) has
no `population` argument, so join-caused exclusions always fall into the
`"(none)"` group under `by = "population"`.

## See also

[`lg_exclusions()`](https://reprostats.org/lineager/reference/lg_exclusions.md),
[`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md)

## Examples

``` r
lg_start()
#> lineager: session started
adsl <- lg_tag(
  data.frame(
    USUBJID = sprintf("%02d", 1:5),
    RANDFL = c("Y","Y","N","Y","Y"),
    SAFFL  = c("Y","Y","N","Y","N")
  ),
  dataset_id = "ADSL5"
)
#> lineager: tagged 'ADSL5' — 5 rows, 3 cols
lg_filter(adsl, RANDFL == "Y",
  reason = "Not randomised (RANDFL != 'Y')",
  reason_code = "NOT_RANDOMISED", population = "RANDFL"
)
#> lineager: [ADSL5] filter 'Not randomised (RANDFL != 'Y')' — 5 in, 4 out, 1 excluded
#> <lg_df> 'ADSL5'  [4 × 4]
#>   USUBJID RANDFL SAFFL
#> 1      01      Y     Y
#> 2      02      Y     Y
#> 3      04      Y     Y
#> 4      05      Y     N

lg_disposition()
#>   step                         reason n_excluded n_remaining
#> 1    1 Not randomised (RANDFL != 'Y')          1           4
```
