# Changelog

## lineager (development version)

## lineager 0.1.0

Initial release.

### Core pipeline functions

- [`lg_start()`](https://reprostats.org/lineager/reference/lg_start.md)
  / [`lg_end()`](https://reprostats.org/lineager/reference/lg_end.md) —
  session lifecycle.
  [`lg_start()`](https://reprostats.org/lineager/reference/lg_start.md)
  initialises a clean session store;
  [`lg_end()`](https://reprostats.org/lineager/reference/lg_end.md)
  prints a summary and marks the session inactive. The store remains
  queryable until the next
  [`lg_start()`](https://reprostats.org/lineager/reference/lg_start.md).

- [`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md) —
  entry point. Assigns a unique lineage ID (`.__lid__`) to every row.
  For datasets with a `USUBJID` column, the ID embeds the subject
  identifier for human readability (`DM_0001_01-042`). For general
  datasets, a zero-padded sequence is used (`patients_000001`).

- [`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
  — tracked filter with mandatory `reason`. Every row removal is
  documented and captured in the session exclusion registry. Optional
  `reason_code` and `population` arguments enrich the record.

- [`lg_derive()`](https://reprostats.org/lineager/reference/lg_derive.md)
  — tracked
  [`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)
  with mandatory `description`. Every variable derivation is recorded in
  the operation log.

- [`lg_join()`](https://reprostats.org/lineager/reference/lg_join.md) —
  tracked join (left, inner, full, right). Preserves `.__lid__` from
  `x`; adds `.__lid_y__` to record which rows of `y` contributed,
  enabling bilateral tracing.

### Documentation functions

- [`lg_population()`](https://reprostats.org/lineager/reference/lg_population.md)
  — register a population or cohort flag definition (SAFFL, ITTFL,
  PPROTFL, or any custom flag). Records inclusion/exclusion criteria,
  plain-English definition, and automatic counts.

- [`lg_spec()`](https://reprostats.org/lineager/reference/lg_spec.md) —
  document a source-to-analysis variable derivation. Links output
  variables back to their source variables and datasets.

### Query functions

- [`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md)
  — trace any row’s complete lineage journey: which datasets it appears
  in, which operations it passed through, and any exclusion records with
  documented reasons.

- [`lg_exclusions()`](https://reprostats.org/lineager/reference/lg_exclusions.md)
  — retrieve the full exclusion registry as a `data.frame`, filterable
  by population or dataset.

- [`lg_disposition()`](https://reprostats.org/lineager/reference/lg_disposition.md)
  — CONSORT-style subject disposition summary, grouped by reason,
  population, or dataset.

- [`lg_operations()`](https://reprostats.org/lineager/reference/lg_operations.md)
  — full pipeline operation log as a `data.frame`.

### Visualisation

- [`lg_lineage()`](https://reprostats.org/lineager/reference/lg_lineage.md)
  — build a lineage graph of the complete pipeline: source datasets, all
  derive/join/filter operations, and exclusion branches, as a Graphviz
  DOT string.

- [`lg_plot()`](https://reprostats.org/lineager/reference/lg_plot.md) —
  render the lineage graph inline (via `DiagrammeR` if installed) or
  write the DOT source to a file.

### Reporting

- [`lg_report()`](https://reprostats.org/lineager/reference/lg_report.md)
  — generate a self-contained HTML provenance report covering dataset
  inventory, subject disposition, population flag definitions, variable
  derivations, operation log, and exclusion listing. For CDISC users,
  the output aligns with CDISC Reviewer’s Guide content requirements.
