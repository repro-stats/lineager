# test-report.R — lg_report()

# Helper: build a populated session for report testing
populated_session <- function() {
  new_session()
  adsl <- adsl_tagged()

  adsl <- lg_derive(adsl,
    RANDFL_N = ifelse(RANDFL == "Y", 1L, 0L),
    description = "Numeric version of RANDFL for analysis"
  )

  lg_filter(adsl, RANDFL == "Y",
    reason      = "Not randomised (RANDFL != 'Y')",
    reason_code = "NOT_RAND",
    population  = "RANDFL"
  )

  lg_population(adsl, "SAFFL",
    label = "Safety Analysis Flag",
    definition = "All randomised subjects who received at least one dose",
    incl_criteria = c("RANDFL == 'Y'", "EXOCCUR == 'Y'"),
    excl_criteria = "No study drug administered"
  )

  lg_spec(
    adam_dataset = "ADSL",
    adam_var = "RANDFL",
    label = "Randomised Flag",
    source_domain = "DM",
    source_var = "ARMCD",
    derivation = "Y if ARMCD != 'SCRNFAIL', N otherwise"
  )
}

test_that("lg_report() returns HTML string when output is NULL", {
  populated_session()
  html <- lg_report(output = NULL)
  expect_true(is.character(html))
  expect_true(nchar(html) > 1000L)
})

test_that("lg_report() output is valid HTML", {
  populated_session()
  html <- lg_report(output = NULL, title = "Test Report")
  expect_true(grepl("<!DOCTYPE html>", html, fixed = TRUE))
  expect_true(grepl("<html", html))
  expect_true(grepl("</html>", html))
  expect_true(grepl("<body", html))
  expect_true(grepl("</body>", html))
})

test_that("lg_report() includes the custom title", {
  populated_session()
  html <- lg_report(output = NULL, title = "My Custom Provenance Report")
  expect_true(grepl("My Custom Provenance Report", html))
})

test_that("lg_report() includes study_id and sponsor", {
  populated_session()
  html <- lg_report(
    output = NULL, title = "T",
    study_id = "TRIAL-999",
    sponsor = "Acme Pharma"
  )
  expect_true(grepl("TRIAL-999", html))
  expect_true(grepl("Acme Pharma", html))
})

test_that("lg_report() includes dataset inventory section", {
  populated_session()
  html <- lg_report(output = NULL)
  expect_true(grepl("Dataset Inventory", html))
  expect_true(grepl("ADSL", html))
})

test_that("lg_report() includes subject disposition when exclusions exist", {
  populated_session()
  html <- lg_report(output = NULL)
  expect_true(grepl("Disposition", html, ignore.case = TRUE))
  expect_true(grepl("Not randomised", html))
})

test_that("lg_report() includes population flag section", {
  populated_session()
  html <- lg_report(output = NULL)
  expect_true(grepl("Population Flag", html))
  expect_true(grepl("SAFFL", html))
  expect_true(grepl("Safety Analysis Flag", html))
})

test_that("lg_report() includes variable derivation section", {
  populated_session()
  html <- lg_report(output = NULL)
  expect_true(grepl("Variable Derivation", html, ignore.case = TRUE))
  expect_true(grepl("ADSL", html))
  expect_true(grepl("RANDFL", html))
})

test_that("lg_report() includes operation log section", {
  populated_session()
  html <- lg_report(output = NULL)
  expect_true(grepl("Operation Log", html))
  expect_true(grepl("FILTER", html))
  expect_true(grepl("DERIVE", html))
})

test_that("lg_report() includes exclusion listing section", {
  populated_session()
  html <- lg_report(output = NULL)
  expect_true(grepl("Exclusion Listing", html, ignore.case = TRUE))
})

test_that("lg_report() writes file when output path given", {
  populated_session()
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp))

  lg_report(output = tmp, title = "Test")
  expect_true(file.exists(tmp))
  expect_gt(file.info(tmp)$size, 0L)

  content <- readLines(tmp, warn = FALSE)
  expect_true(any(grepl("<!DOCTYPE html>", content)))
})

test_that("lg_report() returns file path invisibly when writing to disk", {
  populated_session()
  tmp <- tempfile(fileext = ".html")
  on.exit(unlink(tmp))

  result <- lg_report(output = tmp, title = "Test")
  expect_equal(result, tmp)
})

test_that("lg_report() creates output directory if it doesn't exist", {
  populated_session()
  dir <- tempfile()
  tmp <- file.path(dir, "report.html")
  on.exit(unlink(dir, recursive = TRUE))

  expect_false(dir.exists(dir))
  lg_report(output = tmp, title = "Test")
  expect_true(file.exists(tmp))
})

test_that("lg_report() only accepts html format", {
  populated_session()
  expect_error(lg_report(format = "pdf", output = NULL), "html")
  expect_error(lg_report(format = "docx", output = NULL), "html")
  expect_error(lg_report(format = "xml", output = NULL), "html")
})

test_that("lg_report() works with a minimal session (nothing but a tag)", {
  new_session()
  adsl_tagged()
  html <- lg_report(output = NULL, title = "Minimal")
  expect_true(grepl("<!DOCTYPE html>", html, fixed = TRUE))
  expect_true(grepl("ADSL", html))
})
