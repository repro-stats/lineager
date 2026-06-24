# lineager.R
# Package core: store, session management, and shared internals.
#
# Design philosophy:
#   - Subject-first: every concept is anchored to USUBJID, not operations
#   - CDISC-aware: ADaM/SDTM domain names, population flags, variable specs
#     are first-class objects, not strings
#   - Mandatory reason: lg_filter() requires documented exclusion reasons
#   - No redundancy with dtrackr: lineager tracks WHERE each subject went
#     and WHY; dtrackr tracks WHAT happened to the dataframe
#   - Minimal API: one function per concept, no convenience wrappers
#   - Regulatory output: lg_report() produces CDISC Reviewer's Guide content


# --------------------------------------------------------------------------- #
#  Package-level store                                                         #
# --------------------------------------------------------------------------- #

# Single in-memory store per R session.
# Reset with lg_start(); retrieved by all lg_* functions implicitly.
.lg <- new.env(parent = emptyenv())
.lg_reset <- function() {
  .lg$active       <- FALSE
  .lg$study_id     <- NULL
  .lg$analysis_id  <- NULL
  .lg$datasets     <- list()   # named list of lg_dataset metadata
  .lg$operations   <- list()   # ordered list of lg_operation
  .lg$exclusions   <- list()   # flat list of lg_exclusion
  .lg$populations  <- list()   # named list of lg_population (by flag_var)
  .lg$var_specs    <- list()   # list of lg_var_spec
  .lg$op_counter   <- 0L
}
.lg_reset()


# --------------------------------------------------------------------------- #
#  lg_start / lg_end                                                           #
# --------------------------------------------------------------------------- #

#' Start a lineager provenance session
#'
#' Initialises the session store. Call once at the top of your analysis script,
#' before any [lg_tag()], [lg_filter()], or [lg_derive()] calls. Resets any
#' prior session state.
#'
#' @param study_id Character or `NULL`. Optional study identifier included in
#'   reports.
#' @param analysis_id Character or `NULL`. Optional analysis identifier.
#'
#' @return Invisibly `NULL`.
#'
#' @examples
#' lg_start(study_id = "TRIAL-001", analysis_id = "primary-efficacy")
#'
#' @seealso [lg_end()], [lg_tag()], [lg_report()]
#' @export
lg_start <- function(study_id = NULL, analysis_id = NULL) {
  .lg_reset()
  .lg$active      <- TRUE
  .lg$study_id    <- study_id
  .lg$analysis_id <- analysis_id
  message(sprintf(
    "lineager: session started%s%s",
    if (!is.null(study_id))    sprintf(" [study: %s]",    study_id)    else "",
    if (!is.null(analysis_id)) sprintf(" [analysis: %s]", analysis_id) else ""
  ))
  invisible(NULL)
}


#' End a lineager provenance session
#'
#' Prints a session summary and marks the session inactive. The store is
#' preserved in memory and remains queryable via [lg_trace()],
#' [lg_exclusions()], and [lg_report()] until [lg_start()] is called again.
#'
#' @return Invisibly `NULL`.
#'
#' @examples
#' lg_start()
#' lg_end()
#'
#' @seealso [lg_start()]
#' @export
lg_end <- function() {
  .assert_active()
  n_ops  <- length(.lg$operations)
  n_excl <- length(.lg$exclusions)
  n_pop  <- length(.lg$populations)
  n_spec <- length(.lg$var_specs)
  message(sprintf(
    "lineager: session ended \u2014 %d operation(s), %d exclusion(s), %d population(s), %d var spec(s)",
    n_ops, n_excl, n_pop, n_spec
  ))
  .lg$active <- FALSE
  invisible(NULL)
}


# --------------------------------------------------------------------------- #
#  Internal helpers                                                            #
# --------------------------------------------------------------------------- #

#' @noRd
.assert_active <- function() {
  if (!isTRUE(.lg$active)) {
    stop(
      "No active lineager session.\n",
      "  Call lg_start() before using any lg_* function."
    )
  }
}

#' @noRd
.assert_tagged <- function(data, arg = "data") {
  if (!inherits(data, "lg_df")) {
    stop(sprintf(
      "`%s` must be a lineager-tagged data frame (created by lg_tag()).", arg
    ))
  }
}

#' @noRd
.assert_reason <- function(reason, arg = "reason") {
  if (missing(reason) || !is.character(reason) || !nzchar(trimws(reason))) {
    stop(sprintf(
      "A `%s` is required. Every exclusion must document why subjects were removed.\n",
      arg
    ))
  }
}

#' @noRd
.next_op_id <- function() {
  .lg$op_counter <- .lg$op_counter + 1L
  sprintf("op_%04d", .lg$op_counter)
}

#' @noRd
.utc_now <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
}

#' @noRd
.get_call_context <- function(n = 3L) {
  # Walk up the call stack to find the user's script line
  sc <- sys.calls()
  if (length(sc) >= n) {
    call_str <- tryCatch(deparse(sc[[max(1L, length(sc) - n + 1L)]][[1L]]),
                         error = function(e) NA_character_)
    return(call_str)
  }
  NA_character_
}

#' @noRd
.lid_col <- ".__lid__"

#' @noRd
.register_operation <- function(op) {
  .lg$operations <- c(.lg$operations, list(op))
}

#' @noRd
.register_exclusions <- function(excl_list) {
  .lg$exclusions <- c(.lg$exclusions, excl_list)
}

#' Pipe operator
#' @importFrom magrittr %>%
#' @export
magrittr::`%>%`

#' @noRd
`%||%` <- function(x, y) if (is.null(x)) y else x
