# test-population.R — lg_population(), lg_spec()

# ── lg_population() ──────────────────────────────────────────────────────────

test_that("lg_population() registers population in session store", {
  new_session()
  adsl <- adsl_tagged()
  lg_population(adsl, "SAFFL", "Safety Analysis Flag",
                "All randomised subjects who received at least one dose",
                incl_criteria = c("RANDFL == 'Y'", "EXOCCUR == 'Y'"),
                excl_criteria = "No study drug administered")

  env <- lg_env()
  expect_true("SAFFL" %in% names(env$populations))
})

test_that("lg_population() stores label, definition, criteria", {
  new_session()
  adsl <- adsl_tagged()
  lg_population(adsl, "RANDFL", "Randomised Flag",
                "All randomised subjects",
                incl_criteria = "RANDFL == 'Y'")

  pop <- lg_env()$populations[["RANDFL"]]
  expect_equal(pop$label,      "Randomised Flag")
  expect_equal(pop$definition, "All randomised subjects")
  expect_equal(pop$incl_criteria, "RANDFL == 'Y'")
})

test_that("lg_population() counts n_included and n_excluded correctly", {
  new_session()
  raw  <- adsl_raw()
  adsl <- adsl_tagged()
  lg_population(adsl, "SAFFL", "Safety", "Safety pop", "SAFFL == 'Y'")

  pop <- lg_env()$populations[["SAFFL"]]
  expect_equal(pop$n_included, sum(raw$SAFFL == "Y"))
  expect_equal(pop$n_excluded, sum(raw$SAFFL != "Y"))
  expect_equal(pop$n_total,    nrow(raw))
})

test_that("lg_population() stores excl_criteria as NULL when not provided", {
  new_session()
  adsl <- adsl_tagged()
  lg_population(adsl, "RANDFL", "Randomised", "Def",
                incl_criteria = "RANDFL == 'Y'")

  pop <- lg_env()$populations[["RANDFL"]]
  expect_null(pop$excl_criteria)
})

test_that("lg_population() multiple criteria stored as vector", {
  new_session()
  adsl <- adsl_tagged()
  lg_population(adsl, "SAFFL", "Safety", "Def",
                incl_criteria = c("RANDFL == 'Y'", "EXOCCUR == 'Y'"),
                excl_criteria = c("No drug", "Withdrawn consent"))

  pop <- lg_env()$populations[["SAFFL"]]
  expect_length(pop$incl_criteria, 2L)
  expect_length(pop$excl_criteria, 2L)
})

test_that("lg_population() errors when flag_var not in dataset", {
  new_session()
  adsl <- adsl_tagged()
  expect_error(
    lg_population(adsl, "NONEXISTENT_FLAG", "Label", "Def", "X == 'Y'"),
    "not found"
  )
})

test_that("lg_population() errors on untagged data", {
  new_session()
  expect_error(
    lg_population(adsl_raw(), "SAFFL", "Safety", "Def", "SAFFL == 'Y'"),
    "lg_tag"
  )
})

test_that("lg_population() returns data invisibly for piping", {
  new_session()
  adsl   <- adsl_tagged()
  result <- lg_population(adsl, "SAFFL", "Safety", "Def", "SAFFL == 'Y'")
  expect_identical(result, adsl)
})

test_that("lg_population() can register multiple populations", {
  new_session()
  adsl <- adsl_tagged()
  lg_population(adsl, "RANDFL", "Randomised", "Def", "RANDFL == 'Y'")
  lg_population(adsl, "SAFFL",  "Safety",     "Def", "SAFFL == 'Y'")

  env <- lg_env()
  expect_true("RANDFL" %in% names(env$populations))
  expect_true("SAFFL"  %in% names(env$populations))
})

