# report.R
# lg_report(): generate a CDISC Reviewer's Guide-aligned provenance document.
#
# Produces self-contained HTML (no external dependencies at render time).
# Sections:
#   1. Session summary \u2014 datasets, date/time, study/analysis IDs
#   2. Subject disposition \u2014 CONSORT-style disposition table
#   3. Population flag definitions \u2014 each registered lg_population
#   4. Variable derivations \u2014 each registered lg_spec (SDTM \u2192 ADaM)
#   5. Operation log \u2014 full sequence of lg_filter / lg_derive / lg_join ops
#   6. Exclusion listing \u2014 full exclusion registry, grouped by reason
#
# All user-supplied text (reasons, descriptions, labels, definitions, etc.)
# is passed through .html_escape() before being inserted into the HTML
# template, since exclusion/derivation text routinely contains "<", ">",
# and "&" (e.g. `reason = "AGE < 18 & CONSENT != 'Y'"`), which would
# otherwise corrupt the rendered table.


#' Generate a CDISC Reviewer's Guide-aligned provenance report
#'
#' Compiles all provenance collected during the active session into a
#' structured, self-contained HTML document suitable for inclusion in a
#' regulatory submission package.
#'
#' The report covers:
#' - **Dataset inventory** : all tagged datasets, row counts, sources
#' - **Subject disposition** : CONSORT-style disposition table from all
#'   [lg_filter()] calls
#' - **Population flags** : definitions, criteria, and counts for all
#'   [lg_population()] registrations
#' - **Variable derivations** : SDTM-to-ADaM mappings from [lg_spec()]
#'   registrations
#' - **Operation log** : full sequence of pipeline operations
#' - **Exclusion listing** : every excluded subject with reason and population
#'
#' @param format Character. Output format: `"html"` (default). PDF requires
#'   Quarto CLI and a LaTeX installation.
#' @param output Character or `NULL`. Output file path. If `NULL`, returns
#'   the report as a character string (HTML) without writing to disk.
#' @param title Character. Report title.
#' @param study_id Character or `NULL`. Study identifier for the report header.
#' @param sponsor Character or `NULL`. Sponsor name.
#' @param author Character or `NULL`. Analyst name.
#' @param date Date or Character. Report date. Defaults to today.
#'
#' @return The output file path (if `output` is specified) or the HTML string
#'   (if `output` is `NULL`), invisibly.
#'
#' @examples
#' \donttest{
#' lg_start(study_id = "TRIAL-001", analysis_id = "primary")
#'
#' # ... tagging, filtering, deriving, spec registration ...
#'
#' lg_report(
#'   output   = tempfile(fileext = ".html"),
#'   title    = "Data Provenance Report: TRIAL-001",
#'   sponsor  = "Example Pharma Ltd",
#'   author   = "J. Smith, Biostatistician"
#' )
#' }
#'
#' @seealso [lineager::lg_start()], [lg_exclusions()], [lg_disposition()]
#' @export
lg_report <- function(format = "html",
                      output = NULL,
                      title = "Data Provenance Report",
                      study_id = .lg$study_id,
                      sponsor = NULL,
                      author = NULL,
                      date = Sys.Date()) {
  .assert_active()

  if (format != "html") stop("Only format = 'html' is currently supported.")

  html <- .build_html_report(
    title    = title,
    study_id = study_id %||% "Not specified",
    sponsor  = sponsor %||% "Not specified",
    author   = author %||% "Not specified",
    date     = as.character(date)
  )

  if (!is.null(output)) {
    dir.create(dirname(output), showWarnings = FALSE, recursive = TRUE)
    writeLines(html, output)
    message(sprintf("lineager: report written to %s", output))
    return(invisible(output))
  }

  invisible(html)
}


# --------------------------------------------------------------------------- #
#  HTML builder \u2014 no external dependencies                                     #
# --------------------------------------------------------------------------- #

