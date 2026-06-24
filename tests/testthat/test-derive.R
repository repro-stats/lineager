# test-derive.R — lg_derive(), lg_join()

# ── lg_derive() ──────────────────────────────────────────────────────────────

test_that("lg_derive() rejects missing or blank description", {
  new_session()
  adsl <- adsl_tagged()
  expect_error(lg_derive(adsl, X = 1L),                      "description")
  expect_error(lg_derive(adsl, X = 1L, description = ""),    "description")
  expect_error(lg_derive(adsl, X = 1L, description = "  "),  "description")
})

test_that("lg_derive() errors on untagged data", {
  new_session()
  expect_error(lg_derive(adsl_raw(), X = 1L, description = "D"), "lg_tag")
})

test_that("lg_derive() adds derived column to the dataset", {
  new_session()
  adsl   <- adsl_tagged()
  result <- lg_derive(adsl, AGE_GRP = ifelse(AGE >= 35L, ">=35", "<35"),
                      description = "Age group from AGE")
  expect_true("AGE_GRP" %in% names(result))
  expect_equal(result$AGE_GRP, ifelse(adsl_raw()$AGE >= 35L, ">=35", "<35"))
})

test_that("lg_derive() preserves .__lid__ column and values", {
  new_session()
  adsl   <- adsl_tagged()
  lids_before <- adsl[[".__lid__"]]
  result <- lg_derive(adsl, X = 1L, description = "Constant")
  expect_equal(result[[".__lid__"]], lids_before)
})

test_that("lg_derive() preserves lg_df class", {
  new_session()
  result <- lg_derive(adsl_tagged(), X = 1L, description = "D")
  expect_s3_class(result, "lg_df")
})

test_that("lg_derive() records a DERIVE operation in the store", {
  new_session()
  lg_derive(adsl_tagged(), X = 1L, description = "Add constant column")

  ops <- lg_operations(verbose = FALSE)
  expect_equal(nrow(ops), 1L)
  expect_equal(ops$op_type[[1L]],     "DERIVE")
  expect_equal(ops$description[[1L]], "Add constant column")
})

test_that("lg_derive() can derive multiple variables in one call", {
  new_session()
  adsl   <- adsl_tagged()
  result <- lg_derive(adsl,
    RANDFL2 = ifelse(RANDFL == "Y", 1L, 0L),
    SAFFL2  = ifelse(SAFFL  == "Y", 1L, 0L),
    description = "Numeric versions of flag variables"
  )
  expect_true(all(c("RANDFL2", "SAFFL2") %in% names(result)))
})

test_that("lg_derive() is pipe-friendly", {
  new_session()
  result <- adsl_tagged() |>
    lg_derive(X = 1L, description = "Step 1") |>
    lg_derive(Y = X + 1L, description = "Step 2")

  ops <- lg_operations(verbose = FALSE)
  expect_equal(nrow(ops), 2L)
  expect_true(all(result$Y == 2L))
})

# ── lg_join() ────────────────────────────────────────────────────────────────

test_that("lg_join() errors on untagged x or y", {
  new_session()
  x <- adsl_tagged()
  y <- data.frame(USUBJID = "01-001", B = 1L, stringsAsFactors = FALSE)
  expect_error(lg_join(adsl_raw(), adsl_tagged(), by = "USUBJID"), "lg_tag")
  expect_error(lg_join(x, y,       by = "USUBJID"),                "lg_tag")
})

test_that("lg_join() left join preserves all rows of x", {
  new_session()
  x <- lg_tag(data.frame(USUBJID = c("01","02","03"), A = 1:3,
                          stringsAsFactors = FALSE), dataset_id = "X")
  y <- lg_tag(data.frame(USUBJID = c("01","02"),      B = c(10L, 20L),
                          stringsAsFactors = FALSE), dataset_id = "Y")

  result <- lg_join(x, y, by = "USUBJID", type = "left")
  expect_equal(nrow(result), 3L)
  expect_true(is.na(result$B[[3L]]))
})

test_that("lg_join() inner join keeps only matching rows", {
  new_session()
  x <- lg_tag(data.frame(USUBJID = c("01","02","03"), A = 1:3,
                          stringsAsFactors = FALSE), dataset_id = "X")
  y <- lg_tag(data.frame(USUBJID = c("01","02"),      B = c(10L,20L),
                          stringsAsFactors = FALSE), dataset_id = "Y")

  result <- lg_join(x, y, by = "USUBJID", type = "inner")
  expect_equal(nrow(result), 2L)
})

test_that("lg_join() adds .__lid_y__ column for bilateral tracing", {
  new_session()
  x <- lg_tag(data.frame(USUBJID = "01", A = 1L, stringsAsFactors = FALSE),
               dataset_id = "X")
  y <- lg_tag(data.frame(USUBJID = "01", B = 2L, stringsAsFactors = FALSE),
               dataset_id = "Y")

  result <- lg_join(x, y, by = "USUBJID")
  expect_true(".__lid_y__" %in% names(result))
  expect_true(!is.na(result[[".__lid_y__"]][[1L]]))
})

test_that("lg_join() preserves .__lid__ from x", {
  new_session()
  x <- lg_tag(data.frame(USUBJID = c("01","02"), A = 1:2,
                          stringsAsFactors = FALSE), dataset_id = "X")
  y <- lg_tag(data.frame(USUBJID = c("01","02"), B = c(10L,20L),
                          stringsAsFactors = FALSE), dataset_id = "Y")

  lids_x <- x[[".__lid__"]]
  result  <- lg_join(x, y, by = "USUBJID")
  expect_equal(result[[".__lid__"]], lids_x)
})

test_that("lg_join() preserves lg_df class", {
  new_session()
  x <- lg_tag(data.frame(USUBJID = "01", A = 1L, stringsAsFactors = FALSE),
               dataset_id = "X")
  y <- lg_tag(data.frame(USUBJID = "01", B = 2L, stringsAsFactors = FALSE),
               dataset_id = "Y")
  expect_s3_class(lg_join(x, y, by = "USUBJID"), "lg_df")
})

test_that("lg_join() records a JOIN operation in the store", {
  new_session()
  x <- lg_tag(data.frame(USUBJID = "01", A = 1L, stringsAsFactors = FALSE),
               dataset_id = "X")
  y <- lg_tag(data.frame(USUBJID = "01", B = 2L, stringsAsFactors = FALSE),
               dataset_id = "Y")
  lg_join(x, y, by = "USUBJID", description = "Merge Y onto X")

  ops <- lg_operations(verbose = FALSE)
  expect_equal(nrow(ops), 1L)
  expect_true(grepl("JOIN", ops$op_type[[1L]]))
  expect_equal(ops$description[[1L]], "Merge Y onto X")
})

test_that("lg_join() description defaults when NULL", {
  new_session()
  x <- lg_tag(data.frame(USUBJID = "01", A = 1L, stringsAsFactors = FALSE),
               dataset_id = "X")
  y <- lg_tag(data.frame(USUBJID = "01", B = 2L, stringsAsFactors = FALSE),
               dataset_id = "Y")
  lg_join(x, y, by = "USUBJID")

  ops <- lg_operations(verbose = FALSE)
  expect_true(grepl("join", ops$description[[1L]], ignore.case = TRUE))
})
