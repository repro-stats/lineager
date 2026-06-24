# Start a lineager provenance session

Initialises the session store. Call once at the top of your analysis
script, before any
[`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md),
[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md),
or
[`lg_derive()`](https://reprostats.org/lineager/reference/lg_derive.md)
calls. Resets any prior session state.

## Usage

``` r
lg_start(study_id = NULL, analysis_id = NULL)
```

## Arguments

- study_id:

  Character or `NULL`. Optional study identifier included in reports.

- analysis_id:

  Character or `NULL`. Optional analysis identifier.

## Value

Invisibly `NULL`.

## See also

[`lg_end()`](https://reprostats.org/lineager/reference/lg_end.md),
[`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md),
[`lg_report()`](https://reprostats.org/lineager/reference/lg_report.md)

## Examples

``` r
lg_start(study_id = "TRIAL-001", analysis_id = "primary-efficacy")
#> lineager: session started [study: TRIAL-001] [analysis: primary-efficacy]
lg_end()
#> lineager: session ended — 0 operation(s), 0 exclusion(s), 0 population(s), 0 var spec(s)
```
