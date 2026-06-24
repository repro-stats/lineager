# tag.R
# lg_tag(): entry point to the lineager system.
# Assigns a unique lineage ID (.__lid__) to every row of a dataset and
# registers it in the session store.
#
# .__lid__ format: {dataset_id}_{zero-padded sequence}
# For CDISC SDTM datasets with USUBJID, the USUBJID is embedded:
#   LB_0001_STUDY-001-042
# This makes IDs human-inspectable without needing a lookup table.


#' Tag a dataset to begin lineage tracking
#'
#' Assigns a unique lineage identifier (`.__lid__`) to every row and registers
#' the dataset in the active session store. This is the entry point to
#' `lineager` : all other functions require a tagged data frame.
#'
#' The `.__lid__` column is added at position 1 and is preserved through
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
#'
#' @return An `lg_df` object : a `data.frame` with a `.__lid__` column and
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
                   source = NULL) {
  .assert_active()

  if (!is.data.frame(data))   stop("`data` must be a data.frame or tibble.")
  if (!is.character(dataset_id) || !nzchar(dataset_id)) {
    stop("`dataset_id` must be a non-empty character string.")
  }
  if (dataset_id %in% names(.lg$datasets)) {
    warning(sprintf(
      "lineager: dataset_id '%s' already registered. Re-tagging replaces prior registration.",
      dataset_id
    ))
  }

  n <- nrow(data)

  # Build lineage IDs: embed USUBJID when available for human-readability
  has_usubjid <- "USUBJID" %in% names(data)
  if (has_usubjid) {
    lids <- sprintf("%s_%04d_%s", dataset_id, seq_len(n), data$USUBJID)
  } else {
    lids <- sprintf("%s_%06d", dataset_id, seq_len(n))
  }

  # Insert .__lid__ at position 1
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
  # Strip .__lid__ and lg_df class before printing to avoid infinite recursion:
  # print.lg_df -> [.lg_df (returns lg_df) -> print.lg_df -> ...
  visible <- x[, names(x) != .lid_col, drop = FALSE]
  class(visible) <- "data.frame"
  print(head(visible, 6L))
  if (nrow(x) > 6L) cat(sprintf("# \u2026 %d more rows\n", nrow(x) - 6L))
  invisible(x)
}

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