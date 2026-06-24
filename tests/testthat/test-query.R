# test-query.R — lg_trace(), lg_exclusions(), lg_disposition(), lg_operations()

# ── lg_exclusions() ──────────────────────────────────────────────────────────

test_that("lg_exclusions() returns empty data frame when no exclusions", {
  new_session()
  df <- lg_exclusions(verbose = FALSE)
  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 0L)
  expect_true("usubjid" %in% names(df))
  expect_true("reason"  %in% names(df))
})

test_that("lg_exclusions() returns all exclusions as data frame", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised", population = "RANDFL")
  df <- lg_exclusions(verbose = FALSE)
  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), sum(adsl_raw()$RANDFL != "Y"))
})

test_that("lg_exclusions() has correct columns", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")
  df <- lg_exclusions(verbose = FALSE)
  expected <- c("excl_id", "op_id", "dataset_id", "lid",
                "usubjid", "reason", "reason_code", "population", "excluded_at")
  expect_true(all(expected %in% names(df)))
})

test_that("lg_exclusions() filters by population", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "R1", population = "RANDFL")
  lg_filter(adsl, SAFFL  == "Y", reason = "R2", population = "SAFFL")

  rand <- lg_exclusions(population = "RANDFL", verbose = FALSE)
  safe <- lg_exclusions(population = "SAFFL",  verbose = FALSE)
  expect_true(all(rand$population == "RANDFL"))
  expect_true(all(safe$population == "SAFFL"))
})

test_that("lg_exclusions() filters by dataset_id", {
  new_session()
  adsl <- adsl_tagged()
  adlb <- lg_tag(data.frame(USUBJID = adsl_raw()$USUBJID,
                             LBTEST = "ALT", LBORRES = "5",
                             LBSTAT = c("","NOT DONE","","",""),
                             stringsAsFactors = FALSE),
                 dataset_id = "ADLB")

  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")
  lg_filter(adlb, LBSTAT != "NOT DONE", reason = "Missing result")

  adsl_excl <- lg_exclusions(dataset_id = "ADSL", verbose = FALSE)
  adlb_excl <- lg_exclusions(dataset_id = "ADLB", verbose = FALSE)
  expect_true(all(adsl_excl$dataset_id == "ADSL"))
  expect_true(all(adlb_excl$dataset_id == "ADLB"))
})

# ── lg_disposition() ─────────────────────────────────────────────────────────

test_that("lg_disposition() returns empty data frame with no exclusions", {
  new_session()
  df <- lg_disposition()
  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 0L)
})

test_that("lg_disposition(by='reason') groups by exclusion reason", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised (RANDFL != 'Y')",
            population = "RANDFL")

  disp <- lg_disposition(by = "reason")
  expect_true("group"      %in% names(disp))
  expect_true("n_excluded" %in% names(disp))
  expect_true(any(grepl("Not randomised", disp$group)))
})

test_that("lg_disposition(by='population') groups by population flag", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "R1", population = "RANDFL")
  lg_filter(adsl, SAFFL  == "Y", reason = "R2", population = "SAFFL")

  disp <- lg_disposition(by = "population")
  expect_true(all(c("RANDFL", "SAFFL") %in% disp$group))
})

test_that("lg_disposition(by='dataset') groups by dataset", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")

  disp <- lg_disposition(by = "dataset")
  expect_true("ADSL" %in% disp$group)
})

test_that("lg_disposition() n_excluded sums to total exclusions", {
  new_session()
  adsl    <- adsl_tagged()
  raw     <- adsl_raw()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")

  disp    <- lg_disposition(by = "reason")
  n_total_expected <- sum(raw$RANDFL != "Y")
  expect_equal(sum(disp$n_excluded), n_total_expected)
})

# ── lg_operations() ──────────────────────────────────────────────────────────

test_that("lg_operations() returns empty data frame when no ops", {
  new_session()
  ops <- lg_operations(verbose = FALSE)
  expect_s3_class(ops, "data.frame")
  expect_equal(nrow(ops), 0L)
})

test_that("lg_operations() returns all ops with correct types", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")
  lg_derive(adsl, X = 1L, description = "Add X")

  x <- lg_tag(data.frame(USUBJID = "01-001", A = 1L, stringsAsFactors = FALSE),
               dataset_id = "X2")
  y <- lg_tag(data.frame(USUBJID = "01-001", B = 2L, stringsAsFactors = FALSE),
               dataset_id = "Y2")
  lg_join(x, y, by = "USUBJID")

  ops <- lg_operations(verbose = FALSE)
  expect_equal(nrow(ops), 3L)
  expect_true("FILTER" %in% ops$op_type)
  expect_true("DERIVE" %in% ops$op_type)
  expect_true(any(grepl("JOIN", ops$op_type)))
})

test_that("lg_operations() op_id values are unique and sequential", {
  new_session()
  adsl <- adsl_tagged()
  lg_derive(adsl, X = 1L, description = "D1")
  lg_derive(adsl, Y = 2L, description = "D2")
  lg_derive(adsl, Z = 3L, description = "D3")

  ops <- lg_operations(verbose = FALSE)
  expect_equal(length(unique(ops$op_id)), 3L)
  expect_equal(ops$op_id, c("op_0001", "op_0002", "op_0003"))
})

