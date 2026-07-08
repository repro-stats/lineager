# Join two tagged datasets with lineage tracking

Performs a left, inner, full, or right join and records the operation in
the session log. The `.__lid__` column from `x` is preserved. A
secondary column `.__lid_y__` records which rows of `y` contributed to
each output row, enabling full bilateral tracing.

## Usage

``` r
lg_join(
  x,
  y,
  by,
  type = c("left", "inner", "full", "right"),
  description = NULL
)
```

## Arguments

- x, y:

  `lg_df` objects.

- by:

  Character vector of join keys, passed to the underlying
  [`dplyr::left_join()`](https://dplyr.tidyverse.org/reference/mutate-joins.html)
  (etc.) call.

- type:

  Join type: `"left"` (default), `"inner"`, `"full"`, `"right"`.

- description:

  Character or `NULL`. Optional description of the join purpose (e.g.
  `"Merge first dose date from EX domain"`).

## Value

An `lg_df` with the joined result. `.__lid_y__` is added to record the
contributing row IDs from `y`.

## See also

[`lg_derive()`](https://reprostats.org/lineager/reference/lg_derive.md),
[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)

## Examples

``` r
lg_start()
#> lineager: session started

adsl <- lg_tag(
  data.frame(USUBJID = c("01", "02"), TRT01P = c("Active", "Placebo")),
  dataset_id = "ADSL"
)
#> lineager: tagged 'ADSL' — 2 rows, 2 cols
ex_summary <- lg_tag(
  data.frame(USUBJID = c("01", "02"), EXSTDTC_min = c("2026-01-01", "2026-01-03")),
  dataset_id = "EX_SUMM"
)
#> lineager: tagged 'EX_SUMM' — 2 rows, 2 cols

adsl_ex <- lg_join(adsl, ex_summary,
  by = "USUBJID",
  description = "First dose date from EX domain"
)
#> lineager: [ADSL + EX_SUMM] left join — 2 rows out
```
