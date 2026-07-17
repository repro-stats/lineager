# Retrieve the operation history recorded on a tagged object

Every `lg_df` accumulates the sequence of
[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md),
[`lg_derive()`](https://reprostats.org/lineager/reference/lg_derive.md),
and [`lg_join()`](https://reprostats.org/lineager/reference/lg_join.md)
operations that produced it, in its `lg_history` attribute.
`lg_history()` returns that sequence directly rather than requiring
`attr(data, "lg_history")`.

## Usage

``` r
lg_history(data)
```

## Arguments

- data:

  An `lg_df` object.

## Value

A list of `lg_operation` records applied to this specific object, in the
order they were applied. Empty list if none yet.

## Examples

``` r
lg_start()
#> lineager: session started
dm <- lg_tag(
  data.frame(USUBJID = c("01", "02"), AGE = c(20L, 15L)),
  dataset_id = "DM"
)
#> lineager: tagged 'DM' — 2 rows, 2 cols
dm_f <- lg_filter(dm, AGE >= 18L, reason = "Minors excluded")
#> lineager: [DM] filter 'Minors excluded' — 2 in, 1 out, 1 excluded
length(lg_history(dm_f))
#> [1] 1
```
