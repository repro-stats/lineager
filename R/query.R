# query.R
# Three query functions — the payoff of tagging and tracking:
#
# lg_trace():       trace a subject's complete journey across the pipeline
# lg_exclusions():  retrieve the exclusion registry as a data frame
# lg_disposition(): CONSORT-style subject disposition summary


#' Trace a subject's complete lineage journey
#'
#' Given a USUBJID (or a `.__lid__` value), returns the complete history of
#' that subject across all tagged datasets and operations in the session:
#' which datasets they appear in, which operations they passed through or were
#' excluded by, and which population flags apply to them.
#'
#' This is the key regulatory tracing capability — a reviewer can ask
#' "show me everything that happened to subject 01-042" and get a complete,
#' programmatically generated answer.
#'
#' @param usubjid Character. The subject identifier to trace. Must match a
#'   value of `USUBJID` in at least one tagged dataset.
#' @param verbose Logical. If `TRUE` (default), prints a formatted trace
#'   to the console.
#'
#' @return A list (invisibly) with components:
#' \describe{
#'   \item{`usubjid`}{The traced subject ID.}
#'   \item{`datasets`}{Character vector of dataset IDs the subject appears in.}
#'   \item{`operations`}{Data frame of operations applied to datasets
#'     containing this subject.}
#'   \item{`exclusions`}{Data frame of exclusion records for this subject,
#'     or a zero-row data frame if none.}
#'   \item{`populations`}{Named list of population flag values for this
#'     subject across all registered populations.}
#' }
#'
#' @examples
#' lg_start()
#' adsl <- lg_tag(
#'   data.frame(USUBJID = c("01", "02", "03"),
#'              RANDFL  = c("Y", "N", "Y")),
#'   dataset_id = "ADSL"
#' )
#' lg_filter(adsl, RANDFL == "Y",
#'           reason = "Not randomised", population = "RANDFL")
#'
#' lg_trace("02")
#'
#' @seealso [lg_exclusions()], [lg_disposition()]
#' @export
lg_trace <- function(usubjid, verbose = TRUE) {
  .assert_active()

  if (!is.character(usubjid) || length(usubjid) != 1L) {
    stop("`usubjid` must be a single character string.")
  }

  # Find which datasets this subject appears in (by matching lid prefix or USUBJID)
  subject_lids <- character(0)
  subject_datasets <- character(0)

  for (ds_id in names(.lg$datasets)) {
    ds <- .lg$datasets[[ds_id]]
    matching <- grep(usubjid, ds$lids, fixed = TRUE, value = TRUE)
    if (length(matching) > 0L) {
      subject_lids    <- c(subject_lids, matching)
      subject_datasets <- c(subject_datasets, ds_id)
    }
  }

  # Find exclusions for this subject
  all_excl <- lg_exclusions(verbose = FALSE)
  subj_excl <- if (nrow(all_excl) > 0L) {
    all_excl[!is.na(all_excl$usubjid) & all_excl$usubjid == usubjid, ,
             drop = FALSE]
  } else {
    all_excl[0L, , drop = FALSE]
  }

  # Find operations that touched datasets containing this subject
  ops <- lg_operations(verbose = FALSE)
  subj_ops <- if (nrow(ops) > 0L) {
    ops[ops$dataset_id %in% subject_datasets, , drop = FALSE]
  } else {
    ops[0L, , drop = FALSE]
  }

  # Find population flag values for this subject
  # (only available if data is still in scope — we store flag values in pops)
  pop_values <- lapply(names(.lg$populations), function(flag) {
    pop <- .lg$populations[[flag]]
    list(flag_var = flag, label = pop$label,
         definition = pop$definition)
  })
  names(pop_values) <- names(.lg$populations)

  result <- list(
    usubjid     = usubjid,
    datasets    = subject_datasets,
    operations  = subj_ops,
    exclusions  = subj_excl,
    populations = pop_values
  )

  if (verbose) .print_trace(result)

  invisible(result)
}

.print_trace <- function(tr) {
  cat(sprintf("\n\u2500\u2500 lineager trace: USUBJID '%s' \u2500\u2500\n\n",
              tr$usubjid))

  if (length(tr$datasets) == 0L) {
    cat("  [not found in any tagged dataset]\n\n")
    return(invisible(NULL))
  }

  cat(sprintf("  Appears in: %s\n\n", paste(tr$datasets, collapse = ", ")))

  if (nrow(tr$operations) > 0L) {
    cat("  Operations:\n")
    for (i in seq_len(nrow(tr$operations))) {
      op <- tr$operations[i, ]
      cat(sprintf("    [%s] %s: %s (%d\u2192%d)\n",
                  op$op_type, op$dataset_id,
                  substr(op$description, 1L, 60L),
                  op$rows_in, op$rows_out))
    }
    cat("\n")
  }

  if (nrow(tr$exclusions) > 0L) {
    cat(sprintf("  Exclusions (%d):\n", nrow(tr$exclusions)))
    for (i in seq_len(nrow(tr$exclusions))) {
      ex <- tr$exclusions[i, ]
      cat(sprintf("    \u2717 [%s] %s%s\n",
                  ex$dataset_id %||% "?",
                  ex$reason,
                  if (!is.na(ex$population)) sprintf(" [pop: %s]", ex$population) else ""))
    }
    cat("\n")
  } else {
    cat("  Exclusions: none\n\n")
  }

  if (length(tr$populations) > 0L) {
    cat("  Registered populations:\n")
    for (nm in names(tr$populations)) {
      p <- tr$populations[[nm]]
      cat(sprintf("    %s: %s\n", p$flag_var, p$label))
    }
    cat("\n")
  }
}


