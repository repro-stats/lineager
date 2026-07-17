# Tag a dataset to begin lineage tracking

Assigns a unique lineage identifier (`lineage_id`) to every row and
registers the dataset in the active session store. This is the entry
point to `lineager` : all other functions require a tagged data frame.

## Usage

``` r
lg_tag(
  data,
  dataset_id,
  domain = NULL,
  label = NULL,
  source = NULL,
  overwrite = FALSE
)
```

## Arguments

- data:

  A `data.frame` or `tibble`.

- dataset_id:

  Character. Short identifier for this dataset, e.g. `"LB"`, `"ADLB"`,
  `"ADSL"`. Used as the prefix in lineage IDs and in report output.

- domain:

  Character or `NULL`. CDISC domain code if applicable (e.g. `"DM"`,
  `"LB"`, `"AE"`). Used for SDTM-to-ADaM mapping and Reviewer's Guide
  output.

- label:

  Character or `NULL`. Human-readable label for the dataset (e.g.
  `"Laboratory test results"`). Used in reports.

- source:

  Character or `NULL`. Source file or system description.

- overwrite:

  Logical. If `dataset_id` is already registered in this session,
  `lg_tag()` errors by default : any `lg_df` object still held from the
  previous registration would silently stop being traceable via
  [`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md)
  the moment the registration is replaced. Set `overwrite = TRUE` to
  explicitly allow re-tagging (e.g. intentionally re-running a step) and
  acknowledge that the prior object is no longer traceable.

## Value

An `lg_df` object : a `data.frame` with a `lineage_id` column and
lineage metadata stored in attributes.

## Details

The `lineage_id` column is added at position 1 and is preserved through
[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md),
[`lg_derive()`](https://reprostats.org/lineager/reference/lg_derive.md),
and [`lg_join()`](https://reprostats.org/lineager/reference/lg_join.md)
operations. It allows every row in any downstream dataset to be traced
back to its origin.

## See also

[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md),
[`lg_derive()`](https://reprostats.org/lineager/reference/lg_derive.md),
[`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md)

## Examples

``` r
lg_start()
#> lineager: session started

dm <- data.frame(
  USUBJID = c("01-001", "01-002", "01-003"),
  AGE     = c(34L, 52L, 47L),
  SEX     = c("M", "F", "M")
)

dm_tagged <- lg_tag(dm, dataset_id = "DM", domain = "DM",
                    label = "Demographics")
#> lineager: tagged 'DM' — 3 rows, 3 cols
dm_tagged
#> <lg_df> 'DM' (domain: DM)  [3 × 4]
#>   USUBJID AGE SEX
#> 1  01-001  34   M
#> 2  01-002  52   F
#> 3  01-003  47   M
```
