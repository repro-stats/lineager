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
#' session log. The `.__lid__` column from `x` is preserved. A secondary
#' column `.__lid_y__` records which rows of `y` contributed to each output
#' row, enabling full bilateral tracing.
#'
#' @param x,y `lg_df` objects.
#' @param by Character vector of join keys, passed to the underlying
#'   [dplyr::left_join()] (etc.) call.
#' @param type Join type: `"left"` (default), `"inner"`, `"full"`,
#'   `"right"`.
#' @param description Character or `NULL`. Optional description of the join
#'   purpose (e.g. `"Merge first dose date from EX domain"`).
#'
#' @return An `lg_df` with the joined result. `.__lid_y__` is added to record
#'   the contributing row IDs from `y`.
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
  desc  <- description %||% sprintf("%s join of '%s' onto '%s'", type, ds_y, ds_x)

  # Rename y's .__lid__ before joining to avoid collision
  y_join <- y
  names(y_join)[names(y_join) == .lid_col] <- ".__lid_y__"

  join_fn <- switch(type,
    left  = dplyr::left_join,
    inner = dplyr::inner_join,
    full  = dplyr::full_join,
    right = dplyr::right_join
  )

  result <- join_fn(x, y_join, by = by)
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
