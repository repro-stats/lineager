# Retrieve the exclusion registry

Returns all exclusions recorded by
[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
calls during the active session as a flat `data.frame`. This is the data
underlying the subject disposition listing : every excluded subject,
with their USUBJID, the reason they were excluded, and which population
the exclusion relates to.

## Usage

``` r
lg_exclusions(population = NULL, dataset_id = NULL, verbose = TRUE)
```

## Arguments

- population:

  Character or `NULL`. Filter to a specific population flag (e.g.
  `"SAFFL"`). `NULL` returns all exclusions.

- dataset_id:

  Character or `NULL`. Filter to a specific dataset.

- verbose:

  Logical. If `TRUE` (default), prints a count summary.

## Value

A `data.frame` with columns: `excl_id`, `op_id`, `dataset_id`, `lid`,
`usubjid`, `reason`, `reason_code`, `population`, `excluded_at`.

## See also

[`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md),
[`lg_disposition()`](https://reprostats.org/lineager/reference/lg_disposition.md)

## Examples

``` r
lg_start()
#> lineager: session started
adsl <- lg_tag(
  data.frame(USUBJID = c("01", "02", "03"), RANDFL = c("Y", "N", "Y")),
  dataset_id = "ADSL"
)
#> lineager: tagged 'ADSL' — 3 rows, 2 cols
lg_filter(adsl, RANDFL == "Y",
  reason = "Not randomised", population = "RANDFL"
)
#> lineager: [ADSL] filter 'Not randomised' — 3 in, 2 out, 1 excluded
#> <lg_df> 'ADSL'  [2 × 3]
#>   USUBJID RANDFL
#> 1      01      Y
#> 2      03      Y

lg_exclusions()
#> lineager: 1 exclusion(s) retrieved
#>             excl_id   op_id dataset_id          lid usubjid         reason
#> 1 op_0001_excl_0001 op_0001       ADSL ADSL_0002_02      02 Not randomised
#>   reason_code population              excluded_at
#> 1        <NA>     RANDFL 2026-07-08T11:19:54.634Z
```
