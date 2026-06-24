#' lineager: Row-Level Data Provenance and Exclusion Tracking
#'
#' @description
#' You build a dataset. You filter it, join it, derive new variables, and
#' produce an analysis. Somewhere along the way rows disappear — subjects
#' excluded, records removed, observations dropped. Later, someone asks:
#' *"Show me exactly which records were excluded, why, and what happened
#' to record 01-042 between the source data and this analysis."*
#'
#' Without `lineager`, that answer requires manual reconstruction.
#' With `lineager`, it is a single function call.
#'
#' `lineager` tags every row of every dataset with a unique lineage
#' identifier that survives filters, joins, and derivations. Every
#' row removal must carry a documented reason. Variable derivations are
#' registered as structured specifications. And at any point,
#' [lg_trace()] returns any row's complete journey across the entire
#' pipeline — from source to final analysis dataset.
#'
#' The package is general-purpose. It works for any R pipeline where
#' row-level provenance matters: clinical data, machine learning,
#' financial modelling, epidemiology, or any analytical workflow where
#' "what was excluded and why" is a question you need to answer.
#' CDISC-specific features (domain codes, population flags, SDTM-to-ADaM
#' variable mapping, Reviewer's Guide output) are available as optional
#' enrichment for pharmaceutical and clinical users.
#'
#' @section Workflow:
#'
#' **Step 1 — Start a session and tag your source data**
#'
#' ```r
#' lg_start(study_id = "TRIAL-001", analysis_id = "primary-efficacy")
#'
#' dm <- lg_tag(read_sas("sdtm/dm.sas7bdat"),
#'              dataset_id = "DM", domain = "DM",
#'              label = "Demographics")
#'
#' # Works equally for non-CDISC data:
#' patients <- lg_tag(patient_df, dataset_id = "patients",
#'                    label = "Patient registry")
#' ```
#'
#' **Step 2 — Derive variables with documented descriptions**
#'
#' ```r
#' adsl <- lg_derive(dm,
#'   RANDFL = ifelse(ARMCD != "SCRNFAIL", "Y", "N"),
#'   description = "RANDFL: Y if subject was randomised (ARMCD != 'SCRNFAIL')"
#' )
#'
#' # lg_spec() documents the SDTM→ADaM mapping (optional, pharma use)
#' lg_spec("ADSL", "RANDFL", "Randomised Flag",
#'         source_domain = "DM", source_var = "ARMCD",
#'         derivation    = "Y if ARMCD != 'SCRNFAIL'")
#' ```
#'
#' **Step 3 — Filter with mandatory exclusion reasons**
#'
#' ```r
#' adsl_safety <- lg_filter(
#'   adsl,
#'   SAFFL == "Y",
#'   reason      = "Not in safety population (SAFFL != 'Y')",
#'   reason_code = "NOT_SAFETY",
#'   population  = "SAFFL"    # optional grouping field
#' )
#' ```
#'
#' **Step 4 — Trace any row and generate the report**
#'
#' ```r
#' lg_trace("01-042")   # complete history of this subject across the pipeline
#'
#' lg_report(
#'   output   = "outputs/provenance_report.html",
#'   title    = "Data Provenance Report",
#'   sponsor  = "Example Pharma Ltd",
#'   author   = "Ndoh Penn, Biostatistician"
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
#' | [lineager::lg_exclusions()] | Retrieve the full exclusion registry |
#' | [lineager::lg_disposition()] | Grouped exclusion summary table |
#' | [lineager::lg_operations()] | Full pipeline operation log |
#' | [lineager::lg_report()] | Generate a structured HTML provenance report |
#'
#' @section The lineage ID:
#'
#' Every row in every tagged dataset carries a `.__lid__` column. For
#' CDISC datasets with USUBJID, the ID embeds the subject identifier for
#' human readability:
#'
#' ```
#' DM_0001_01-042    <- row 1 from DM domain, subject 01-042
#' ADLB_0047_01-042  <- row 47 from ADLB, subject 01-042
#' ```
#'
#' For non-CDISC datasets, a zero-padded sequence is used:
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
#' - `domain` argument in [lg_tag()] — CDISC domain code (`"DM"`, `"LB"`, `"AE"`)
#' - [lg_population()] — registers SAFFL, ITTFL, PPROTFL definitions
#' - [lg_spec()] — documents SDTM-to-ADaM variable derivations
#' - [lg_report()] — generates CDISC Reviewer's Guide-aligned documentation
#'
#' None of these are required for general use.
#'
#' @section How it differs from dtrackr:
#'
#' `dtrackr` tracks what happened to a **dataset** — operations applied,
#' row counts at each step, CONSORT flowcharts. It is excellent for that
#' purpose.
#'
#' `lineager` tracks what happened to each **row** — where it came from,
#' which operations it passed through or was excluded by, how its derived
#' variables were computed, and why it was removed if it was. Exclusion
#' reasons are mandatory. The output targets provenance documentation
#' rather than flowcharts.
#'
#' @section Integration with regulog:
#'
#' `lineager` and `regulog` are complementary. Use `regulog` to create a
#' tamper-evident audit trail of the session (who ran what, when, and why),
#' and `lineager` to document the row-level data transformations within that
#' session. The [lg_report()] output can be referenced in the `regulog`
#' audit trail via `log_action()`.
#'
#' @aliases lineager-package
"_PACKAGE"