#' Retrieve the exclusion registry
#'
#' Returns all exclusions recorded by [lg_filter()] calls during the active
#' session as a flat `data.frame`. This is the data underlying the subject
#' disposition listing — every excluded subject, with their USUBJID, the
#' reason they were excluded, and which population the exclusion relates to.
#'
#' @param population Character or `NULL`. Filter to a specific population flag
#'   (e.g. `"SAFFL"`). `NULL` returns all exclusions.
#' @param dataset_id Character or `NULL`. Filter to a specific dataset.
#' @param verbose Logical. If `TRUE` (default), prints a count summary.
#'
#' @return A `data.frame` with columns: `excl_id`, `op_id`, `dataset_id`,
#'   `lid`, `usubjid`, `reason`, `reason_code`, `population`, `excluded_at`.
#'
#' @examples
#' lg_start()
#' adsl <- lg_tag(
#'   data.frame(USUBJID = c("01","02","03"), RANDFL = c("Y","N","Y")),
#'   dataset_id = "ADSL"
#' )
#' lg_filter(adsl, RANDFL == "Y",
#'           reason = "Not randomised", population = "RANDFL")
#'
#' lg_exclusions()
#'
#' @seealso [lg_trace()], [lg_disposition()]
#' @export
lg_exclusions <- function(population = NULL, dataset_id = NULL,
                          verbose = TRUE) {
  .assert_active()

  if (length(.lg$exclusions) == 0L) {
    if (verbose) message("lineager: no exclusions recorded in this session")
    return(.empty_excl_frame())
  }

  rows <- lapply(.lg$exclusions, function(e) {
    data.frame(
      excl_id     = e$excl_id,
      op_id       = e$op_id,
      dataset_id  = e$dataset_id,
      lid         = e$lid,
      usubjid     = e$usubjid %||% NA_character_,
      reason      = e$reason,
      reason_code = e$reason_code %||% NA_character_,
      population  = e$population %||% NA_character_,
      excluded_at = e$excluded_at,
      stringsAsFactors = FALSE
    )
  })
  df <- do.call(rbind, rows)

  if (!is.null(population)) df <- df[!is.na(df$population) & df$population == population, ]
  if (!is.null(dataset_id)) df <- df[df$dataset_id == dataset_id, ]
  rownames(df) <- NULL

  if (verbose) {
    message(sprintf("lineager: %d exclusion(s) retrieved", nrow(df)))
  }
  df
}

.empty_excl_frame <- function() {
  data.frame(excl_id = character(0), op_id = character(0),
             dataset_id = character(0), lid = character(0),
             usubjid = character(0), reason = character(0),
             reason_code = character(0), population = character(0),
             excluded_at = character(0), stringsAsFactors = FALSE)
}


#' Generate a subject disposition summary
#'
#' Produces a CONSORT-style subject disposition table from all [lg_filter()]
#' exclusions in the session. Each row represents a distinct exclusion reason,
#' showing cumulative subject counts at each stage.
#'
#' @param by Character. How to group: `"reason"` (default) groups by the
#'   exclusion reason text, `"population"` groups by population flag,
#'   `"dataset"` groups by dataset ID.
#'
#' @return A `data.frame` with columns: `group`, `n_excluded`, and a
#'   `cumulative_n` column showing remaining subjects at each stage.
#'
#' @examples
#' lg_start()
#' adsl <- lg_tag(
#'   data.frame(USUBJID = c("01","02","03","04","05"),
#'              RANDFL  = c("Y","N","Y","Y","N"),
#'              SAFFL   = c("Y","N","Y","Y","N")),
#'   dataset_id = "ADSL"
#' )
#' lg_filter(adsl, RANDFL == "Y",
#'           reason = "Not randomised (RANDFL != 'Y')",
#'           reason_code = "NOT_RANDOMISED", population = "RANDFL")
#'
#' lg_disposition()
#'
#' @seealso [lg_exclusions()], [lg_trace()]
#' @export
lg_disposition <- function(by = c("reason", "population", "dataset")) {
  .assert_active()
  by <- match.arg(by)

  excl <- lg_exclusions(verbose = FALSE)

  if (nrow(excl) == 0L) {
    message("lineager: no exclusions to summarise")
    return(data.frame(group = character(0), n_excluded = integer(0),
                      stringsAsFactors = FALSE))
  }

  group_col <- switch(by,
    reason     = "reason",
    population = "population",
    dataset    = "dataset_id"
  )

  counts <- as.data.frame(table(excl[[group_col]], dnn = "group"),
                           stringsAsFactors = FALSE)
  names(counts)[2L] <- "n_excluded"
  counts <- counts[order(-counts$n_excluded), ]
  rownames(counts) <- NULL

  counts
}


#' Retrieve the operation log as a data frame
#'
#' @param verbose Logical. Print count summary. Default `FALSE`.
#' @return A `data.frame` of all recorded operations.
#' @export
lg_operations <- function(verbose = FALSE) {
  .assert_active()

  if (length(.lg$operations) == 0L) {
    return(data.frame(op_id = character(0), op_type = character(0),
                      dataset_id = character(0), description = character(0),
                      rows_in = integer(0), rows_out = integer(0),
                      stringsAsFactors = FALSE))
  }

  rows <- lapply(.lg$operations, function(op) {
    data.frame(
      op_id       = op$op_id,
      op_type     = op$op_type,
      dataset_id  = op$dataset_id %||% NA_character_,
      description = op$description %||% NA_character_,
      rows_in     = op$rows_in    %||% NA_integer_,
      rows_out    = op$rows_out   %||% NA_integer_,
      timestamp   = op$timestamp  %||% NA_character_,
      stringsAsFactors = FALSE
    )
  })
  df <- do.call(rbind, rows)
  rownames(df) <- NULL

  if (verbose) message(sprintf("lineager: %d operation(s) in log", nrow(df)))
  df
}
