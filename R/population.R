# population.R
# lg_population(): document a population flag derivation (SAFFL, ITTFL, etc.)
# lg_spec():       document an SDTM-to-ADaM variable mapping


#' Document and apply a population flag
#'
#' Population flags (SAFFL, ITTFL, PPROTFL, and custom flags) are first-class
#' objects in `lineager`. Every flag must carry its inclusion criteria,
#' exclusion criteria, and plain-English definition : the information needed
#' to reconstruct the Reviewer's Guide population section automatically.
#'
#' The flag variable must already exist in `data`. `lg_population()` documents
#' it; it does not compute it. Compute the flag first with [lg_derive()], then
#' call `lg_population()` to register its definition.
#'
#' @param data An `lg_df` containing the flag variable.
#' @param flag_var Character. The flag variable name (e.g. `"SAFFL"`).
#' @param label Character. Human label (e.g. `"Safety Analysis Flag"`).
#' @param definition Character. Plain-English definition for regulatory
#'   reviewers (e.g. `"All randomised subjects who received at least one dose
#'   of study medication"`).
#' @param incl_criteria Character vector of inclusion criteria as R expressions
#'   or plain English. At least one required.
#' @param excl_criteria Character vector of explicit exclusion criteria.
#'   `NULL` if there are none beyond failing inclusion.
#' @param included_value The value of `flag_var` that denotes inclusion.
#'   Defaults to `"Y"` (the CDISC convention), but `lineager` is
#'   general-purpose : if your flag is a logical column, pass
#'   `included_value = TRUE`; for any other custom coding, pass the actual
#'   included-value directly. Using the wrong value here silently produces
#'   incorrect included/excluded counts (e.g. a logical `TRUE`/`FALSE` flag
#'   compared against `"Y"` will count every row as excluded).
#'
#' @return `data`, invisibly (for pipe use).
#'
#' @examples
#' lg_start()
#' adsl <- lg_tag(
#'   data.frame(
#'     USUBJID = c("01", "02", "03"),
#'     RANDFL = c("Y", "N", "Y"), EXOCCUR = c("Y", "N", "Y"),
#'     SAFFL = c("Y", "N", "Y")
#'   ),
#'   dataset_id = "ADSL"
#' )
#'
#' lg_population(
#'   adsl,
#'   flag_var = "SAFFL",
#'   label = "Safety Analysis Flag",
#'   definition = "All randomised subjects who received at least one dose",
#'   incl_criteria = c("RANDFL == 'Y'", "EXOCCUR == 'Y'"),
#'   excl_criteria = "No study drug administered (EXOCCUR != 'Y')"
#' )
#'
#' @seealso [lg_filter()], [lg_disposition()], [lg_report()]
#' @export
lg_population <- function(data, flag_var, label, definition,
                          incl_criteria, excl_criteria = NULL,
                          included_value = "Y") {
  .assert_active()
  .assert_tagged(data)

  if (!flag_var %in% names(data)) {
    stop(sprintf(
      "Flag variable '%s' not found in dataset '%s'.\n",
      flag_var, attr(data, "lg_dataset_id") %||% "unknown"
    ), "  Derive the flag with lg_derive() first, then call lg_population().")
  }

  if (flag_var %in% names(.lg$populations)) {
    warning(sprintf(
      "lineager: population '%s' already registered. Overwriting prior registration.",
      flag_var
    ))
  }

  flag_vals <- data[[flag_var]]
  n_included <- sum(flag_vals == included_value, na.rm = TRUE)
  n_excluded <- sum(flag_vals != included_value | is.na(flag_vals), na.rm = TRUE)

  pop <- structure(
    list(
      flag_var = flag_var,
      label = label,
      definition = definition,
      incl_criteria = incl_criteria,
      excl_criteria = excl_criteria,
      included_value = included_value,
      dataset_id = attr(data, "lg_dataset_id") %||% "unknown",
      n_included = n_included,
      n_excluded = n_excluded,
      n_total = nrow(data),
      registered_at = .utc_now()
    ),
    class = "lg_population"
  )

  .lg$populations[[flag_var]] <- pop

  message(sprintf(
    "lineager: population '%s' (%s) \u2014 %d included, %d excluded",
    flag_var, label, n_included, n_excluded
  ))
  invisible(data)
}


#' @export
print.lg_population <- function(x, ...) {
  cat(sprintf(
    "<lg_population> %s \u2014 %s\n",
    x$flag_var, x$label
  ))
  cat(sprintf("  Definition : %s\n", x$definition))
  cat(sprintf("  N included : %d\n", x$n_included))
  cat(sprintf("  N excluded : %d\n", x$n_excluded))
  cat(sprintf(
    "  Inclusion  : %s\n",
    paste(x$incl_criteria, collapse = "; ")
  ))
  if (!is.null(x$excl_criteria)) {
    cat(sprintf(
      "  Exclusion  : %s\n",
      paste(x$excl_criteria, collapse = "; ")
    ))
  }
  invisible(x)
}


#' Document an SDTM-to-ADaM variable derivation
#'
#' Records a structured derivation specification linking an ADaM analysis
#' variable back to its SDTM source. These specs are the basis for the
#' variable derivation section of the CDISC Reviewer's Guide, auto-generated
#' by [lg_report()].
#'
#' @param adam_dataset Character. ADaM dataset name (e.g. `"ADLB"`).
#' @param adam_var Character. ADaM variable name (e.g. `"AVAL"`).
#' @param label Character. Variable label.
#' @param source_domain Character. Source SDTM domain (e.g. `"LB"`).
#' @param source_var Character. Source SDTM variable (e.g. `"LBSTRESN"`).
#' @param derivation Character. Plain-English description of how the ADaM
#'   variable is derived from the source.
#' @param conditions Character vector or `NULL`. Conditions under which this
#'   derivation applies. `NULL` means it applies unconditionally.
#'
#' @return Invisibly `NULL`.
#'
#' @examples
#' lg_start()
#'
#' lg_spec(
#'   adam_dataset = "ADLB",
#'   adam_var = "AVAL",
#'   label = "Analysis Value",
#'   source_domain = "LB",
#'   source_var = "LBSTRESN",
#'   derivation = "LBSTRESN; numeric conversion of LBORRES where LBSTRESN is missing",
#'   conditions = "LBSTAT != 'NOT DONE'"
#' )
#'
#' @seealso [lg_derive()], [lg_report()]
#' @export
lg_spec <- function(adam_dataset, adam_var, label,
                    source_domain, source_var,
                    derivation, conditions = NULL) {
  .assert_active()

  key <- paste0(adam_dataset, ".", adam_var)

  if (key %in% names(.lg$var_specs)) {
    warning(sprintf(
      "lineager: variable spec '%s' already registered. Overwriting prior registration.",
      key
    ))
  }

  spec <- structure(
    list(
      adam_dataset  = adam_dataset,
      adam_var      = adam_var,
      label         = label,
      source_domain = source_domain,
      source_var    = source_var,
      derivation    = derivation,
      conditions    = conditions,
      registered_at = .utc_now()
    ),
    class = "lg_var_spec"
  )

  .lg$var_specs[[key]] <- spec
  invisible(NULL)
}
