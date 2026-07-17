# Join two tagged datasets with lineage tracking

Performs a left, inner, full, or right join and records the operation in
the session log. The `lineage_id` column from `x` is preserved. A
secondary column records which rows of `y` contributed to each output
row, enabling full bilateral tracing.

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

  Character or `NULL`. Description of the join purpose (e.g.
  `"Merge first dose date from EX domain"`). For `type = "inner"` or
  `type = "right"`, `description` becomes **mandatory** the moment the
  join actually drops one or more rows of `x` (i.e. `x` rows with no
  matching `y` record) : those dropped rows are subjects being silently
  removed from the pipeline, and per lineager's core design, every
  exclusion must carry a documented reason. If no rows end up dropped,
  `description` stays optional as before.

## Value

An `lg_df` with the joined result. A `lineage_id_y` column is added
recording the contributing row IDs from `y`, matching prior versions of
`lineager`. If `x` already carries a `lineage_id_y` column from an
earlier join in the same chain (e.g. joining a third dataset onto the
result of a previous `lg_join()` call), this join's own y-tracing column
is instead named `lineage_id_y__<op_id>` (e.g. `lineage_id_y__op_0003`)
so it cannot silently collide with – or overwrite – the earlier join's
tracing column. A message is printed whenever this fallback naming is
used.

## Details

Only unmatched rows of `x` are exclusion-tracked (since `x` is treated
as the primary, subject-carrying dataset in lineager's model). Unmatched
rows of `y` dropped by `"left"` or `"inner"` joins are not separately
logged as exclusions of `y`'s own dataset : if `y`-side row loss also
needs documented tracking for your use case, log it explicitly with
[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
on `y` before joining.

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

adsl_ex <- lg_join(adsl, ex_summary, by = "USUBJID",
                   description = "First dose date from EX domain")
#> lineager: [ADSL + EX_SUMM] left join — 2 rows out
```