test_that("print.lg_population shows key fields", {
  new_session()
  adsl <- adsl_tagged()
  lg_population(adsl, "SAFFL", "Safety Analysis Flag",
                "All randomised subjects who received at least one dose",
                "SAFFL == 'Y'")

  pop <- lg_env()$populations[["SAFFL"]]
  out <- capture.output(print(pop))
  expect_true(any(grepl("SAFFL",   out)))
  expect_true(any(grepl("Safety",  out)))
})

# ── lg_spec() ────────────────────────────────────────────────────────────────

test_that("lg_spec() registers a variable spec keyed as 'dataset.var'", {
  new_session()
  lg_spec("ADLB", "AVAL", "Analysis Value", "LB", "LBSTRESN",
          "LBSTRESN; numeric LBORRES where missing")

  expect_true("ADLB.AVAL" %in% names(lg_env()$var_specs))
})

test_that("lg_spec() stores all fields correctly", {
  new_session()
  lg_spec(adam_dataset  = "ADLB",
          adam_var      = "AVAL",
          label         = "Analysis Value",
          source_domain = "LB",
          source_var    = "LBSTRESN",
          derivation    = "Numeric conversion of LBORRES; LBSTRESN preferred",
          conditions    = "LBSTAT != 'NOT DONE'")

  spec <- lg_env()$var_specs[["ADLB.AVAL"]]
  expect_equal(spec$adam_dataset,  "ADLB")
  expect_equal(spec$adam_var,      "AVAL")
  expect_equal(spec$label,         "Analysis Value")
  expect_equal(spec$source_domain, "LB")
  expect_equal(spec$source_var,    "LBSTRESN")
  expect_equal(spec$conditions,    "LBSTAT != 'NOT DONE'")
})

test_that("lg_spec() conditions defaults to NULL when not provided", {
  new_session()
  lg_spec("ADSL", "TRTSDT", "Treatment Start", "EX", "EXSTDTC",
          "First EXSTDTC per subject")
  spec <- lg_env()$var_specs[["ADSL.TRTSDT"]]
  expect_null(spec$conditions)
})

test_that("lg_spec() returns NULL invisibly", {
  new_session()
  result <- lg_spec("A", "B", "B", "C", "D", "Derivation")
  expect_null(result)
})

test_that("lg_spec() can register multiple specs", {
  new_session()
  lg_spec("ADLB", "AVAL",  "Analysis Value",    "LB", "LBSTRESN", "D1")
  lg_spec("ADLB", "AVALC", "Analysis Value (C)", "LB", "LBORRES",  "D2")
  lg_spec("ADSL", "TRTSDT","Trt Start Date",     "EX", "EXSTDTC",  "D3")

  specs <- lg_env()$var_specs
  expect_true(all(c("ADLB.AVAL", "ADLB.AVALC", "ADSL.TRTSDT") %in% names(specs)))
})

test_that("lg_spec() overwrites existing spec with same key", {
  new_session()
  lg_spec("ADLB", "AVAL", "Old Label", "LB", "LBORRES",  "Old derivation")
  lg_spec("ADLB", "AVAL", "New Label", "LB", "LBSTRESN", "New derivation")

  spec <- lg_env()$var_specs[["ADLB.AVAL"]]
  expect_equal(spec$label,      "New Label")
  expect_equal(spec$derivation, "New derivation")
})

test_that("print.lg_population shows exclusion criteria when provided", {
  new_session()
  adsl <- lg_tag(
    data.frame(USUBJID = c("01", "02", "03"), SAFFL = c("Y", "Y", "N")),
    dataset_id = "ADSL"
  )
  lg_population(adsl,
    flag_var      = "SAFFL",
    label         = "Safety Analysis Set",
    definition    = "Randomised and dosed",
    incl_criteria = "SAFFL = Y",
    excl_criteria = "SAFFL != Y"
  )
  # Retrieve the registered population and print it
  pop <- lineager:::.lg$populations[["SAFFL"]]
  out <- capture.output(print(pop))
  expect_true(any(grepl("Exclusion", out)))
})