# ── lg_trace() ───────────────────────────────────────────────────────────────

test_that("lg_trace() finds subject in tagged dataset", {
  new_session()
  adsl_tagged()
  result <- lg_trace("01-001", verbose = FALSE)
  expect_equal(result$usubjid, "01-001")
  expect_true("ADSL" %in% result$datasets)
})

test_that("lg_trace() reports exclusions for excluded subjects", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised",
            population = "RANDFL")

  # 01-002 has RANDFL = "N"
  result <- lg_trace("01-002", verbose = FALSE)
  expect_gt(nrow(result$exclusions), 0L)
  expect_true(any(grepl("Not randomised", result$exclusions$reason)))
})

test_that("lg_trace() shows empty exclusions for included subjects", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")

  # 01-001 has RANDFL = "Y"
  result <- lg_trace("01-001", verbose = FALSE)
  expect_equal(nrow(result$exclusions), 0L)
})

test_that("lg_trace() returns all registered populations", {
  new_session()
  adsl <- adsl_tagged()
  lg_population(adsl, "SAFFL",  "Safety",      "Def", "SAFFL == 'Y'")
  lg_population(adsl, "RANDFL", "Randomised",  "Def", "RANDFL == 'Y'")

  result <- lg_trace("01-001", verbose = FALSE)
  expect_true("SAFFL"  %in% names(result$populations))
  expect_true("RANDFL" %in% names(result$populations))
})

test_that("lg_trace() returns subject not in any dataset gracefully", {
  new_session()
  adsl_tagged()
  result <- lg_trace("99-999", verbose = FALSE)
  expect_equal(result$usubjid, "99-999")
  expect_length(result$datasets, 0L)
})

test_that("lg_trace() errors on non-character or multiple values", {
  new_session()
  adsl_tagged()
  expect_error(lg_trace(42L))
  expect_error(lg_trace(c("01-001", "01-002")))
})

test_that("lg_trace() verbose=TRUE prints without error", {
  new_session()
  adsl_tagged()
  expect_output(lg_trace("01-001", verbose = TRUE))
})

test_that("lg_trace() shows operations from datasets containing the subject", {
  new_session()
  adsl <- adsl_tagged()
  lg_derive(adsl, X = 1L, description = "Add X to ADSL")

  result <- lg_trace("01-001", verbose = FALSE)
  expect_gt(nrow(result$operations), 0L)
  expect_true(any(grepl("ADSL", result$operations$dataset_id)))
})

# ── Additional coverage tests ─────────────────────────────────────────────────

test_that("lg_trace(verbose=TRUE) prints formatted output", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised", population = "RANDFL")
  lg_population(adsl, "SAFFL", "Safety", "Def", "SAFFL == 'Y'")

  # verbose=TRUE hits .print_trace() with datasets, operations, exclusions, populations
  expect_output(lg_trace("01-002", verbose = TRUE))
})

test_that("lg_trace(verbose=TRUE) prints 'not found' for missing subject", {
  new_session()
  adsl_tagged()
  expect_output(lg_trace("NOTEXIST", verbose = TRUE), regexp = "not found|NOTEXIST")
})

test_that("lg_trace() shows operations from dataset containing subject", {
  new_session()
  adsl <- adsl_tagged()
  lg_derive(adsl, X = 1L, description = "Add X")
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")

  result <- lg_trace("01-001", verbose = FALSE)
  expect_gt(nrow(result$operations), 0L)
})

test_that("lg_trace() shows exclusions section in verbose output", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised", population = "RANDFL")

  # 01-002 is excluded — verbose output should show exclusion block
  out <- capture.output(lg_trace("01-002", verbose = TRUE))
  expect_true(any(grepl("Exclusion|excluded|Not randomised", out, ignore.case = TRUE)))
})

test_that("lg_trace() shows populations section in verbose output", {
  new_session()
  adsl <- adsl_tagged()
  lg_population(adsl, "SAFFL", "Safety Analysis Flag", "Def", "SAFFL == 'Y'")

  out <- capture.output(lg_trace("01-001", verbose = TRUE))
  expect_true(any(grepl("SAFFL|population|Safety", out, ignore.case = TRUE)))
})

test_that("lg_exclusions(verbose=TRUE) messages the count", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")

  expect_message(lg_exclusions(verbose = TRUE), "exclusion")
})

test_that("lg_exclusions(verbose=TRUE) messages when empty", {
  new_session()
  adsl_tagged()
  expect_message(lg_exclusions(verbose = TRUE), "no exclusions")
})

test_that("lg_operations(verbose=TRUE) messages the operation count", {
  new_session()
  adsl <- adsl_tagged()
  lg_derive(adsl, X = 1L, description = "Test")

  expect_message(lg_operations(verbose = TRUE), "operation")
})

test_that("lg_operations() returns empty data frame with correct columns when no ops", {
  new_session()
  adsl_tagged()
  ops <- lg_operations(verbose = FALSE)
  expect_equal(nrow(ops), 0L)
  expect_true("op_type" %in% names(ops))
})

test_that("lg_disposition() returns empty data frame when no exclusions", {
  new_session()
  adsl_tagged()
  df <- lg_disposition()
  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 0L)
})