# lineager (development version)

# lineager 0.1.0

Initial release.

## Core pipeline functions

* `lg_start()` / `lg_end()` — session lifecycle. `lg_start()` initialises
  a clean session store; `lg_end()` prints a summary and marks the session
  inactive. The store remains queryable until the next `lg_start()`.

* `lg_tag()` — entry point. Assigns a unique lineage ID (`.__lid__`) to
  every row. For datasets with a `USUBJID` column, the ID embeds the
  subject identifier for human readability (`DM_0001_01-042`). For
  general datasets, a zero-padded sequence is used (`patients_000001`).

* `lg_filter()` — tracked filter with mandatory `reason`. Every row
  removal is documented and captured in the session exclusion registry.
  Optional `reason_code` and `population` arguments enrich the record.

* `lg_derive()` — tracked `dplyr::mutate()` with mandatory `description`.
  Every variable derivation is recorded in the operation log.

* `lg_join()` — tracked join (left, inner, full, right). Preserves
  `.__lid__` from `x`; adds `.__lid_y__` to record which rows of `y`
  contributed, enabling bilateral tracing.

## Documentation functions

* `lg_population()` — register a population or cohort flag definition
  (SAFFL, ITTFL, PPROTFL, or any custom flag). Records inclusion/exclusion
  criteria, plain-English definition, and automatic counts.

* `lg_spec()` — document a source-to-analysis variable derivation. Links
  output variables back to their source variables and datasets.

## Query functions

* `lg_trace()` — trace any row's complete lineage journey: which datasets
  it appears in, which operations it passed through, and any exclusion
  records with documented reasons.

* `lg_exclusions()` — retrieve the full exclusion registry as a
  `data.frame`, filterable by population or dataset.

* `lg_disposition()` — CONSORT-style subject disposition summary, grouped
  by reason, population, or dataset.

* `lg_operations()` — full pipeline operation log as a `data.frame`.

## Visualisation

* `lg_lineage()` — build a lineage graph of the complete pipeline: source
  datasets, all derive/join/filter operations, and exclusion branches, as
  a Graphviz DOT string.

* `lg_plot()` — render the lineage graph inline (via `DiagrammeR` if
  installed) or write the DOT source to a file.

## Reporting

* `lg_report()` — generate a self-contained HTML provenance report
  covering dataset inventory, subject disposition, population flag
  definitions, variable derivations, operation log, and exclusion listing.
  For CDISC users, the output aligns with CDISC Reviewer's Guide content
  requirements.