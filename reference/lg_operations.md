# Retrieve the operation log as a data frame

Retrieve the operation log as a data frame

## Usage

``` r
lg_operations(verbose = TRUE)
```

## Arguments

- verbose:

  Logical. Print count summary. Default `TRUE`.

## Value

A `data.frame` of all recorded operations, with columns `op_id`,
`op_type`, `dataset_id`, `description`, `population` (`NA` for
non-`FILTER` operations), `rows_in`, `rows_out`, `rows_excluded`
(`rows_in - rows_out` when not directly recorded), and `timestamp`.
