# Retrieve lineage IDs from a tagged dataset

Returns the `lineage_id` vector from an `lg_df` object. Use this instead
of accessing the column directly to keep code robust against future
internal changes.

## Usage

``` r
lg_id(data)
```

## Arguments

- data:

  An `lg_df` from
  [`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md).

## Value

A character vector of lineage IDs, one per row.

## Examples

``` r
lg_start()
#> lineager: session started
dm <- data.frame(USUBJID = c("01-001", "01-002"), AGE = c(34L, 52L))
dm_tagged <- lg_tag(dm, dataset_id = "DM")
#> lineager: tagged 'DM' — 2 rows, 2 cols
lg_id(dm_tagged)
#> [1] "DM_0001_01-001" "DM_0002_01-002"
```
