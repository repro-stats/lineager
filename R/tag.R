# tag.R
# lg_tag(): entry point to the lineager system.
# Assigns a unique lineage ID (lineage_id) to every row of a dataset and
# registers it in the session store.
#
# lineage_id format: {dataset_id}_{zero-padded sequence}
# For CDISC SDTM datasets with USUBJID, the USUBJID is embedded:
#   LB_0001_STUDY-001-042
# This makes IDs human-inspectable without needing a lookup table.


#' Tag a dataset to begin lineage tracking
#'
#' Assigns a unique lineage identifier (`lineage_id`) to every row and registers
#' the dataset in the active session store. This is the entry point to
#' `lineager` : all other functions require a tagged data frame.
#'
#' The `lineage_id` column is added at position 1 and is preserved through
#' [lg_filter()], [lg_derive()], and [lg_join()] operations. It allows
#' every row in any downstream dataset to be traced back to its origin.
#'
#' @param data A `data.frame` or `tibble`.
#' @param dataset_id Character. Short identifier for this dataset, e.g.
#'   `"LB"`, `"ADLB"`, `"ADSL"`. Used as the prefix in lineage IDs and
#'   in report output.
#' @param domain Character or `NULL`. CDISC domain code if applicable
#'   (e.g. `"DM"`, `"LB"`, `"AE"`). Used for SDTM-to-ADaM mapping and
#'   Reviewer's Guide output.
#' @param label Character or `NULL`. Human-readable label for the dataset
#'   (e.g. `"Laboratory test results"`). Used in reports.
#' @param source Character or `NULL`. Source file or system description.
#' @param overwrite Logical. If `dataset_id` is already registered in this
#'   session, `lg_tag()` errors by default : any `lg_df` object still held
#'   from the previous registration would silently stop being traceable via
#'   [lg_trace()] the moment the registration is replaced. Set `overwrite =
#'   TRUE` to explicitly allow re-tagging (e.g. intentionally re-running a
#'   step) and acknowledge that the prior object is no longer traceable.
#'
#' @return An `lg_df` object : a `data.frame` with a `lineage_id` column and
#'   lineage metadata stored in attributes.
#'
#' @examples
#' lg_start()
#'
#' dm <- data.frame(
#'   USUBJID = c("01-001", "01-002", "01-003"),
#'   AGE     = c(34L, 52L, 47L),
#'   SEX     = c("M", "F", "M")
#' )
#'
#' dm_tagged <- lg_tag(dm, dataset_id = "DM", domain = "DM",
#'                     label = "Demographics")
#' dm_tagged
#'
#' @seealso [lg_filter()], [lg_derive()], [lg_trace()]
#' @export
lg_tag <- function(data, dataset_id, domain = NULL, label = NULL,
                   source = NULL, overwrite = FALSE) {
  .assert_active()

  if (!is.data.frame(data))   stop("`data` must be a data.frame or tibble.")
  if (!is.character(dataset_id) || !nzchar(dataset_id)) {
    stop("`dataset_id` must be a non-empty character string.")
  }
  if (dataset_id %in% names(.lg$datasets) && !isTRUE(overwrite)) {
    stop(sprintf(
      "dataset_id '%s' is already registered in this session.\n",
      dataset_id
    ), "  Any lg_df object tagged under the previous registration will no ",
    "longer be traceable via lg_trace() once it is replaced.\n",
    "  Set `overwrite = TRUE` if this is intentional, or choose a ",
    "different dataset_id.")
  }

  n <- nrow(data)

  # Build lineage IDs: embed USUBJID when available for human-readability
  has_usubjid <- "USUBJID" %in% names(data)
  if (has_usubjid) {
    lids <- sprintf("%s_%04d_%s", dataset_id, seq_len(n), data$USUBJID)
  } else {
    lids <- sprintf("%s_%06d", dataset_id, seq_len(n))
  }

  # Insert lineage_id at position 1
  out <- data.frame(.lid_placeholder_ = lids, data, stringsAsFactors = FALSE,
                    check.names = FALSE)
  names(out)[1L] <- .lid_col

  # Attach lineage metadata as attributes
  attr(out, "lg_dataset_id") <- dataset_id
  attr(out, "lg_domain")     <- domain
  attr(out, "lg_label")      <- label %||% dataset_id
  attr(out, "lg_source")     <- source
  attr(out, "lg_row_count")  <- n
  attr(out, "lg_tagged_at")  <- .utc_now()
  attr(out, "lg_history")    <- list()

  class(out) <- c("lg_df", "data.frame")

  # Register in session store
  .lg$datasets[[dataset_id]] <- list(
    dataset_id = dataset_id,
    domain     = domain,
    label      = label %||% dataset_id,
    source     = source,
    n_rows     = n,
    lids       = lids,
    tagged_at  = attr(out, "lg_tagged_at")
  )

  message(sprintf("lineager: tagged '%s' \u2014 %d rows, %d cols",
                  dataset_id, n, ncol(data)))
  out
}


