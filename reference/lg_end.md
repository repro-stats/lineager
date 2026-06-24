# End a lineager provenance session

Prints a session summary and marks the session inactive. The store is
preserved in memory and remains queryable via
[`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md),
[`lg_exclusions()`](https://reprostats.org/lineager/reference/lg_exclusions.md),
and
[`lg_report()`](https://reprostats.org/lineager/reference/lg_report.md)
until
[`lg_start()`](https://reprostats.org/lineager/reference/lg_start.md) is
called again.

## Usage

``` r
lg_end()
```

## Value

Invisibly `NULL`.

## See also

[`lg_start()`](https://reprostats.org/lineager/reference/lg_start.md)

## Examples

``` r
lg_start()
#> lineager: session started
lg_end()
#> lineager: session ended — 0 operation(s), 0 exclusion(s), 0 population(s), 0 var spec(s)
```
