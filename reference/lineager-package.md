# lineager: Row-Level Data Provenance and Exclusion Tracking

You build a dataset. You filter it, join it, derive new variables, and
produce an analysis. Somewhere along the way rows disappear : subjects
excluded, records removed, observations dropped. Later, someone asks:
*"Show me exactly which records were excluded, why, and what happened to
record 01-042 between the source data and this analysis."*

`lineager` makes that question answerable : programmatically, from your
existing R pipeline, with no post-hoc documentation.

It tags every row of every dataset with a unique lineage identifier that
survives filters, joins, and derivations. Every row removal must carry a
documented reason. Variable derivations are registered as structured
specifications. And at any point,
[`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md)
returns any row's complete journey across the entire pipeline : from
source to final analysis dataset.

`lineager` is general-purpose. It works for any R pipeline where
row-level provenance matters: clinical data, machine learning, financial
modelling, epidemiology, or any analytical workflow where "what was
excluded and why" is a question you need to answer. CDISC-specific
features (domain codes, population flags, SDTM-to-ADaM variable mapping,
Reviewer's Guide output) are available as optional enrichment for
pharmaceutical and clinical users.

## Workflow

**Step 1 : Start a session and tag your source data**

    lg_start(study_id = "TRIAL-001", analysis_id = "primary-efficacy")

    # CDISC datasets
    dm <- lg_tag(haven::read_sas("sdtm/dm.sas7bdat"),
                 dataset_id = "DM", domain = "DM",
                 label = "Demographics")

    # General-purpose datasets
    patients <- lg_tag(patient_df, dataset_id = "patients",
                       label = "Patient registry")

**Step 2 : Derive variables with documented descriptions**

    adsl <- lg_derive(dm,
      RANDFL = ifelse(ARMCD != "SCRNFAIL", "Y", "N"),
      description = "RANDFL: Y if subject was randomised (ARMCD != 'SCRNFAIL')"
    )

    lg_spec("ADSL", "RANDFL", "Randomised Flag",
            source_domain = "DM", source_var = "ARMCD",
            derivation    = "Y if ARMCD != 'SCRNFAIL'")

**Step 3 : Filter with mandatory exclusion reasons**

    adsl_safety <- lg_filter(
      adsl,
      SAFFL == "Y",
      reason      = "Not in safety population (SAFFL != 'Y')",
      reason_code = "NOT_SAFETY",
      population  = "SAFFL"
    )

**Step 4 : Trace any row and generate the provenance report**

    lg_trace("01-042")

    lg_report(
      output  = "outputs/provenance_report.html",
      title   = "Data Provenance Report",
      sponsor = "Example Pharma Ltd",
      author  = "Ndoh Penn, Biostatistician"
    )

## Key functions

|  |  |
|----|----|
| Function | Purpose |
| [`lg_start()`](https://reprostats.org/lineager/reference/lg_start.md) | Initialise a provenance session |
| [`lg_end()`](https://reprostats.org/lineager/reference/lg_end.md) | End the session and print a summary |
| [`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md) | Tag a dataset with row-level lineage IDs |
| [`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md) | Filter with mandatory exclusion reason |
| [`lg_derive()`](https://reprostats.org/lineager/reference/lg_derive.md) | Derive new variables with documented description |
| [`lg_join()`](https://reprostats.org/lineager/reference/lg_join.md) | Tracked join with bilateral row-ID tracing |
| [`lg_population()`](https://reprostats.org/lineager/reference/lg_population.md) | Register a population or cohort definition |
| [`lg_spec()`](https://reprostats.org/lineager/reference/lg_spec.md) | Document a source-to-analysis variable derivation |
| [`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md) | Trace a row's complete lineage journey |
| [`lg_exclusions()`](https://reprostats.org/lineager/reference/lg_exclusions.md) | Retrieve the full exclusion registry |
| [`lg_disposition()`](https://reprostats.org/lineager/reference/lg_disposition.md) | Grouped exclusion summary table |
| [`lg_operations()`](https://reprostats.org/lineager/reference/lg_operations.md) | Full pipeline operation log |
| [`lg_lineage()`](https://reprostats.org/lineager/reference/lg_lineage.md) | Build a pipeline lineage graph from session operations |
| [`lg_plot()`](https://reprostats.org/lineager/reference/lg_plot.md) | Render the lineage graph inline or export as DOT |
| [`lg_report()`](https://reprostats.org/lineager/reference/lg_report.md) | Generate a structured HTML provenance report |

## The lineage ID

Every row in every tagged dataset carries a `.__lid__` column. For
datasets with a `USUBJID` column, the ID embeds the subject identifier
for human readability:

    DM_0001_01-042    <- row 1 from DM, subject 01-042
    ADLB_0047_01-042  <- row 47 from ADLB, subject 01-042

For datasets without `USUBJID`, a zero-padded sequence is used:

    patients_000001   <- row 1 from the patients dataset

This ID persists through
[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md),
[`lg_derive()`](https://reprostats.org/lineager/reference/lg_derive.md),
and [`lg_join()`](https://reprostats.org/lineager/reference/lg_join.md),
forming the traceable thread connecting any output row back to its
origin.

## CDISC-specific features

Pharmaceutical and clinical users can additionally use:

- `domain` argument in
  [`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md) for
  CDISC domain codes (`"DM"`, `"LB"`, `"AE"`, etc.)

- [`lg_population()`](https://reprostats.org/lineager/reference/lg_population.md)
  to register SAFFL, ITTFL, PPROTFL flag definitions

- [`lg_spec()`](https://reprostats.org/lineager/reference/lg_spec.md) to
  document SDTM-to-ADaM variable derivations

- [`lg_report()`](https://reprostats.org/lineager/reference/lg_report.md)
  to generate CDISC Reviewer's Guide-aligned documentation

None of these are required for general use.

## Integration with regulog

`lineager` and `regulog` are complementary packages. Use `regulog` to
create a tamper-evident audit trail of the session (who ran what, when,
and why), and `lineager` to document the row-level data transformations
within that session. The
[`lg_report()`](https://reprostats.org/lineager/reference/lg_report.md)
output can be referenced in the `regulog` audit trail via
`log_action()`.

## See also

Useful links:

- <https://reprostats.org>

- <https://github.com/repro-stats/lineager>

- Report bugs at <https://github.com/repro-stats/lineager/issues>

## Author

**Maintainer**: Ndoh Penn <ndohpenn9@gmail.com>
([ORCID](https://orcid.org/0009-0003-9054-465X))
