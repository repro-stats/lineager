# test-filter.R — lg_filter()

test_that("lg_filter() rejects blank or missing reason", {
  new_session()
  adsl <- adsl_tagged()
  expect_error(lg_filter(adsl, RANDFL == "Y"), "reason")
  expect_error(lg_filter(adsl, RANDFL == "Y", reason = ""), "reason")
  expect_error(lg_filter(adsl, RANDFL == "Y", reason = " "), "reason")
})

test_that("lg_filter() errors on untagged data", {
  new_session()
  expect_error(lg_filter(adsl_raw(), RANDFL == "Y", reason = "R"), "lg_tag")
})

test_that("lg_filter() returns only rows matching the condition", {
  new_session()
  adsl <- adsl_tagged()
  result <- lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")
  expect_true(all(result$RANDFL == "Y"))
  expect_equal(nrow(result), sum(adsl_raw()$RANDFL == "Y"))
})

test_that("lg_filter() preserves lineage_id column", {
  new_session()
  adsl <- adsl_tagged()
  result <- lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")
  expect_true("lineage_id" %in% names(result))
})

test_that("lg_filter() preserves lg_df class", {
  new_session()
  adsl <- adsl_tagged()
  result <- lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")
  expect_s3_class(result, "lg_df")
})

test_that("lg_filter() records exclusions in session store", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y",
    reason = "Not randomised",
    population = "RANDFL", reason_code = "NOT_RAND"
  )

  excl <- lg_env()$exclusions
  n_not_rand <- sum(adsl_raw()$RANDFL != "Y")
  expect_equal(length(excl), n_not_rand)
})

test_that("lg_filter() records correct USUBJID for each excluded subject", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")

  excl_df <- lg_exclusions(verbose = FALSE)
  expected_subjs <- adsl_raw()$USUBJID[adsl_raw()$RANDFL != "Y"]
  expect_setequal(excl_df$usubjid, expected_subjs)
})

test_that("lg_filter() stores reason, reason_code, population on each exclusion", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y",
    reason      = "Screen failure",
    reason_code = "SCRNFAIL",
    population  = "RANDFL"
  )

  excl <- lg_env()$exclusions
  for (e in excl) {
    expect_equal(e$reason, "Screen failure")
    expect_equal(e$reason_code, "SCRNFAIL")
    expect_equal(e$population, "RANDFL")
  }
})

test_that("lg_filter() records a FILTER operation", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")

  ops <- lg_operations(verbose = FALSE)
  expect_equal(nrow(ops), 1L)
  expect_equal(ops$op_type[[1L]], "FILTER")
  expect_equal(ops$rows_in[[1L]], nrow(adsl))
  expect_equal(ops$rows_out[[1L]], sum(adsl_raw()$RANDFL == "Y"))
})

test_that("lg_filter() with TRUE condition excludes nothing", {
  new_session()
  adsl <- adsl_tagged()
  result <- lg_filter(adsl, TRUE, reason = "No exclusion intended")
  expect_equal(nrow(result), nrow(adsl))
  expect_equal(length(lg_env()$exclusions), 0L)
})

test_that("lg_filter() with FALSE condition excludes everything", {
  new_session()
  adsl <- adsl_tagged()
  result <- lg_filter(adsl, FALSE, reason = "Exclude all")
  expect_equal(nrow(result), 0L)
  expect_equal(length(lg_env()$exclusions), nrow(adsl))
})

test_that("lg_filter() is pipe-friendly", {
  new_session()
  result <- adsl_tagged() |>
    lg_filter(RANDFL == "Y", reason = "Not randomised") |>
    lg_filter(AGE >= 32L, reason = "Under age threshold")

  ops <- lg_operations(verbose = FALSE)
  expect_equal(nrow(ops), 2L)
  expect_true(all(result$RANDFL == "Y"))
  expect_true(all(result$AGE >= 32L))
})

test_that("lg_filter() NULL reason_code defaults to NA in exclusion record", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y",
    reason = "Not randomised",
    reason_code = NULL
  )
  excl <- lg_env()$exclusions
  for (e in excl) expect_true(is.na(e$reason_code))
})