# --------------------------------------------------------------------------- #
#  S3 methods for lg_df                                                        #
# --------------------------------------------------------------------------- #

#' @importFrom utils head
#' @export
print.lg_df <- function(x, ...) {
  ds  <- attr(x, "lg_dataset_id") %||% "unknown"
  dom <- attr(x, "lg_domain")
  cat(sprintf(
    "<lg_df> '%s'%s  [%d \u00d7 %d]\n",
    ds,
    if (!is.null(dom)) sprintf(" (domain: %s)", dom) else "",
    nrow(x), ncol(x)
  ))
  # Strip lineage_id and lg_df class before printing to avoid infinite recursion:
  # print.lg_df -> [.lg_df (returns lg_df) -> print.lg_df -> ...
  visible <- x[, names(x) != .lid_col, drop = FALSE]
  class(visible) <- "data.frame"
  print(head(visible, 6L))
  if (nrow(x) > 6L) cat(sprintf("# \u2026 %d more rows\n", nrow(x) - 6L))
  invisible(x)
}

#' Subset an `lg_df`, preserving lineage attributes
#'
#' @details
#' `[.lg_df` deliberately forces `drop = FALSE`, unlike base `[.data.frame`.
#' This means single-column subsetting (e.g. `df[, "col"]`) returns a
#' one-column `lg_df`/`data.frame` rather than a bare vector, so the lineage
#' attributes are never silently lost through ordinary subsetting. Use
#' `df[[col]]` or `lg_id(df)` when a plain vector is what you actually want.
#'
#' @param x An `lg_df` object.
#' @param i Row index, as in `[.data.frame`.
#' @param j Column index, as in `[.data.frame`.
#' @param drop Ignored : `lg_df` subsetting always behaves as though
#'   `drop = FALSE`. See Details.
#'
#' @return An `lg_df` with lineage attributes preserved (or a plain
#'   `data.frame`/vector for subsetting operations where preservation
#'   is not applicable, matching normal `[.data.frame` fallback behaviour).
#' @export
`[.lg_df` <- function(x, i, j, drop = FALSE) {
  # Preserve lg_df class and attributes through subsetting
  attrs <- attributes(x)
  result <- NextMethod()
  if (is.data.frame(result)) {
    for (a in names(attrs)) {
      if (!a %in% c("names", "row.names", "class")) {
        attr(result, a) <- attrs[[a]]
      }
    }
    class(result) <- c("lg_df", "data.frame")
    # Update row count
    attr(result, "lg_row_count") <- nrow(result)
  }
  result
}


#' Retrieve lineage IDs from a tagged dataset
#'
#' Returns the `lineage_id` vector from an `lg_df` object. Use this instead
#' of accessing the column directly to keep code robust against future
#' internal changes.
#'
#' @param data An `lg_df` from [lg_tag()].
#' @return A character vector of lineage IDs, one per row.
#'
#' @examples
#' lg_start()
#' dm <- data.frame(USUBJID = c("01-001", "01-002"), AGE = c(34L, 52L))
#' dm_tagged <- lg_tag(dm, dataset_id = "DM")
#' lg_id(dm_tagged)
#'
#' @export
lg_id <- function(data) {
  .assert_tagged(data)
  data[[.lid_col]]
}


#' Retrieve the operation history recorded on a tagged object
#'
#' Every `lg_df` accumulates the sequence of [lg_filter()], [lg_derive()],
#' and [lg_join()] operations that produced it, in its `lg_history`
#' attribute. `lg_history()` returns that sequence directly rather than
#' requiring `attr(data, "lg_history")`.
#'
#' @param data An `lg_df` object.
#' @return A list of `lg_operation` records applied to this specific object,
#'   in the order they were applied. Empty list if none yet.
#'
#' @examples
#' lg_start()
#' dm <- lg_tag(
#'   data.frame(USUBJID = c("01", "02"), AGE = c(20L, 15L)),
#'   dataset_id = "DM"
#' )
#' dm_f <- lg_filter(dm, AGE >= 18L, reason = "Minors excluded")
#' length(lg_history(dm_f))
#'
#' @export
lg_history <- function(data) {
  .assert_tagged(data)
  attr(data, "lg_history") %||% list()
}