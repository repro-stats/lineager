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

An `lg_history` object (a list of `lg_operation` records applied to this
specific object, in the order they were applied; empty if none yet).
Iterate over it, or index into it, exactly like a regular list — the
class only changes how it prints.

## Details

The returned object prints as a readable summary rather than a raw
nested list — when empty, it reports plainly that no operations are
recorded for this object yet, rather than printing a bare, uninformative
[`list()`](https://rdrr.io/r/base/list.html).

## Examples

``` r
lg_start()
#> lineager: session started
dm <- lg_tag(
  data.frame(USUBJID = c("01", "02"), AGE = c(20L, 15L)),
  dataset_id = "DM"
)
#> lineager: tagged 'DM' — 2 rows, 2 cols
lg_history(dm) # no operations yet
#> <lg_history> no operations recorded for this object yet

dm_f <- lg_filter(dm, AGE >= 18L, reason = "Minors excluded")
#> lineager: [DM] filter 'Minors excluded' — 2 in, 1 out, 1 excluded
lg_history(dm_f)
#> <lg_history> 1 operation(s)
#> 
#> <lg_operation> [op_0001] FILTER
#>   Dataset    : DM
#>   Description: Minors excluded
#>   Rows       : 2 -> 1 (1 excluded)
#>   Timestamp  : 2026-07-30T16:10:27.900Z
#> 
```
