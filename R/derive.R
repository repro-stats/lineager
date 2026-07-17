# derive.R
# lg_derive(): tracked mutate \u2014 documents new variable derivations.
# lg_join():   tracked join \u2014 records which source datasets contributed each row.


#' Derive new variables with documented derivation
#'
#' Works exactly like [dplyr::mutate()] but records a derivation description
#' in the session operation log. Use this when computing ADaM analysis
#' variables from SDTM source variables.
#'
#' @param data An `lg_df` from [lg_tag()].
#' @param ... Name-value pairs of derivations, passed to [dplyr::mutate()].
#' @param description Character. **Required.** What is being derived and from
#'   what source. E.g. `"AVAL: numeric conversion of LBORRES; LBSTRESN used
#'   where LBORRES is missing or non-numeric"`.
#'
#' @return An `lg_df` with derived variables added.
#'
#' @examples
#' lg_start()
#' lb <- lg_tag(
#'   data.frame(USUBJID = "01-001", LBORRES = "12.4",
#'              LBSTRESN = 12.4, stringsAsFactors = FALSE),
#'   dataset_id = "LB", domain = "LB"
#' )
#'
#' lb_derived <- lg_derive(
#'   lb,
#'   AVAL = dplyr::coalesce(LBSTRESN, suppressWarnings(as.numeric(LBORRES))),
#'   description = "AVAL: LBSTRESN; numeric LBORRES where LBSTRESN is missing"
#' )
#'
#' @seealso [lg_filter()], [lg_join()], [lg_spec()]
#' @export
lg_derive <- function(data, ..., description) {
  .assert_active()
  .assert_tagged(data)

  if (missing(description) || !is.character(description) || !nzchar(trimws(description))) {
    stop("`description` is required for lg_derive(). Document what is being derived and why.")
  }

  op_id  <- .next_op_id()
  ds_id  <- attr(data, "lg_dataset_id") %||% "unknown"
  n_rows <- nrow(data)

  result <- dplyr::mutate(data, ...)

  # Restore lg_df class and attributes (dplyr::mutate may strip them)
  result <- .restore_lg_attrs(result, data)

  op <- structure(
    list(
      op_id       = op_id,
      op_type     = "DERIVE",
      dataset_id  = ds_id,
      description = description,
      rows_in     = n_rows,
      rows_out    = nrow(result),
      timestamp   = .utc_now()
    ),
    class = "lg_operation"
  )
  .register_operation(op)

  history <- attr(result, "lg_history") %||% list()
  attr(result, "lg_history") <- c(history, list(op))

  message(sprintf("lineager: [%s] derive \u2014 %s", ds_id, description))
  result
}


