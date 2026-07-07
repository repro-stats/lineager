# test-tag.R — lg_tag(), lg_df S3 class

test_that("lg_tag() returns an lg_df", {
  new_session()
  expect_s3_class(adsl_tagged(), "lg_df")
})

test_that("lg_tag() adds .__lid__ as first column", {
  new_session()
  tagged <- adsl_tagged()
  expect_equal(names(tagged)[[1L]], ".__lid__")
})

test_that("lg_tag() .__lid__ embeds USUBJID for CDISC datasets", {
  new_session()
  tagged <- adsl_tagged(3L)
  lids <- tagged[[".__lid__"]]
  expect_true(all(grepl("01-001|01-002|01-003", lids)))
  expect_true(all(grepl("^ADSL_", lids)))
})

test_that("lg_tag() .__lid__ uses zero-padded seq for non-CDISC data", {
  new_session()
  df <- data.frame(x = 1:4, y = letters[1:4])
  tagged <- lg_tag(df, dataset_id = "MISC")
  lids <- tagged[[".__lid__"]]
  expect_true(all(grepl("^MISC_\\d{6}$", lids)))
})

test_that("lg_tag() .__lid__ values are unique", {
  new_session()
  tagged <- adsl_tagged()
  expect_equal(length(unique(tagged[[".__lid__"]])), nrow(tagged))
})

test_that("lg_tag() preserves all original columns", {
  new_session()
  raw <- adsl_raw()
  tagged <- lg_tag(raw, dataset_id = "ADSL")
  original_cols <- names(raw)
  expect_true(all(original_cols %in% names(tagged)))
})

test_that("lg_tag() sets dataset attributes correctly", {
  new_session()
  tagged <- lg_tag(adsl_raw(3L),
    dataset_id = "ADSL",
    domain = "DM", label = "Demographics",
    source = "dm.sas7bdat"
  )
  expect_equal(attr(tagged, "lg_dataset_id"), "ADSL")
  expect_equal(attr(tagged, "lg_domain"), "DM")
  expect_equal(attr(tagged, "lg_label"), "Demographics")
  expect_equal(attr(tagged, "lg_source"), "dm.sas7bdat")
  expect_equal(attr(tagged, "lg_row_count"), 3L)
})

test_that("lg_tag() registers dataset in session store", {
  new_session()
  lg_tag(adsl_raw(4L), dataset_id = "ADSL2", domain = "DM")
  env <- lg_env()
  expect_true("ADSL2" %in% names(env$datasets))
  ds <- env$datasets[["ADSL2"]]
  expect_equal(ds$domain, "DM")
  expect_equal(ds$n_rows, 4L)
  expect_length(ds$lids, 4L)
})

test_that("lg_tag() errors on non-data-frame input", {
  new_session()
  expect_error(lg_tag(list(a = 1), "X"), "data.frame")
  expect_error(lg_tag("a string", "X"), "data.frame")
  expect_error(lg_tag(1:10, "X"), "data.frame")
})

test_that("lg_tag() errors on blank or missing dataset_id", {
  new_session()
  expect_error(lg_tag(adsl_raw(), ""), "non-empty")
  expect_error(lg_tag(adsl_raw(), NULL), "non-empty")
})

test_that("lg_tag() warns when dataset_id already registered", {
  new_session()
  lg_tag(adsl_raw(), "ADSL")
  expect_warning(lg_tag(adsl_raw(), "ADSL"), "already registered")
})

test_that("print.lg_df shows dataset_id and dimensions", {
  new_session()
  tagged <- adsl_tagged(3L)
  out <- capture.output(print(tagged))
  expect_true(any(grepl("ADSL", out)))
  expect_true(any(grepl("3", out)))
})

test_that("[.lg_df preserves lg_df class on row subsetting", {
  new_session()
  tagged <- adsl_tagged()
  subset <- tagged[1:2, ]
  expect_s3_class(subset, "lg_df")
})
