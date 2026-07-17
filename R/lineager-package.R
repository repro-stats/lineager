#' lineager: Row-Level Data Provenance and Exclusion Tracking
#'
#' @description
#' You build a dataset. You filter it, join it, derive new variables, and
#' produce an analysis. Somewhere along the way rows disappear : subjects
#' excluded, records removed, observations dropped. Later, someone asks:
#' *"Show me exactly which records were excluded, why, and what happened
#' to record 01-042 between the source data and this analysis."*
#'
#' `lineager` makes that question answerable : programmatically, from your
#' existing R pipeline, with no post-hoc documentation.
#'
#' It tags every row of every dataset with a unique lineage identifier that
#' survives filters, joins, and derivations. Every row removal must carry a
#' documented reason. Variable derivations are registered as structured
#' specifications. And at any point, [lg_trace()] returns any row's complete
#' journey across the entire pipeline : from source to final analysis dataset.
#'
#' `lineager` is general-purpose. It works for any R pipeline where row-level
#' provenance matters: clinical data, machine learning, financial modelling,
#' epidemiology, or any analytical workflow where "what was excluded and why"
#' is a question you need to answer. CDISC-specific features (domain codes,
#' population flags, SDTM-to-ADaM variable mapping, Reviewer's Guide output)
#' are available as optional enrichment for pharmaceutical and clinical users.
#'
#' @section Workflow:
#'
#' **Step 1 : Start a session and tag your source data**
#'
#' ```r
#' lg_start(study_id = "TRIAL-001", analysis_id = "primary-efficacy")
#'
#' # CDISC datasets
#' dm <- lg_tag(haven::read_sas("sdtm/dm.sas7bdat"),
#'              dataset_id = "DM", domain = "DM",
#'              label = "Demographics")
#'
#' # General-purpose datasets
#' patients <- lg_tag(patient_df, dataset_id = "patients",
#'                    label = "Patient registry")
#' ```
#'
#' **Step 2 : Derive variables with documented descriptions**
#'
#' ```r
#' adsl <- lg_derive(dm,
#'   RANDFL = ifelse(ARMCD != "SCRNFAIL", "Y", "N"),
#'   description = "RANDFL: Y if subject was randomised (ARMCD != 'SCRNFAIL')"
#' )
#'
#' lg_spec("ADSL", "RANDFL", "Randomised Flag",
#'         source_domain = "DM", source_var = "ARMCD",
#'         derivation    = "Y if ARMCD != 'SCRNFAIL'")
#' ```
#'
#' **Step 3 : Filter with mandatory exclusion reasons**
#'
#' ```r
#' adsl_safety <- lg_filter(
#'   adsl,
#'   SAFFL == "Y",
#'   reason      = "Not in safety population (SAFFL != 'Y')",
#'   reason_code = "NOT_SAFETY",
#'   population  = "SAFFL"
#' )
#' ```
#'
#' **Step 4 : Trace any row and generate the provenance report**
#'
#' ```r
#' lg_trace("01-042")
#'
#' lg_report(
#'   output  = "outputs/provenance_report.html",
#'   title   = "Data Provenance Report",
#'   sponsor = "Example Pharma Ltd",
#'   author  = "J. Smith, Biostatistician"
#' )
#' ```
#'
#' @section Key functions:
#'
#' | Function | Purpose |
#' |---|---|
#' | [lineager::lg_start()] | Initialise a provenance session |
#' | [lineager::lg_end()] | End the session and print a summary |
#' | [lineager::lg_tag()] | Tag a dataset with row-level lineage IDs |
#' | [lineager::lg_filter()] | Filter with mandatory exclusion reason |
#' | [lineager::lg_derive()] | Derive new variables with documented description |
#' | [lineager::lg_join()] | Tracked join with bilateral row-ID tracing |
#' | [lineager::lg_population()] | Register a population or cohort definition |
#' | [lineager::lg_spec()] | Document a source-to-analysis variable derivation |
#' | [lineager::lg_trace()] | Trace a row's complete lineage journey |
#' | [lineager::lg_history()] | Retrieve the operation history recorded on a tagged object |
#' | [lineager::lg_exclusions()] | Retrieve the full exclusion registry |
#' | [lineager::lg_disposition()] | Grouped exclusion summary table |
#' | [lineager::lg_operations()] | Full pipeline operation log |
#' | [lineager::lg_lineage()] | Build a pipeline lineage graph from session operations |
#' | [lineager::lg_plot()] | Render the lineage graph inline or export as DOT |
#' | [lineager::lg_report()] | Generate a structured HTML provenance report |
#'
#' @section The lineage ID:
#'
#' Every row in every tagged dataset carries a `lineage_id` column. For
#' datasets with a `USUBJID` column, the ID embeds the subject identifier
#' for human readability:
#'
#' ```
#' DM_0001_01-042    <- row 1 from DM, subject 01-042
#' ADLB_0047_01-042  <- row 47 from ADLB, subject 01-042
#' ```
#'
#' For datasets without `USUBJID`, a zero-padded sequence is used:
#'
#' ```
#' patients_000001   <- row 1 from the patients dataset
#' ```
#'
#' This ID persists through [lg_filter()], [lg_derive()], and [lg_join()],
#' forming the traceable thread connecting any output row back to its origin.
#'
#' @section CDISC-specific features:
#'
#' Pharmaceutical and clinical users can additionally use:
#'
#' - `domain` argument in [lg_tag()] for CDISC domain codes
#'   (`"DM"`, `"LB"`, `"AE"`, etc.)
#' - [lg_population()] to register SAFFL, ITTFL, PPROTFL flag definitions
#' - [lg_spec()] to document SDTM-to-ADaM variable derivations
#' - [lg_report()] to generate CDISC Reviewer's Guide-aligned documentation
#'
#' None of these are required for general use.
#'
#' @section Integration with regulog:
#'
#' `lineager` and `regulog` are complementary packages. Use `regulog` to
#' create a tamper-evident audit trail of the session (who ran what, when,
#' and why), and `lineager` to document the row-level data transformations
#' within that session. The [lg_report()] output can be referenced in the
#' `regulog` audit trail via `log_action()`.
#'
#' @aliases lineager-package
"_PACKAGE"