# Trace a subject's complete lineage journey

Given a USUBJID (or a `.__lid__` value), returns the complete history of
that subject across all tagged datasets and operations in the session:
which datasets they appear in, which operations they passed through or
were excluded by, and which population flags apply to them.

## Usage

``` r
lg_trace(usubjid, verbose = TRUE)
```

## Arguments

- usubjid:

  Character. The subject identifier to trace. Must match a value of
  `USUBJID` in at least one tagged dataset.

- verbose:

  Logical. If `TRUE` (default), prints a formatted trace to the console.

## Value

A list (invisibly) with components:

- `usubjid`:

  The traced subject ID.

- `datasets`:

  Character vector of dataset IDs the subject appears in.

- `operations`:

  Data frame of operations applied to datasets containing this subject.

- `exclusions`:

  Data frame of exclusion records for this subject, or a zero-row data
  frame if none.

- `populations`:

  Named list of population flag values for this subject across all
  registered populations.

## Details

This is the key regulatory tracing capability : a reviewer can ask "show
me everything that happened to subject 01-042" and get a complete,
programmatically generated answer.

## See also

[`lg_exclusions()`](https://reprostats.org/lineager/reference/lg_exclusions.md),
[`lg_disposition()`](https://reprostats.org/lineager/reference/lg_disposition.md)

## Examples

``` r
lg_start()
#> lineager: session started
adsl <- lg_tag(
  data.frame(
    USUBJID = c("01", "02", "03"),
    RANDFL = c("Y", "N", "Y")
  ),
  dataset_id = "ADSL"
)
#> lineager: tagged 'ADSL' — 3 rows, 2 cols
lg_filter(adsl, RANDFL == "Y",
  reason = "Not randomised", population = "RANDFL"
)
#> lineager: [ADSL] filter 'Not randomised' — 3 in, 2 out, 1 excluded
#> <lg_df> 'ADSL'  [2 × 3]
#>   USUBJID RANDFL
#> 1      01      Y
#> 2      03      Y

lg_trace("02")
#> 
#> ── lineager trace: USUBJID '02' ──
#> 
#>   Appears in: ADSL
#> 
#>   Operations:
#>     [FILTER] ADSL: Not randomised (3→2)
#> 
#>   Exclusions (1):
#>     ✗ [ADSL] Not randomised [pop: RANDFL]
#> 
```
