# Derive new variables with documented derivation

Works exactly like
[`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)
but records a derivation description in the session operation log. Use
this when computing ADaM analysis variables from SDTM source variables.

## Usage

``` r
lg_derive(data, ..., description)
```

## Arguments

- data:

  An `lg_df` from
  [`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md).

- ...:

  Name-value pairs of derivations, passed to
  [`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html).

- description:

  Character. **Required.** What is being derived and from what source.
  E.g.
  `"AVAL: numeric conversion of LBORRES; LBSTRESN used where LBORRES is missing or non-numeric"`.

## Value

An `lg_df` with derived variables added.

## See also

[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md),
[`lg_join()`](https://reprostats.org/lineager/reference/lg_join.md),
[`lg_spec()`](https://reprostats.org/lineager/reference/lg_spec.md)

## Examples

``` r
lg_start()
#> lineager: session started
lb <- lg_tag(
  data.frame(USUBJID = "01-001", LBORRES = "12.4",
             LBSTRESN = 12.4, stringsAsFactors = FALSE),
  dataset_id = "LB", domain = "LB"
)
#> lineager: tagged 'LB' — 1 rows, 3 cols

lb_derived <- lg_derive(
  lb,
  AVAL = dplyr::coalesce(LBSTRESN, suppressWarnings(as.numeric(LBORRES))),
  description = "AVAL: LBSTRESN; numeric LBORRES where LBSTRESN is missing"
)
#> lineager: [LB] derive — AVAL: LBSTRESN; numeric LBORRES where LBSTRESN is missing
```
