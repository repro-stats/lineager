# Changelog

## lineager (development version)

### Bug fixes

- [`lg_join()`](https://reprostats.org/lineager/reference/lg_join.md) no
  longer silently mangles bilateral tracing when joins are chained.
  Previously, every join’s `y`-side tracing column was named
  `lineage_id_y`, so joining a third dataset onto the result of an
  earlier join would silently overwrite the first join’s tracing column.
  A single, non-chained join still produces the same `lineage_id_y`
  column name as before (no change for the common case); only when `x`
  already carries a `lineage_id_y` column from an earlier join in the
  same chain does the new join fall back to a uniquely-named column
  (`lineage_id_y__<op_id>`), with a message identifying the fallback.

- `lg_join(type = "inner")` and `lg_join(type = "right")` can drop rows
  of `x` that have no matching `y` record. These drops are now
  registered in the exclusion registry with a documented reason,
  consistent with
  [`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)’s
  core design principle that every row removal must be documented.
  `description` is now required the moment such a join actually drops
  one or more rows; if no rows are dropped, `description` remains
  optional. `"left"` and `"full"` joins are unaffected, since they never
  drop rows of `x`.

- `lg_disposition(by = "reason")` now returns the actual chronological
  disposition funnel (`step`, `reason`, `n_excluded`, `n_remaining`, one
  row per
  [`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
  call in execution order) instead of a frequency-sorted summary
  (`group`, `n_excluded`) that could not represent cumulative remaining
  counts. `by = "population"` and `by = "dataset"` still return
  `group`/`n_excluded`, now with an added `n_remaining` column.

- [`lg_operations()`](https://reprostats.org/lineager/reference/lg_operations.md)
  was silently dropping the `population` and `rows_excluded` fields
  already present on `FILTER` operations. Both are now included in the
  returned data frame; `rows_excluded` falls back to
  `rows_in - rows_out` when not directly recorded.

- [`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md)
  matched subjects by an unanchored substring search, so a USUBJID that
  is a substring of another (e.g. `"01"` inside `"101"`) could silently
  return another subject’s data. Matching is now exact against the
  `_<usubjid>` suffix embedded in `lineage_id`.

- [`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md)
  re-registering an already-used `dataset_id` now errors instead of only
  warning. Any `lg_df` object held from the prior registration silently
  stops being traceable via
  [`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md)
  once the registration is replaced; a warning was too easy to miss
  given that consequence. Set `overwrite = TRUE` to explicitly allow
  re-tagging.

- [`lg_population()`](https://reprostats.org/lineager/reference/lg_population.md)
  hardcoded `"Y"` as the only recognised “included” value, giving
  silently incorrect counts for non-CDISC flags (e.g. logical
  `TRUE`/`FALSE` columns were counted as entirely excluded). Added an
  `included_value` argument (default `"Y"`, unchanged for existing CDISC
  usage).

- [`lg_spec()`](https://reprostats.org/lineager/reference/lg_spec.md)
  now warns when overwriting an existing `adam_dataset`/ `adam_var` key,
  for consistency with
  [`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md)’s
  and
  [`lg_population()`](https://reprostats.org/lineager/reference/lg_population.md)’s
  guards against silent re-registration. Overwriting still succeeds;
  only the silent case is now flagged.

- [`lg_report()`](https://reprostats.org/lineager/reference/lg_report.md)
  did not escape user-supplied text (reasons, descriptions, labels,
  definitions, etc.) before inserting it into the HTML template. Reason
  strings containing `<`, `>`, or `&` — common in exclusion criteria
  such as `"AGE < 18 & CONSENT != 'Y'"` — could corrupt the rendered
  table. All dynamic content is now HTML-escaped. Fixed a related issue
  where missing (`NA`) values in the exclusion listing rendered as the
  literal string `"NA"` instead of the intended em-dash placeholder.

### New features

- Added
  [`lg_history()`](https://reprostats.org/lineager/reference/lg_history.md),
  an accessor for the operation sequence recorded on a tagged object
  (previously only reachable via `attr(data, "lg_history")`).

### Documentation

- `README.md` and the package-level documentation now list
  [`lg_history()`](https://reprostats.org/lineager/reference/lg_history.md)
  in the function reference table.
- [`vignette("getting-started")`](https://reprostats.org/lineager/articles/getting-started.md)
  documents when
  [`lg_join()`](https://reprostats.org/lineager/reference/lg_join.md)
  requires `description` for `"inner"`/`"right"` joins.
- [`vignette("populations-and-reporting")`](https://reprostats.org/lineager/articles/populations-and-reporting.md)
  notes that the “Overwriting a spec” example intentionally triggers
  [`lg_spec()`](https://reprostats.org/lineager/reference/lg_spec.md)’s
  new overwrite warning.

### Testing

- Test coverage increased from 98.18% to 99.89%
  ([`covr::package_coverage()`](http://covr.r-lib.org/reference/package_coverage.md)),
  with new tests specifically targeting each fix above: chained-join
  collision avoidance, backward-compatible single-join naming,
  inner/right join row-drop documentation, the disposition funnel’s
  chronological ordering, exact USUBJID matching, HTML-escaping
  (including the previously-untested `NA` branch), the
  [`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md)
  overwrite guard, and
  [`lg_population()`](https://reprostats.org/lineager/reference/lg_population.md)’s
  `included_value` argument.

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
  entry point. Assigns a unique lineage ID (`lineage_id`) to every row.
  For datasets with a `USUBJID` column, the ID embeds the subject
  identifier for human readability (`DM_0001_01-042`). For general
  datasets, a zero-padded sequence is used (`patients_000001`).
  Re-tagging an already-registered `dataset_id` errors by default, since
  any `lg_df` object still held from the earlier registration would
  silently stop being traceable via
  [`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md)
  the moment the registration is replaced; pass `overwrite = TRUE` to
  allow it explicitly.

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
  tracked join (left, inner, full, right). Preserves `lineage_id` from
  `x`; adds `lineage_id_y` to record which rows of `y` contributed,
  enabling bilateral tracing. For `type = "inner"` or `type = "right"`,
  a `description` is required the moment the join actually drops one or
  more unmatched rows of `x` — those rows are subjects being silently
  removed from the pipeline, and per lineager’s core design every
  exclusion must carry a documented reason; dropped rows are registered
  in the exclusion registry exactly like a
  [`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
  exclusion. If `x` already carries a `lineage_id_y` column from an
  earlier join in the same chain, the new join’s y-tracing column is
  instead named `lineage_id_y__<op_id>` to avoid silently colliding with
  the earlier one.

### Documentation functions

- [`lg_population()`](https://reprostats.org/lineager/reference/lg_population.md)
  — register a population or cohort flag definition (SAFFL, ITTFL,
  PPROTFL, or any custom flag). Records inclusion/exclusion criteria,
  plain-English definition, and automatic counts. The value denoting
  inclusion defaults to `"Y"` (the CDISC convention) but is configurable
  via `included_value` for logical or custom-coded flags. Re-registering
  an existing flag warns rather than silently overwriting.

- [`lg_spec()`](https://reprostats.org/lineager/reference/lg_spec.md) —
  document a source-to-analysis variable derivation. Links output
  variables back to their source variables and datasets. Re-registering
  an existing `adam_dataset`/`adam_var` key warns rather than silently
  overwriting.

### Query functions

- [`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md)
  — trace any row’s complete lineage journey: which datasets it appears
  in, which operations it passed through, and any exclusion records with
  documented reasons. Matches on the exact `USUBJID` suffix of the
  lineage ID, so one subject ID that happens to be a substring of
  another (e.g. `"01"` within `"101"`) cannot produce a false match.

- [`lg_history()`](https://reprostats.org/lineager/reference/lg_history.md)
  — retrieve the sequence of operations recorded on a specific tagged
  object, in the order they were applied.

- [`lg_exclusions()`](https://reprostats.org/lineager/reference/lg_exclusions.md)
  — retrieve the full exclusion registry as a `data.frame`, filterable
  by population or dataset.

- [`lg_disposition()`](https://reprostats.org/lineager/reference/lg_disposition.md)
  — CONSORT-style subject disposition summary. With the default
  `by = "reason"`, returns one row per contributing step (a filter, or a
  row-dropping join) in the exact order it was executed, with the number
  excluded and the number remaining immediately after — a true
  chronological funnel. `by = "population"` and `by = "dataset"`
  aggregate exclusions across steps that share a group. Every documented
  exclusion, whether from
  [`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
  or a row-dropping
  [`lg_join()`](https://reprostats.org/lineager/reference/lg_join.md),
  is reflected here, so totals always match
  [`lg_exclusions()`](https://reprostats.org/lineager/reference/lg_exclusions.md).

- [`lg_operations()`](https://reprostats.org/lineager/reference/lg_operations.md)
  — full pipeline operation log as a `data.frame`, including population
  and row-excluded counts for every operation type.

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
  derivations, operation log, and exclusion listing. All user-supplied
  text (reasons, descriptions, labels, definitions) is HTML-escaped
  before rendering. For CDISC users, the output aligns with CDISC
  Reviewer’s Guide content requirements.
