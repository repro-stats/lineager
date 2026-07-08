# Generate a CDISC Reviewer's Guide-aligned provenance report

Compiles all provenance collected during the active session into a
structured, self-contained HTML document suitable for inclusion in a
regulatory submission package.

## Usage

``` r
lg_report(
  format = "html",
  output = NULL,
  title = "Data Provenance Report",
  study_id = .lg$study_id,
  sponsor = NULL,
  author = NULL,
  date = Sys.Date()
)
```

## Arguments

- format:

  Character. Output format: `"html"` (default). PDF requires Quarto CLI
  and a LaTeX installation.

- output:

  Character or `NULL`. Output file path. If `NULL`, returns the report
  as a character string (HTML) without writing to disk.

- title:

  Character. Report title.

- study_id:

  Character or `NULL`. Study identifier for the report header.

- sponsor:

  Character or `NULL`. Sponsor name.

- author:

  Character or `NULL`. Analyst name.

- date:

  Date or Character. Report date. Defaults to today.

## Value

The output file path (if `output` is specified) or the HTML string (if
`output` is `NULL`), invisibly.

## Details

The report covers:

- **Dataset inventory** : all tagged datasets, row counts, sources

- **Subject disposition** : CONSORT-style disposition table from all
  [`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
  calls

- **Population flags** : definitions, criteria, and counts for all
  [`lg_population()`](https://reprostats.org/lineager/reference/lg_population.md)
  registrations

- **Variable derivations** : SDTM-to-ADaM mappings from
  [`lg_spec()`](https://reprostats.org/lineager/reference/lg_spec.md)
  registrations

- **Operation log** : full sequence of pipeline operations

- **Exclusion listing** : every excluded subject with reason and
  population

## See also

[`lg_start()`](https://reprostats.org/lineager/reference/lg_start.md),
[`lg_exclusions()`](https://reprostats.org/lineager/reference/lg_exclusions.md),
[`lg_disposition()`](https://reprostats.org/lineager/reference/lg_disposition.md)

## Examples

``` r
# \donttest{
lg_start(study_id = "TRIAL-001", analysis_id = "primary")
#> lineager: session started [study: TRIAL-001] [analysis: primary]

# ... tagging, filtering, deriving, spec registration ...

lg_report(
  output   = tempfile(fileext = ".html"),
  title    = "Data Provenance Report: TRIAL-001",
  sponsor  = "Example Pharma Ltd",
  author   = "J. Smith, Biostatistician"
)
#> lineager: report written to /tmp/Rtmp7S6T5Z/file1a8b5eb0479.html
# }
```
