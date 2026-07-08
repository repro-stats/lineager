# Build a pipeline lineage graph from the active session

Constructs a visual representation of the full pipeline : every tagged
dataset, every
[`lg_derive()`](https://reprostats.org/lineager/reference/lg_derive.md),
[`lg_join()`](https://reprostats.org/lineager/reference/lg_join.md), and
[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
operation, and every exclusion branch : as a list of nodes and edges
with a Graphviz DOT string.

## Usage

``` r
lg_lineage(rankdir = c("TB", "LR"))
```

## Arguments

- rankdir:

  Character. Layout direction: `"TB"` (top to bottom, default) or `"LR"`
  (left to right).

## Value

An `lg_lineage` object (list) with components:

- `nodes`:

  Named list of node metadata.

- `edges`:

  Named list of edge metadata.

- `dot`:

  Character string. Graphviz DOT representation.

- `rankdir`:

  The layout direction used.

## Details

Render with
[`lg_plot()`](https://reprostats.org/lineager/reference/lg_plot.md) for
inline display in RStudio or a knitr document, or write the DOT string
to a file and render externally with Graphviz.

## See also

[`lg_plot()`](https://reprostats.org/lineager/reference/lg_plot.md),
[`lg_operations()`](https://reprostats.org/lineager/reference/lg_operations.md),
[`lg_report()`](https://reprostats.org/lineager/reference/lg_report.md)

## Examples

``` r
lg_start()
#> lineager: session started
patients <- data.frame(
  USUBJID = c("P01", "P02", "P03", "P04", "P05"),
  eligible = c(TRUE, FALSE, TRUE, TRUE, FALSE),
  age = c(34L, 17L, 52L, 29L, 61L),
  stringsAsFactors = FALSE
)
pts <- lg_tag(patients, dataset_id = "PATIENTS")
#> lineager: tagged 'PATIENTS' — 5 rows, 3 cols
pts <- lg_derive(pts,
  adult = age >= 18L,
  description = "adult flag from age"
)
#> lineager: [PATIENTS] derive — adult flag from age
lg_filter(pts, eligible & adult,
  reason = "Ineligible or under 18"
)
#> lineager: [PATIENTS] filter 'Ineligible or under 18' — 5 in, 3 out, 2 excluded
#> <lg_df> 'PATIENTS'  [3 × 5]
#>   USUBJID eligible age adult
#> 1     P01     TRUE  34  TRUE
#> 2     P03     TRUE  52  TRUE
#> 3     P04     TRUE  29  TRUE

lin <- lg_lineage()
print(lin)
#> <lg_lineage>  1 source dataset(s), 2 operation(s), 1 exclusion branch(es)
#> Use lg_plot(lin) to render. DOT source:
#> 
#> digraph lineage {
#>   rankdir = TB;
#>   graph [fontname="Helvetica", splines=ortho, nodesep=0.4, ranksep=0.6];
#>   node  [fontname="Helvetica", fontsize=10, margin="0.15,0.08"];
#>   edge  [fontname="Helvetica", fontsize=9, color="#6b6f80"];
#> 
#>   SRC_PATIENTS [label="PATIENTS\nn = 5", shape=box, style="filled,rounded", fillcolor="#e8effe", color="#1a56db", fontcolor="#0f1117"];
#>   OP_op_0001 [label="DERIVE\nadult flag from age", shape=ellipse, style="filled,rounded", fillcolor="#fff8e1", color="#f59e0b", fontcolor="#0f1117"];
#>   DS_PATIENTS_op_0001 [label="PATIENTS\nn = 5", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   OP_op_0002 [label="FILTER\nIneligible or under 18\n−2 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
#>   DS_PATIENTS_op_0002 [label="PATIENTS\nn = 3", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
#>   EXCL_op_0002 [label="excluded\nn = 2", shape=plaintext, fontcolor="#dc2626", fontsize=9];
#> 
#>   SRC_PATIENTS -> OP_op_0001;
#>   OP_op_0001 -> DS_PATIENTS_op_0001;
#>   DS_PATIENTS_op_0001 -> OP_op_0002 [label=" n=5 "];
#>   OP_op_0002 -> DS_PATIENTS_op_0002;
#>   OP_op_0002 -> EXCL_op_0002;
#> } 
lg_end()
#> lineager: session ended — 2 operation(s), 2 exclusion(s), 0 population(s), 0 var spec(s)
```