#' Join two tagged datasets with lineage tracking
#'
#' Performs a left, inner, full, or right join and records the operation in the
#' session log. The `lineage_id` column from `x` is preserved. A secondary
#' column records which rows of `y` contributed to each output row, enabling
#' full bilateral tracing.
#'
#' @param x,y `lg_df` objects.
#' @param by Character vector of join keys, passed to the underlying
#'   [dplyr::left_join()] (etc.) call.
#' @param type Join type: `"left"` (default), `"inner"`, `"full"`,
#'   `"right"`.
#' @param description Character or `NULL`. Description of the join purpose
#'   (e.g. `"Merge first dose date from EX domain"`). For `type = "inner"`
#'   or `type = "right"`, `description` becomes **mandatory** the moment the
#'   join actually drops one or more rows of `x` (i.e. `x` rows with no
#'   matching `y` record) : those dropped rows are subjects being silently
#'   removed from the pipeline, and per lineager's core design, every
#'   exclusion must carry a documented reason. If no rows end up dropped,
#'   `description` stays optional as before.
#'
#' @return An `lg_df` with the joined result. A `lineage_id_y` column is
#'   added recording the contributing row IDs from `y`, matching prior
#'   versions of `lineager`. If `x` already carries a `lineage_id_y` column
#'   from an earlier join in the same chain (e.g. joining a third dataset
#'   onto the result of a previous `lg_join()` call), this join's own
#'   y-tracing column is instead named `lineage_id_y__<op_id>` (e.g.
#'   `lineage_id_y__op_0003`) so it cannot silently collide with -- or
#'   overwrite -- the earlier join's tracing column. A message is printed
#'   whenever this fallback naming is used.
#'
#' @details
#' Only unmatched rows of `x` are exclusion-tracked (since `x` is treated as
#' the primary, subject-carrying dataset in lineager's model). Unmatched rows
#' of `y` dropped by `"left"` or `"inner"` joins are not separately logged as
#' exclusions of `y`'s own dataset : if `y`-side row loss also needs
#' documented tracking for your use case, log it explicitly with
#' [lg_filter()] on `y` before joining.
#'
#' @examples
#' lg_start()
#'
#' adsl <- lg_tag(
#'   data.frame(USUBJID = c("01", "02"), TRT01P = c("Active", "Placebo")),
#'   dataset_id = "ADSL"
#' )
#' ex_summary <- lg_tag(
#'   data.frame(USUBJID = c("01", "02"), EXSTDTC_min = c("2026-01-01", "2026-01-03")),
#'   dataset_id = "EX_SUMM"
#' )
#'
#' adsl_ex <- lg_join(adsl, ex_summary, by = "USUBJID",
#'                    description = "First dose date from EX domain")
#'
#' @seealso [lg_derive()], [lg_filter()]
#' @export
lg_join <- function(x, y, by, type = c("left", "inner", "full", "right"),
                    description = NULL) {
  .assert_active()
  .assert_tagged(x, "x")
  .assert_tagged(y, "y")
  type <- match.arg(type)

  op_id <- .next_op_id()
  ds_x  <- attr(x, "lg_dataset_id") %||% "x"
  ds_y  <- attr(y, "lg_dataset_id") %||% "y"

  # Rename y's lineage_id before joining to avoid colliding with x's own
  # lineage_id column. In the common, non-chained case this column keeps its
  # long-standing name "lineage_id_y" -- unchanged from prior behaviour, so
  # existing code/vignettes that reference it directly keep working. Only
  # when x ALREADY carries a "lineage_id_y" column (i.e. this is a second
  # or later join in a chain) does it get a distinguishing, op_id-based name
  # instead -- avoiding the silent column collision that previously mangled
  # bilateral tracing on chained joins, without breaking the ordinary case.
  y_lid_name <- "lineage_id_y"
  if (y_lid_name %in% names(x)) {
    y_lid_name <- paste0("lineage_id_y__", op_id)
    message(sprintf(
      "lineager: '%s' already has a 'lineage_id_y' column from an earlier join in this chain; recording this join's y-tracing column as '%s' instead.",
      ds_x, y_lid_name
    ))
  }
  y_join <- y
  names(y_join)[names(y_join) == .lid_col] <- y_lid_name

  join_fn <- switch(type,
    left  = dplyr::left_join,
    inner = dplyr::inner_join,
    full  = dplyr::full_join,
    right = dplyr::right_join
  )

  result <- join_fn(x, y_join, by = by)

  # Inner/right joins can silently drop x rows that have no matching y
  # record. Per lineager's core design, every row removed from the pipeline
  # must carry a documented reason -- so treat those drops the same way
  # lg_filter() treats an exclusion: register them in the session exclusion
  # registry, and require `description` the moment a drop actually occurs.
  if (type %in% c("inner", "right")) {
    included_lids <- result[[.lid_col]]
    all_lids_x <- x[[.lid_col]]
    dropped_lids <- setdiff(all_lids_x, included_lids)

    if (length(dropped_lids) > 0L) {
      if (is.null(description) || !is.character(description) ||
          !nzchar(trimws(description))) {
        stop(sprintf(
          "lg_join(type = \"%s\") drops %d row(s) from '%s' with no matching '%s' record.\n",
          type, length(dropped_lids), ds_x, ds_y
        ), "  Provide a `description` documenting why these unmatched rows ",
        "are being dropped, or use type = \"left\"/\"full\" to keep them.")
      }

      dropped_rows <- x[x[[.lid_col]] %in% dropped_lids, , drop = FALSE]
      has_subj <- "USUBJID" %in% names(dropped_rows)

      excl_list <- lapply(seq_len(nrow(dropped_rows)), function(i) {
        structure(
          list(
            excl_id     = sprintf("%s_excl_%04d", op_id, i),
            op_id       = op_id,
            dataset_id  = ds_x,
            lid         = dropped_rows[[.lid_col]][[i]],
            usubjid     = if (has_subj) dropped_rows$USUBJID[[i]] else NA_character_,
            reason      = description,
            reason_code = NA_character_,
            population  = NA_character_,
            excluded_at = .utc_now()
          ),
          class = "lg_exclusion"
        )
      })
      .register_exclusions(excl_list)
    }
  }

  desc <- description %||% sprintf("%s join of '%s' onto '%s'", type, ds_y, ds_x)

  result <- .restore_lg_attrs(result, x)

  op <- structure(
    list(
      op_id        = op_id,
      op_type      = sprintf("JOIN_%s", toupper(type)),
      dataset_id   = ds_x,
      source_y     = ds_y,
      description  = desc,
      by           = paste(by, collapse = ", "),
      rows_in      = nrow(x),
      rows_out     = nrow(result),
      rows_excluded = nrow(x) - sum(x[[.lid_col]] %in% result[[.lid_col]]),
      timestamp    = .utc_now()
    ),
    class = "lg_operation"
  )
  .register_operation(op)

  history <- attr(result, "lg_history") %||% list()
  attr(result, "lg_history") <- c(history, list(op))

  message(sprintf("lineager: [%s + %s] %s join \u2014 %d rows out",
                  ds_x, ds_y, type, nrow(result)))
  result
}


# Internal: restore lg_df class and lineage attrs after dplyr operations
.restore_lg_attrs <- function(result, source) {
  preserve <- c("lg_dataset_id", "lg_domain", "lg_label",
                "lg_source", "lg_history", "lg_tagged_at")
  for (a in preserve) {
    attr(result, a) <- attr(source, a)
  }
  attr(result, "lg_row_count") <- nrow(result)
  class(result) <- c("lg_df", "data.frame")
  result
}