# Filter a tagged dataset with mandatory exclusion documentation

Works exactly like
[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html)
but requires a `reason` for every exclusion. Rows that do not meet the
filter conditions are captured in the session exclusion registry with
their USUBJID (if present), lineage ID, and the documented reason.

## Usage

``` r
lg_filter(data, ..., reason, population = NULL, reason_code = NULL)
```

## Arguments

- data:

  An `lg_df` from
  [`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md).

- ...:

  Filter conditions, passed to
  [`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html).

- reason:

  Character. **Mandatory.** Why these rows are being excluded. E.g.
  `"Not randomised (RANDFL != 'Y')"`.

- population:

  Character or `NULL`. Which population flag this exclusion relates to
  (e.g. `"SAFFL"`). Used to group the exclusion listing.

- reason_code:

  Character or `NULL`. Short controlled-vocabulary code for this
  exclusion (e.g. `"NOT_RANDOMISED"`). Useful for programmatic querying
  of the exclusion registry.

## Value

An `lg_df` containing only the rows that passed the filter. Excluded
rows are recorded in the session store.

## Details

`reason` has no default. Undocumented exclusions are a compliance
failure : this is enforced at the R level, not by convention.

## See also

[`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md),
[`lg_exclusions()`](https://reprostats.org/lineager/reference/lg_exclusions.md),
[`lg_disposition()`](https://reprostats.org/lineager/reference/lg_disposition.md)

## Examples

``` r
lg_start()
#> lineager: session started
adsl <- lg_tag(
  data.frame(USUBJID = c("01", "02", "03"),
             RANDFL  = c("Y", "N", "Y"),
             SAFFL   = c("Y", "N", "Y")),
  dataset_id = "ADSL"
)
#> lineager: tagged 'ADSL' — 3 rows, 3 cols

adsl_rand <- lg_filter(
  adsl,
  RANDFL == "Y",
  reason      = "Not randomised (RANDFL != 'Y')",
  reason_code = "NOT_RANDOMISED",
  population  = "RANDFL"
)
#> lineager: [ADSL] filter 'Not randomised (RANDFL != 'Y')' — 3 in, 2 out, 1 excluded
```
