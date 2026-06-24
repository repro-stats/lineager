# Render a lineage graph

Renders the lineage graph returned by
[`lg_lineage()`](https://reprostats.org/lineager/reference/lg_lineage.md)
as an interactive inline widget (using `DiagrammeR` if installed), or
writes the DOT source to a file for rendering with Graphviz externally.

## Usage

``` r
lg_plot(lineage, output = NULL)
```

## Arguments

- lineage:

  An `lg_lineage` object from
  [`lg_lineage()`](https://reprostats.org/lineager/reference/lg_lineage.md).

- output:

  Character or `NULL`. File path for DOT output (e.g. `"pipeline.dot"`).
  When `NULL` (default), renders inline using
  [`DiagrammeR::grViz()`](https://rich-iannone.github.io/DiagrammeR/reference/grViz.html)
  if available, otherwise prints the DOT source to the console.

## Value

The `lg_lineage` object, invisibly.

## See also

[`lg_lineage()`](https://reprostats.org/lineager/reference/lg_lineage.md)

## Examples

``` r
if (FALSE) { # \dontrun{
lg_start()
pts <- lg_tag(data.frame(USUBJID = c("P01","P02"),
                          eligible = c(TRUE, FALSE),
                          stringsAsFactors = FALSE),
              dataset_id = "PATIENTS")
lg_filter(pts, eligible, reason = "Not eligible")
lin <- lg_lineage()
lg_plot(lin)
lg_end()
} # }
```
