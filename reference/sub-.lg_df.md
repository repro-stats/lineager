# Subset an `lg_df`, preserving lineage attributes

Subset an `lg_df`, preserving lineage attributes

## Usage

``` r
# S3 method for class 'lg_df'
x[i, j, drop = FALSE]
```

## Arguments

- x:

  An `lg_df` object.

- i:

  Row index, as in `[.data.frame`.

- j:

  Column index, as in `[.data.frame`.

- drop:

  Ignored : `lg_df` subsetting always behaves as though `drop = FALSE`.
  See Details.

## Value

An `lg_df` with lineage attributes preserved (or a plain
`data.frame`/vector for subsetting operations where preservation is not
applicable, matching normal `[.data.frame` fallback behaviour).

## Details

`[.lg_df` deliberately forces `drop = FALSE`, unlike base
`[.data.frame`. This means single-column subsetting (e.g. `df[, "col"]`)
returns a one-column `lg_df`/`data.frame` rather than a bare vector, so
the lineage attributes are never silently lost through ordinary
subsetting. Use `df[[col]]` or `lg_id(df)` when a plain vector is what
you actually want.
