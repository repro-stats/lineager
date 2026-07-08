# Traceable ADaM derivation: every exclusion documented

## Overview

Every ADaM derivation involves exclusions — screen failures, protocol
deviations, missing baselines, assessment windows. In most trials these
are documented in aggregate: “47 subjects were excluded from the
per-protocol population.” But regulators increasingly ask for more:
which rows? Why? And can you trace any subject through the complete
derivation pipeline?

`lineager` answers these questions at the row level. Every row in every
dataset carries a lineage ID (`.__lid__`) that survives filters, joins,
and derivations. Every
[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
call requires a documented reason, and the session automatically
accumulates an exclusion registry as the pipeline runs — no manual
disposition tracking needed.

This article builds an ADEFF dataset for a Phase III atopic dermatitis
trial — starting from raw ADSL and ADLB, deriving baseline and change
from baseline, tracking every exclusion, and producing a CDISC
Reviewer’s Guide-aligned provenance report.

------------------------------------------------------------------------

## Setup

``` r

library(lineager)
library(dplyr)
```

    #> 
    #> Attaching package: 'dplyr'

    #> The following objects are masked from 'package:stats':
    #> 
    #>     filter, lag

    #> The following objects are masked from 'package:base':
    #> 
    #>     intersect, setdiff, setequal, union

------------------------------------------------------------------------

## Simulate source datasets

We simulate CDISC ADaM-structured ADSL (subject-level) and ADLB (lab/
assessment) datasets for a Phase III trial of dupilumab in
moderate-to-severe atopic dermatitis. 320 randomised subjects, primary
endpoint EASI score.

``` r

n_total <- 320L

# ── ADSL ──────────────────────────────────────────────────────────────────
adsl_raw <- data.frame(
  STUDYID  = "DERM-DUP-301",
  USUBJID  = sprintf("DUP301-%04d", seq_len(n_total)),
  TRT01P   = rep(c("Dupilumab 300mg Q2W", "Placebo Q2W"), each = n_total / 2),
  AGE      = round(rnorm(n_total, mean = 36, sd = 14)),
  SEX      = sample(c("M", "F"), n_total, replace = TRUE),
  ITTFL    = ifelse(runif(n_total) < 0.97, "Y", "N"),
  SAFFL    = ifelse(runif(n_total) < 0.98, "Y", "N"),
  PPROTFL  = ifelse(runif(n_total) < 0.91, "Y", "N"),
  EASISCAT = sample(c("MODERATE", "SEVERE"), n_total, replace = TRUE, prob = c(0.55, 0.45)),
  stringsAsFactors = FALSE
)

# ── ADLB: EASI scores at baseline and Week 16 ──────────────────────────────
adlb_raw <- expand.grid(
  USUBJID = adsl_raw$USUBJID,
  AVISITN = c(0L, 16L),
  stringsAsFactors = FALSE
) |>
  merge(adsl_raw[, c("USUBJID", "TRT01P", "EASISCAT")], by = "USUBJID") |>
  arrange(USUBJID, AVISITN)

set.seed(2026)
adlb_raw$AVAL <- mapply(function(trt, vis, scat) {
  base_mean <- if (scat == "SEVERE") 45 else 30
  if (vis == 0L) return(round(pmax(0, rnorm(1, base_mean, 8)), 1))
  reduction <- if (trt == "Dupilumab 300mg Q2W") 0.55 else 0.12
  round(pmax(0, base_mean * (1 - reduction) + rnorm(1, 0, 5)), 1)
}, adlb_raw$TRT01P, adlb_raw$AVISITN, adlb_raw$EASISCAT)

# Missingness at Week 16 (~6%)
post_bl <- adlb_raw$AVISITN > 0
miss_idx <- which(post_bl)[sample(sum(post_bl), round(sum(post_bl) * 0.06))]
adlb_raw$AVAL[miss_idx] <- NA_real_

adlb_raw$PARAMCD <- "EASI"

cat(sprintf(
  "ADSL: %d subjects | ADLB: %d records\n", nrow(adsl_raw), nrow(adlb_raw)
))
```

    #> ADSL: 320 subjects | ADLB: 640 records

------------------------------------------------------------------------

## Start the lineager session

[`lg_start()`](https://reprostats.org/lineager/reference/lg_start.md)
initialises the session store. All `lg_*` functions write to this store
automatically.

``` r

lg_start(study_id = "DERM-DUP-301", analysis_id = "ADEFF-primary-efficacy")
```

    #> lineager: session started [study: DERM-DUP-301] [analysis: ADEFF-primary-efficacy]

------------------------------------------------------------------------

## Tag source datasets

[`lg_tag()`](https://reprostats.org/lineager/reference/lg_tag.md)
assigns a unique lineage ID (`.__lid__`) to every row. The `USUBJID` is
embedded automatically when present, making IDs human-readable.

``` r

adsl <- lg_tag(adsl_raw, dataset_id = "ADSL", domain = "DM", label = "Subject-Level")
```

    #> lineager: tagged 'ADSL' — 320 rows, 9 cols

``` r

adlb <- lg_tag(adlb_raw, dataset_id = "ADLB", domain = "LB", label = "Laboratory/Efficacy")
```

    #> lineager: tagged 'ADLB' — 640 rows, 6 cols

``` r

head(adsl[, c(".__lid__", "USUBJID", "TRT01P", "ITTFL")], 4L)
```

    #> <lg_df> 'ADSL' (domain: DM)  [4 × 4]
    #>       USUBJID              TRT01P ITTFL
    #> 1 DUP301-0001 Dupilumab 300mg Q2W     Y
    #> 2 DUP301-0002 Dupilumab 300mg Q2W     Y
    #> 3 DUP301-0003 Dupilumab 300mg Q2W     Y
    #> 4 DUP301-0004 Dupilumab 300mg Q2W     Y

------------------------------------------------------------------------

## Build the ADEFF derivation pipeline

### Step 1: Document and apply the safety population

[`lg_population()`](https://reprostats.org/lineager/reference/lg_population.md)
registers the population flag definition — inclusion criteria, exclusion
criteria, and a plain-English description — directly linking to the flag
already present in the data.

``` r

lg_population(
  adsl,
  flag_var      = "SAFFL",
  label         = "Safety Analysis Flag",
  definition    = "All randomised subjects who received at least one dose of study treatment",
  incl_criteria = c("Randomised", "Received >= 1 dose of study treatment"),
  excl_criteria = "No study drug administered"
)
```

    #> lineager: population 'SAFFL' (Safety Analysis Flag) — 314 included, 6 excluded

``` r

adsl_saf <- lg_filter(
  adsl, SAFFL == "Y",
  reason     = "Restrict to safety analysis set (SAFFL = Y) per SAP Section 4.1",
  population = "SAFFL"
)
```

    #> lineager: [ADSL] filter 'Restrict to safety analysis set (SAFFL = Y) per SAP Section 4.1' — 320 in, 314 out, 6 excluded

### Step 2: ITT population

``` r

adsl_itt <- lg_filter(
  adsl_saf, ITTFL == "Y",
  reason     = "Restrict to ITT population (ITTFL = Y) per SAP Section 4.2",
  population = "ITTFL"
)
```

    #> lineager: [ADSL] filter 'Restrict to ITT population (ITTFL = Y) per SAP Section 4.2' — 314 in, 304 out, 10 excluded

``` r

cat(sprintf("After ITT filter: %d subjects\n", nrow(adsl_itt)))
```

    #> After ITT filter: 304 subjects

### Step 3: Join EASI assessments to ADSL covariates

``` r

adeff <- lg_join(
  adlb, adsl_itt[, c("USUBJID", "TRT01P", "EASISCAT")],
  by          = "USUBJID",
  type        = "inner",
  description = "Join ADLB EASI assessments to ITT-restricted ADSL covariates"
)
```

    #> lineager: [ADLB + ADSL] inner join — 608 rows out

``` r

cat(sprintf("After join: %d records\n", nrow(adeff)))
```

    #> After join: 608 records

### Step 4: Derive baseline and change from baseline

``` r

adeff <- adeff |>
  group_by(USUBJID) |>
  mutate(BASE = AVAL[AVISITN == 0L][1L]) |>
  ungroup()

# Re-tag after the dplyr grouping pipeline to keep lg_df class intact
# Drop any existing .__lid__ before re-tagging to avoid duplicate columns
adeff_df <- as.data.frame(adeff)
adeff_df <- adeff_df[, !names(adeff_df) %in% ".__lid__"]
adeff <- lg_tag(adeff_df, dataset_id = "ADEFF", domain = "ADLB",
                label = "Efficacy Analysis Dataset")
```

    #> lineager: tagged 'ADEFF' — 608 rows, 9 cols

``` r

n_miss_base <- sum(is.na(adeff$BASE[adeff$AVISITN == 0L]))

adeff <- lg_filter(
  adeff, !is.na(BASE),
  reason = "Exclude records with missing baseline EASI score per SAP Section 5.1",
  population = "ITTFL"
)
```

    #> lineager: [ADEFF] filter 'Exclude records with missing baseline EASI score per SAP Section 5.1' — 608 in, 608 out, 0 excluded

``` r

adeff <- lg_derive(
  adeff,
  CHG  = AVAL - BASE,
  PCHG = (AVAL - BASE) / BASE * 100,
  description = "Derive change from baseline (CHG) and percent change (PCHG) per CDISC ADaM IG Section 3.2.7"
)
```

    #> lineager: [ADEFF] derive — Derive change from baseline (CHG) and percent change (PCHG) per CDISC ADaM IG Section 3.2.7

### Step 5: Restrict to Week 16, non-missing

``` r

adeff_w16 <- lg_filter(
  adeff, AVISITN == 16L, !is.na(AVAL),
  reason     = "Restrict to Week 16 primary timepoint with non-missing EASI assessment",
  population = "ITTFL"
)
```

    #> lineager: [ADEFF] filter 'Restrict to Week 16 primary timepoint with non-missing EASI assessment' — 608 in, 285 out, 323 excluded

``` r

cat(sprintf("Week 16 primary analysis records: %d\n", nrow(adeff_w16)))
```

    #> Week 16 primary analysis records: 285

### Step 6: Derive EASI-75 responder flag

``` r

adeff_final <- lg_derive(
  adeff_w16,
  EASI75FL = ifelse(PCHG <= -75, "Y", "N"),
  description = "Derive EASI-75 responder flag: Y if percent change <= -75% per SAP Section 5.3"
)
```

    #> lineager: [ADEFF] derive — Derive EASI-75 responder flag: Y if percent change <= -75% per SAP Section 5.3

------------------------------------------------------------------------

## Document the SDTM-to-ADaM derivation

[`lg_spec()`](https://reprostats.org/lineager/reference/lg_spec.md)
records the structured derivation specification linking the ADaM
variable back to its SDTM source — the basis for the CDISC Reviewer’s
Guide derivation section.

``` r

lg_spec(
  adam_dataset  = "ADEFF",
  adam_var      = "CHG",
  label         = "Change from Baseline EASI Score",
  source_domain = "LB",
  source_var    = "LBSTRESN",
  derivation    = "AVAL - BASE, where BASE is the Visit 0 (Baseline) EASI assessment",
  conditions    = "Subjects with non-missing baseline EASI score"
)
```

------------------------------------------------------------------------

## Subject disposition

[`lg_disposition()`](https://reprostats.org/lineager/reference/lg_disposition.md)
summarises the exclusion registry automatically — no manual group
definitions needed. Every
[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
call above contributed its exclusions to this summary.

``` r

lg_disposition(by = "reason")
```

    #>                                                                    group
    #> 1 Restrict to Week 16 primary timepoint with non-missing EASI assessment
    #> 2             Restrict to ITT population (ITTFL = Y) per SAP Section 4.2
    #> 3        Restrict to safety analysis set (SAFFL = Y) per SAP Section 4.1
    #>   n_excluded
    #> 1        323
    #> 2         10
    #> 3          6

------------------------------------------------------------------------

## Exclusion registry

``` r

excl <- lg_exclusions()
```

    #> lineager: 339 exclusion(s) retrieved

``` r

excl |>
  select(dataset_id, reason, population) |>
  knitr::kable(caption = "ADEFF derivation exclusion registry — DERM-DUP-301")
```

| dataset_id | reason | population |
|:---|:---|:---|
| ADSL | Restrict to safety analysis set (SAFFL = Y) per SAP Section 4.1 | SAFFL |
| ADSL | Restrict to safety analysis set (SAFFL = Y) per SAP Section 4.1 | SAFFL |
| ADSL | Restrict to safety analysis set (SAFFL = Y) per SAP Section 4.1 | SAFFL |
| ADSL | Restrict to safety analysis set (SAFFL = Y) per SAP Section 4.1 | SAFFL |
| ADSL | Restrict to safety analysis set (SAFFL = Y) per SAP Section 4.1 | SAFFL |
| ADSL | Restrict to safety analysis set (SAFFL = Y) per SAP Section 4.1 | SAFFL |
| ADSL | Restrict to ITT population (ITTFL = Y) per SAP Section 4.2 | ITTFL |
| ADSL | Restrict to ITT population (ITTFL = Y) per SAP Section 4.2 | ITTFL |
| ADSL | Restrict to ITT population (ITTFL = Y) per SAP Section 4.2 | ITTFL |
| ADSL | Restrict to ITT population (ITTFL = Y) per SAP Section 4.2 | ITTFL |
| ADSL | Restrict to ITT population (ITTFL = Y) per SAP Section 4.2 | ITTFL |
| ADSL | Restrict to ITT population (ITTFL = Y) per SAP Section 4.2 | ITTFL |
| ADSL | Restrict to ITT population (ITTFL = Y) per SAP Section 4.2 | ITTFL |
| ADSL | Restrict to ITT population (ITTFL = Y) per SAP Section 4.2 | ITTFL |
| ADSL | Restrict to ITT population (ITTFL = Y) per SAP Section 4.2 | ITTFL |
| ADSL | Restrict to ITT population (ITTFL = Y) per SAP Section 4.2 | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |
| ADEFF | Restrict to Week 16 primary timepoint with non-missing EASI assessment | ITTFL |

ADEFF derivation exclusion registry — DERM-DUP-301 {.table}

------------------------------------------------------------------------

## Trace a subject through the pipeline

[`lg_trace()`](https://reprostats.org/lineager/reference/lg_trace.md)
returns the complete provenance history for any subject — every dataset
it appeared in, every operation that touched it, and any exclusion
records.

``` r

example_subj <- adeff_final$USUBJID[1L]
lg_trace(example_subj)
```

    #> 
    #> ── lineager trace: USUBJID 'DUP301-0001' ──
    #> 
    #>   Appears in: ADSL, ADLB, ADEFF
    #> 
    #>   Operations:
    #>     [FILTER] ADSL: Restrict to safety analysis set (SAFFL = Y) per SAP Section  (320→314)
    #>     [FILTER] ADSL: Restrict to ITT population (ITTFL = Y) per SAP Section 4.2 (314→304)
    #>     [JOIN_INNER] ADLB: Join ADLB EASI assessments to ITT-restricted ADSL covariates (640→608)
    #>     [FILTER] ADEFF: Exclude records with missing baseline EASI score per SAP Sec (608→608)
    #>     [DERIVE] ADEFF: Derive change from baseline (CHG) and percent change (PCHG)  (608→608)
    #>     [FILTER] ADEFF: Restrict to Week 16 primary timepoint with non-missing EASI  (608→285)
    #>     [DERIVE] ADEFF: Derive EASI-75 responder flag: Y if percent change <= -75% p (285→285)
    #> 
    #>   Exclusions (1):
    #>     ✗ [ADEFF] Restrict to Week 16 primary timepoint with non-missing EASI assessment [pop: ITTFL]
    #> 
    #>   Registered populations:
    #>     SAFFL: Safety Analysis Flag

``` r

excluded_subj <- adsl_raw$USUBJID[adsl_raw$ITTFL == "N"][1L]
if (!is.na(excluded_subj)) lg_trace(excluded_subj)
```

    #> 
    #> ── lineager trace: USUBJID 'DUP301-0021' ──
    #> 
    #>   Appears in: ADSL, ADLB
    #> 
    #>   Operations:
    #>     [FILTER] ADSL: Restrict to safety analysis set (SAFFL = Y) per SAP Section  (320→314)
    #>     [FILTER] ADSL: Restrict to ITT population (ITTFL = Y) per SAP Section 4.2 (314→304)
    #>     [JOIN_INNER] ADLB: Join ADLB EASI assessments to ITT-restricted ADSL covariates (640→608)
    #> 
    #>   Exclusions (1):
    #>     ✗ [ADSL] Restrict to ITT population (ITTFL = Y) per SAP Section 4.2 [pop: ITTFL]
    #> 
    #>   Registered populations:
    #>     SAFFL: Safety Analysis Flag

------------------------------------------------------------------------

## Pipeline lineage graph

``` r

lin <- lg_lineage()
print(lin)
```

    #> <lg_lineage>  3 source dataset(s), 7 operation(s), 3 exclusion branch(es)
    #> Use lg_plot(lin) to render. DOT source:
    #> 
    #> digraph lineage {
    #>   rankdir = TB;
    #>   graph [fontname="Helvetica", splines=ortho, nodesep=0.4, ranksep=0.6];
    #>   node  [fontname="Helvetica", fontsize=10, margin="0.15,0.08"];
    #>   edge  [fontname="Helvetica", fontsize=9, color="#6b6f80"];
    #> 
    #>   SRC_ADSL [label="ADSL\nn = 320", shape=box, style="filled,rounded", fillcolor="#e8effe", color="#1a56db", fontcolor="#0f1117"];
    #>   SRC_ADLB [label="ADLB\nn = 640", shape=box, style="filled,rounded", fillcolor="#e8effe", color="#1a56db", fontcolor="#0f1117"];
    #>   SRC_ADEFF [label="ADEFF\nn = 608", shape=box, style="filled,rounded", fillcolor="#e8effe", color="#1a56db", fontcolor="#0f1117"];
    #>   OP_op_0001 [label="FILTER\nRestrict to safety analysis set ...\n−6 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
    #>   DS_ADSL_op_0001 [label="ADSL\nn = 314", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
    #>   EXCL_op_0001 [label="excluded\nn = 6", shape=plaintext, fontcolor="#dc2626", fontsize=9];
    #>   OP_op_0002 [label="FILTER\nRestrict to ITT population (ITTF...\n−10 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
    #>   DS_ADSL_op_0002 [label="ADSL\nn = 304", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
    #>   EXCL_op_0002 [label="excluded\nn = 10", shape=plaintext, fontcolor="#dc2626", fontsize=9];
    #>   OP_op_0003 [label="JOIN (inner)\nby: USUBJID", shape=diamond, style="filled,rounded", fillcolor="#e8f5e9", color="#0e7a4f", fontcolor="#0f1117"];
    #>   DS_ADLB_op_0003 [label="ADLB\nn = 608", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
    #>   OP_op_0004 [label="FILTER\nExclude records with missing bas...\n−0 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
    #>   DS_ADEFF_op_0004 [label="ADEFF\nn = 608", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
    #>   OP_op_0005 [label="DERIVE\nDerive change from baseline (CHG...", shape=ellipse, style="filled,rounded", fillcolor="#fff8e1", color="#f59e0b", fontcolor="#0f1117"];
    #>   DS_ADEFF_op_0005 [label="ADEFF\nn = 608", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
    #>   OP_op_0006 [label="FILTER\nRestrict to Week 16 primary time...\n−323 rows", shape=ellipse, style="filled,rounded", fillcolor="#fff3e0", color="#ea8c00", fontcolor="#0f1117"];
    #>   DS_ADEFF_op_0006 [label="ADEFF\nn = 285", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
    #>   EXCL_op_0006 [label="excluded\nn = 323", shape=plaintext, fontcolor="#dc2626", fontsize=9];
    #>   OP_op_0007 [label="DERIVE\nDerive EASI-75 responder flag: Y...", shape=ellipse, style="filled,rounded", fillcolor="#fff8e1", color="#f59e0b", fontcolor="#0f1117"];
    #>   DS_ADEFF_op_0007 [label="ADEFF\nn = 285", shape=box, style="filled,rounded", fillcolor="#ffffff", color="#6b6f80", fontcolor="#0f1117"];
    #> 
    #>   SRC_ADSL -> OP_op_0001 [label=" n=320 "];
    #>   OP_op_0001 -> DS_ADSL_op_0001;
    #>   OP_op_0001 -> EXCL_op_0001;
    #>   DS_ADSL_op_0001 -> OP_op_0002 [label=" n=314 "];
    #>   OP_op_0002 -> DS_ADSL_op_0002;
    #>   OP_op_0002 -> EXCL_op_0002;
    #>   SRC_ADLB -> OP_op_0003 [label=" x "];
    #>   DS_ADSL_op_0002 -> OP_op_0003 [label=" y "];
    #>   OP_op_0003 -> DS_ADLB_op_0003;
    #>   SRC_ADEFF -> OP_op_0004 [label=" n=608 "];
    #>   OP_op_0004 -> DS_ADEFF_op_0004;
    #>   DS_ADEFF_op_0004 -> OP_op_0005;
    #>   OP_op_0005 -> DS_ADEFF_op_0005;
    #>   DS_ADEFF_op_0005 -> OP_op_0006 [label=" n=608 "];
    #>   OP_op_0006 -> DS_ADEFF_op_0006;
    #>   OP_op_0006 -> EXCL_op_0006;
    #>   DS_ADEFF_op_0006 -> OP_op_0007;
    #>   OP_op_0007 -> DS_ADEFF_op_0007;
    #> }

------------------------------------------------------------------------

## Provenance report

``` r

lg_report(
  output   = "outputs/DERM-DUP-301_ADEFF_provenance_v1.html",
  title    = "ADEFF Provenance Report — DERM-DUP-301",
  study_id = "DERM-DUP-301",
  sponsor  = "Example Pharma Ltd",
  author   = "J. Smith, Biostatistician"
)
```

------------------------------------------------------------------------

## End the session

``` r

lg_end()
```

    #> lineager: session ended — 7 operation(s), 339 exclusion(s), 1 population(s), 1 var spec(s)

------------------------------------------------------------------------

## What the provenance record proves

Every row in the final ADEFF dataset carries a lineage ID tracing it to
its source record in ADSL or ADLB. The exclusion registry — built
automatically from each
[`lg_filter()`](https://reprostats.org/lineager/reference/lg_filter.md)
call, not maintained separately — documents which subjects were excluded
at each step, why, and which population the exclusion relates to.
[`lg_disposition()`](https://reprostats.org/lineager/reference/lg_disposition.md)
produces the population flow table directly from these records, so the
numbers can never drift out of sync with the derivation code that
produced them.

------------------------------------------------------------------------

## Session information

``` r

sessionInfo()
```

    #> R version 4.6.1 (2026-06-24)
    #> Platform: x86_64-pc-linux-gnu
    #> Running under: Ubuntu 24.04.4 LTS
    #> 
    #> Matrix products: default
    #> BLAS:   /usr/lib/x86_64-linux-gnu/openblas-pthread/libblas.so.3 
    #> LAPACK: /usr/lib/x86_64-linux-gnu/openblas-pthread/libopenblasp-r0.3.26.so;  LAPACK version 3.12.0
    #> 
    #> locale:
    #>  [1] LC_CTYPE=C.UTF-8       LC_NUMERIC=C           LC_TIME=C.UTF-8       
    #>  [4] LC_COLLATE=C.UTF-8     LC_MONETARY=C.UTF-8    LC_MESSAGES=C.UTF-8   
    #>  [7] LC_PAPER=C.UTF-8       LC_NAME=C              LC_ADDRESS=C          
    #> [10] LC_TELEPHONE=C         LC_MEASUREMENT=C.UTF-8 LC_IDENTIFICATION=C   
    #> 
    #> time zone: UTC
    #> tzcode source: system (glibc)
    #> 
    #> attached base packages:
    #> [1] stats     graphics  grDevices utils     datasets  methods   base     
    #> 
    #> other attached packages:
    #> [1] dplyr_1.2.1    lineager_0.1.0
    #> 
    #> loaded via a namespace (and not attached):
    #>  [1] vctrs_0.7.3       cli_3.6.6         knitr_1.51        rlang_1.3.0      
    #>  [5] xfun_0.59         otel_0.2.0        generics_0.1.4    textshaping_1.0.5
    #>  [9] jsonlite_2.0.0    glue_1.8.1        htmltools_0.5.9   ragg_1.5.2       
    #> [13] sass_0.4.10       rmarkdown_2.31    tibble_3.3.1      evaluate_1.0.5   
    #> [17] jquerylib_0.1.4   fastmap_1.2.0     yaml_2.3.12       lifecycle_1.0.5  
    #> [21] compiler_4.6.1    fs_2.1.0          pkgconfig_2.0.3   htmlwidgets_1.6.4
    #> [25] systemfonts_1.3.2 digest_0.6.39     R6_2.6.1          tidyselect_1.2.1 
    #> [29] pillar_1.11.1     magrittr_2.0.5    bslib_0.11.0      withr_3.0.3      
    #> [33] tools_4.6.1       pkgdown_2.2.1     cachem_1.1.0      desc_1.4.3
