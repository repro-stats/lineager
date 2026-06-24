# Generate a subject disposition summary

Produces a CONSORT-style subject disposition table from all
[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
exclusions in the session. Each row represents a distinct exclusion
reason, showing cumulative subject counts at each stage.

## Usage

``` r
lg_disposition(by = c("reason", "population", "dataset"))
```

## Arguments

- by:

  Character. How to group: `"reason"` (default) groups by the exclusion
  reason text, `"population"` groups by population flag, `"dataset"`
  groups by dataset ID.

## Value

A `data.frame` with columns: `group`, `n_excluded`, and a `cumulative_n`
column showing remaining subjects at each stage.

## See also

[`lg_exclusions()`](https://reprostats.org/lineager/reference/lg_exclusions.md),
[`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md)

## Examples

``` r
lg_start()
#> lineager: session started
adsl <- lg_tag(
  data.frame(USUBJID = c("01","02","03","04","05"),
             RANDFL  = c("Y","N","Y","Y","N"),
             SAFFL   = c("Y","N","Y","Y","N")),
  dataset_id = "ADSL"
)
#> lineager: tagged 'ADSL' — 5 rows, 3 cols
lg_filter(adsl, RANDFL == "Y",
          reason = "Not randomised (RANDFL != 'Y')",
          reason_code = "NOT_RANDOMISED", population = "RANDFL")
#> lineager: [ADSL] filter 'Not randomised (RANDFL != 'Y')' — 5 in, 3 out, 2 excluded
#> <lg_df> 'ADSL'  [3 × 4]
#>   USUBJID RANDFL SAFFL
#> 1      01      Y     Y
#> 2      03      Y     Y
#> 3      04      Y     Y

lg_disposition()
#>                            group n_excluded
#> 1 Not randomised (RANDFL != 'Y')          2
```
