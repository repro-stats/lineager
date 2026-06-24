# test-session.R — lg_start(), lg_end()

test_that("lg_start() marks session active", {
  new_session()
  expect_true(lg_env()$active)
})

test_that("lg_start() sets study_id and analysis_id", {
  lg_start(study_id = "STUDY-99", analysis_id = "secondary")
  env <- lg_env()
  expect_equal(env$study_id,    "STUDY-99")
  expect_equal(env$analysis_id, "secondary")
})

test_that("lg_start() accepts NULL identifiers", {
  lg_start()
  expect_null(lg_env()$study_id)
  expect_null(lg_env()$analysis_id)
})

test_that("lg_start() resets datasets from prior session", {
  new_session(); adsl_tagged()
  expect_length(lg_env()$datasets, 1L)
  lg_start()
  expect_length(lg_env()$datasets, 0L)
})

test_that("lg_start() resets exclusions from prior session", {
  new_session()
  lg_filter(adsl_tagged(), RANDFL == "Y", reason = "Not randomised")
  expect_gt(length(lg_env()$exclusions), 0L)
  lg_start()
  expect_length(lg_env()$exclusions, 0L)
})

test_that("lg_start() resets operations from prior session", {
  new_session()
  lg_derive(adsl_tagged(), X = 1L, description = "Test")
  expect_gt(length(lg_env()$operations), 0L)
  lg_start()
  expect_length(lg_env()$operations, 0L)
})

test_that("lg_start() resets populations and var_specs", {
  new_session()
  lg_population(adsl_tagged(), "SAFFL", "Safety", "Def", "SAFFL == 'Y'")
  lg_spec("ADSL", "X", "X", "DM", "X", "Derivation")
  expect_gt(length(lg_env()$populations), 0L)
  expect_gt(length(lg_env()$var_specs),   0L)

  lg_start()
  expect_length(lg_env()$populations, 0L)
  expect_length(lg_env()$var_specs,   0L)
})

test_that("lg_start() resets op_counter to zero", {
  new_session()
  adsl <- adsl_tagged()
  lg_derive(adsl, X = 1L, description = "D1")
  lg_derive(adsl, Y = 2L, description = "D2")
  expect_equal(lg_env()$op_counter, 2L)
  lg_start()
  expect_equal(lg_env()$op_counter, 0L)
})

test_that("lg_end() marks session inactive and messages summary", {
  new_session()
  expect_message(lg_end(), "session ended")
  expect_false(lg_env()$active)
})

test_that("lg_end() errors when no session is active", {
  new_session(); lg_end()
  expect_error(lg_end(), "lg_start")
  new_session()  # restore
})

test_that("lg_* functions error when no session active", {
  new_session(); lg_end()
  expect_error(lg_tag(adsl_raw(), "ADSL"), "lg_start")
  expect_error(lg_exclusions(),            "lg_start")
  expect_error(lg_report(output = NULL),   "lg_start")
  new_session()  # restore
})