.build_html_report <- function(title, study_id, sponsor, author, date) {
  sections <- list()

  # 1. Header / session summary
  sections[[1L]] <- .section_header(title, study_id, sponsor, author, date)

  # 2. Dataset inventory
  sections[[2L]] <- .section_datasets()

  # 3. Subject disposition
  sections[[3L]] <- .section_disposition()

  # 4. Population flags
  sections[[4L]] <- .section_populations()

  # 5. Variable derivations
  sections[[5L]] <- .section_var_specs()

  # 6. Operation log
  sections[[6L]] <- .section_operations()

  # 7. Exclusion listing
  sections[[7L]] <- .section_exclusions()

  body <- paste(sections, collapse = "\n")

  sprintf('<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>%s</title>
<style>
  body { font-family: "IBM Plex Sans", system-ui, sans-serif; font-size: 14px;
         color: #1e293b; max-width: 1100px; margin: 0 auto; padding: 2rem; }
  h1 { font-size: 1.75rem; font-weight: 300; border-bottom: 1px solid #e2e8f0;
       padding-bottom: 0.5rem; margin-top: 2rem; }
  h2 { font-size: 1.2rem; font-weight: 500; color: #1a56db; margin-top: 1.75rem; }
  table { width: 100%%; border-collapse: collapse; font-size: 13px; margin: 1rem 0; }
  th { background: #f1f5f9; text-align: left; padding: 0.5rem 0.75rem;
       border: 1px solid #e2e8f0; font-weight: 500; }
  td { padding: 0.4rem 0.75rem; border: 1px solid #e2e8f0; vertical-align: top; }
  tr:nth-child(even) { background: #f8fafc; }
  .meta { display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem 2rem;
          font-size: 13px; color: #64748b; margin: 1rem 0 2rem; }
  .meta strong { color: #1e293b; }
  .badge { display: inline-block; font-size: 11px; padding: 2px 6px;
           border-radius: 3px; background: #e5ecfb; color: #1a56db;
           font-family: monospace; }
  .excl { color: #c45a00; font-weight: 500; }
  code { font-family: "IBM Plex Mono", monospace; font-size: 12px;
         background: #f1f5f9; padding: 1px 4px; border-radius: 2px; }
  .summary-box { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px;
                 padding: 1rem 1.25rem; margin: 1rem 0; }
</style>
</head>
<body>
%s
</body>
</html>', .html_escape(title), body)
}


.section_header <- function(title, study_id, sponsor, author, date) {
  n_ds <- length(.lg$datasets)
  n_excl <- length(.lg$exclusions)
  n_pop <- length(.lg$populations)
  n_spec <- length(.lg$var_specs)
  n_ops <- length(.lg$operations)

  sprintf(
    '<h1>%s</h1>
<div class="meta">
  <div><strong>Study</strong><br>%s</div>
  <div><strong>Analysis</strong><br>%s</div>
  <div><strong>Sponsor</strong><br>%s</div>
  <div><strong>Author</strong><br>%s</div>
  <div><strong>Date</strong><br>%s</div>
  <div><strong>Generated</strong><br>%s</div>
</div>
<div class="summary-box">
  <strong>Session summary:</strong>
  %d dataset(s) tagged &nbsp;&bull;&nbsp;
  %d operation(s) &nbsp;&bull;&nbsp;
  %d exclusion(s) &nbsp;&bull;&nbsp;
  %d population(s) &nbsp;&bull;&nbsp;
  %d variable spec(s)
</div>',
    .html_escape(title), .html_escape(study_id),
    .html_escape(.lg$analysis_id %||% "Not specified"),
    .html_escape(sponsor), .html_escape(author), .html_escape(date), .utc_now(),
    n_ds, n_ops, n_excl, n_pop, n_spec
  )
}


.section_datasets <- function() {
  if (length(.lg$datasets) == 0L) {
    return("")
  }

  rows <- vapply(names(.lg$datasets), function(id) {
    ds <- .lg$datasets[[id]]
    sprintf(
      "<tr><td><code>%s</code></td><td>%s</td><td>%s</td><td>%d</td><td>%s</td></tr>",
      .html_escape(id),
      .html_escape(ds$label %||% ""),
      if (is.null(ds$domain)) "&mdash;" else .html_escape(ds$domain),
      ds$n_rows,
      if (is.null(ds$source)) "&mdash;" else .html_escape(ds$source)
    )
  }, character(1L))

  sprintf(
    "<h2>1. Dataset Inventory</h2>
<table>
<tr><th>Dataset ID</th><th>Label</th><th>Domain</th><th>Rows</th><th>Source</th></tr>
%s
</table>", paste(rows, collapse = "\n")
  )
}


.section_disposition <- function() {
  excl <- lg_exclusions(verbose = FALSE)
  if (nrow(excl) == 0L) {
    return("<h2>2. Subject Disposition</h2><p>No exclusions recorded.</p>")
  }

  # lg_disposition(by = "reason") now returns the true step-by-step funnel:
  # step, reason, n_excluded, n_remaining (see query.R).
  disp <- lg_disposition(by = "reason")
  rows <- vapply(seq_len(nrow(disp)), function(i) {
    sprintf(
      "<tr><td>%d</td><td>%s</td><td class='excl'>%d</td><td>%d</td></tr>",
      disp$step[[i]], .html_escape(disp$reason[[i]]),
      disp$n_excluded[[i]], disp$n_remaining[[i]]
    )
  }, character(1L))

  final_n <- if (nrow(disp) > 0L) disp$n_remaining[[nrow(disp)]] else NA_integer_

  sprintf(
    '<h2>2. Subject Disposition</h2>
<table>
<tr><th>Step</th><th>Exclusion reason</th><th>N excluded</th><th>N remaining</th></tr>
%s
<tr><td colspan="2"><strong>Total excluded</strong></td><td class="excl"><strong>%d</strong></td><td><strong>%d</strong></td></tr>
</table>', paste(rows, collapse = "\n"), sum(disp$n_excluded), final_n
  )
}


.section_populations <- function() {
  if (length(.lg$populations) == 0L) {
    return("")
  }

  sections <- vapply(names(.lg$populations), function(flag) {
    p <- .lg$populations[[flag]]
    crit_in <- paste(.html_escape(p$incl_criteria), collapse = "<br>")
    crit_out <- if (!is.null(p$excl_criteria)) {
      paste(.html_escape(p$excl_criteria), collapse = "<br>")
    } else {
      "&mdash;"
    }
    sprintf(
      "<h3><code>%s</code> &mdash; %s</h3>
<p><em>%s</em></p>
<table>
<tr><th>Inclusion criteria</th><td>%s</td></tr>
<tr><th>Exclusion criteria</th><td>%s</td></tr>
<tr><th>N included</th><td>%d</td></tr>
<tr><th>N excluded</th><td class='excl'>%d</td></tr>
<tr><th>N total</th><td>%d</td></tr>
</table>",
      .html_escape(flag), .html_escape(p$label), .html_escape(p$definition),
      crit_in, crit_out,
      p$n_included, p$n_excluded, p$n_total
    )
  }, character(1L))

  paste0("<h2>3. Population Flag Definitions</h2>", paste(sections, collapse = "\n"))
}


.section_var_specs <- function() {
  if (length(.lg$var_specs) == 0L) {
    return("")
  }

  rows <- vapply(names(.lg$var_specs), function(key) {
    s <- .lg$var_specs[[key]]
    sprintf(
      "<tr><td><code>%s</code></td><td><code>%s</code></td><td>%s</td><td><code>%s</code></td><td><code>%s</code></td><td>%s</td></tr>",
      .html_escape(s$adam_dataset), .html_escape(s$adam_var), .html_escape(s$label),
      .html_escape(s$source_domain), .html_escape(s$source_var), .html_escape(s$derivation)
    )
  }, character(1L))

  sprintf(
    "<h2>4. Variable Derivations (SDTM \u2192 ADaM)</h2>
<table>
<tr><th>ADaM Dataset</th><th>Variable</th><th>Label</th><th>Source Domain</th><th>Source Var</th><th>Derivation</th></tr>
%s
</table>", paste(rows, collapse = "\n")
  )
}


.section_operations <- function() {
  ops <- lg_operations(verbose = FALSE)
  if (nrow(ops) == 0L) {
    return("")
  }

  rows <- vapply(seq_len(nrow(ops)), function(i) {
    op <- ops[i, ]
    sprintf(
      "<tr><td><span class='badge'>%s</span></td><td><code>%s</code></td><td>%s</td><td>%s</td><td>%s</td></tr>",
      .html_escape(op$op_type %||% ""), .html_escape(op$dataset_id %||% ""),
      .html_escape(op$description %||% ""),
      op$rows_in %||% "", op$rows_out %||% ""
    )
  }, character(1L))

  sprintf(
    "<h2>5. Operation Log</h2>
<table>
<tr><th>Type</th><th>Dataset</th><th>Description</th><th>Rows in</th><th>Rows out</th></tr>
%s
</table>", paste(rows, collapse = "\n")
  )
}


.section_exclusions <- function() {
  excl <- lg_exclusions(verbose = FALSE)
  if (nrow(excl) == 0L) {
    return("")
  }

  rows <- vapply(seq_len(nrow(excl)), function(i) {
    e <- excl[i, ]
    sprintf(
      "<tr><td>%s</td><td><code>%s</code></td><td class='excl'>%s</td><td>%s</td></tr>",
      .esc_or_dash(e$usubjid),
      .html_escape(e$dataset_id %||% ""),
      .html_escape(e$reason %||% ""),
      .esc_or_dash(e$population)
    )
  }, character(1L))

  sprintf(
    "<h2>6. Exclusion Listing</h2>
<table>
<tr><th>USUBJID</th><th>Dataset</th><th>Reason</th><th>Population</th></tr>
%s
</table>", paste(rows, collapse = "\n")
  )
}
