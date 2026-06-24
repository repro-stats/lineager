# filter.R
# lg_filter(): tracked filter with mandatory exclusion reason.
#
# This is the heart of lineager's regulatory value.
# Every subject removed from a dataset MUST have a documented reason.
# Excluded subjects, their lineage IDs, USUBJIDs, and reasons are all
# stored in the session exclusion registry — forming the disposition table.


#' Filter a tagged dataset with mandatory exclusion documentation
#'
#' Works exactly like [dplyr::filter()] but requires a `reason` for every
#' exclusion. Rows that do not meet the filter conditions are captured in the
#' session exclusion registry with their USUBJID (if present), lineage ID,
#' and the documented reason.
#'
#' `reason` has no default. Undocumented exclusions are a compliance failure —
#' this is enforced at the R level, not by convention.
#'
#' @param data An `lg_df` from [lg_tag()].
#' @param ... Filter conditions, passed to [dplyr::filter()].
#' @param reason Character. **Mandatory.** Why these rows are being excluded.
#'   E.g. `"Not randomised (RANDFL != 'Y')"`.
#' @param population Character or `NULL`. Which population flag this exclusion
#'   relates to (e.g. `"SAFFL"`). Used to group the exclusion listing.
#' @param reason_code Character or `NULL`. Short controlled-vocabulary code
#'   for this exclusion (e.g. `"NOT_RANDOMISED"`). Useful for programmatic
#'   querying of the exclusion registry.
#'
#' @return An `lg_df` containing only the rows that passed the filter.
#'   Excluded rows are recorded in the session store.
#'
#' @examples
#' lg_start()
#' adsl <- lg_tag(
#'   data.frame(USUBJID = c("01", "02", "03"),
#'              RANDFL  = c("Y", "N", "Y"),
#'              SAFFL   = c("Y", "N", "Y")),
#'   dataset_id = "ADSL"
#' )
#'
#' adsl_rand <- lg_filter(
#'   adsl,
#'   RANDFL == "Y",
#'   reason      = "Not randomised (RANDFL != 'Y')",
#'   reason_code = "NOT_RANDOMISED",
#'   population  = "RANDFL"
#' )
#'
#' @seealso [lg_tag()], [lg_exclusions()], [lg_disposition()]
#' @export
lg_filter <- function(data, ..., reason, population = NULL,
                      reason_code = NULL) {
  .assert_active()
  .assert_tagged(data)
  .assert_reason(reason)

  op_id    <- .next_op_id()
  ds_id    <- attr(data, "lg_dataset_id") %||% "unknown"
  rows_in  <- nrow(data)

  # Apply the filter
  filtered <- dplyr::filter(data, ...)

  # Identify excluded rows by their lineage IDs
  included_lids <- filtered[[.lid_col]]
  all_lids      <- data[[.lid_col]]
  excluded_lids <- setdiff(all_lids, included_lids)

  rows_out      <- length(included_lids)
  rows_excluded <- length(excluded_lids)

  # Build exclusion records for every removed row
  if (rows_excluded > 0L) {
    excl_rows  <- data[data[[.lid_col]] %in% excluded_lids, , drop = FALSE]
    has_subj   <- "USUBJID" %in% names(excl_rows)

    excl_list <- lapply(seq_len(nrow(excl_rows)), function(i) {
      structure(
        list(
          excl_id     = sprintf("%s_excl_%04d", op_id, i),
          op_id       = op_id,
          dataset_id  = ds_id,
          lid         = excl_rows[[.lid_col]][[i]],
          usubjid     = if (has_subj) excl_rows$USUBJID[[i]] else NA_character_,
          reason      = reason,
          reason_code = reason_code %||% NA_character_,
          population  = population %||% NA_character_,
          excluded_at = .utc_now()
        ),
        class = "lg_exclusion"
      )
    })
    .register_exclusions(excl_list)
  }

  # Record the operation
  op <- structure(
    list(
      op_id        = op_id,
      op_type      = "FILTER",
      dataset_id   = ds_id,
      description  = reason,
      population   = population %||% NA_character_,
      rows_in      = rows_in,
      rows_out     = rows_out,
      rows_excluded = rows_excluded,
      timestamp    = .utc_now()
    ),
    class = "lg_operation"
  )
  .register_operation(op)

  # Update history on the returned dataset
  history <- attr(filtered, "lg_history") %||% list()
  attr(filtered, "lg_history") <- c(history, list(op))
  attr(filtered, "lg_row_count") <- rows_out

  message(sprintf(
    "lineager: [%s] filter '%s' \u2014 %d in, %d out, %d excluded",
    ds_id, reason, rows_in, rows_out, rows_excluded
  ))

  filtered
}
