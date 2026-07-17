# test-derive.R — lg_derive(), lg_join()

# ── lg_derive() ──────────────────────────────────────────────────────────────

test_that("lg_derive() rejects missing or blank description", {
  new_session()
  adsl <- adsl_tagged()
  expect_error(lg_derive(adsl, X = 1L), "description")
  expect_error(lg_derive(adsl, X = 1L, description = ""), "description")
  expect_error(lg_derive(adsl, X = 1L, description = "  "), "description")
})

test_that("lg_derive() errors on untagged data", {
  new_session()
  expect_error(lg_derive(adsl_raw(), X = 1L, description = "D"), "lg_tag")
})

test_that("lg_derive() adds derived column to the dataset", {
  new_session()
  adsl <- adsl_tagged()
  result <- lg_derive(adsl,
    AGE_GRP = ifelse(AGE >= 35L, ">=35", "<35"),
    description = "Age group from AGE"
  )
  expect_true("AGE_GRP" %in% names(result))
  expect_equal(result$AGE_GRP, ifelse(adsl_raw()$AGE >= 35L, ">=35", "<35"))
})

test_that("lg_derive() preserves lineage_id column and values", {
  new_session()
  adsl <- adsl_tagged()
  lids_before <- adsl[["lineage_id"]]
  result <- lg_derive(adsl, X = 1L, description = "Constant")
  expect_equal(result[["lineage_id"]], lids_before)
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
  expect_equal(ops$op_type[[1L]], "DERIVE")
  expect_equal(ops$description[[1L]], "Add constant column")
})

test_that("lg_derive() can derive multiple variables in one call", {
  new_session()
  adsl <- adsl_tagged()
  result <- lg_derive(adsl,
    RANDFL2 = ifelse(RANDFL == "Y", 1L, 0L),
    SAFFL2 = ifelse(SAFFL == "Y", 1L, 0L),
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
  expect_error(lg_join(x, y, by = "USUBJID"), "lg_tag")
})

test_that("lg_join() left join preserves all rows of x", {
  new_session()
  x <- lg_tag(data.frame(
    USUBJID = c("01", "02", "03"), A = 1:3,
    stringsAsFactors = FALSE
  ), dataset_id = "X")
  y <- lg_tag(data.frame(
    USUBJID = c("01", "02"), B = c(10L, 20L),
    stringsAsFactors = FALSE
  ), dataset_id = "Y")

  result <- lg_join(x, y, by = "USUBJID", type = "left")
  expect_equal(nrow(result), 3L)
  expect_true(is.na(result$B[[3L]]))
})

test_that("lg_join() inner join keeps only matching rows", {
  new_session()
  x <- lg_tag(data.frame(
    USUBJID = c("01", "02", "03"), A = 1:3,
    stringsAsFactors = FALSE
  ), dataset_id = "X")
  y <- lg_tag(data.frame(
    USUBJID = c("01", "02"), B = c(10L, 20L),
    stringsAsFactors = FALSE
  ), dataset_id = "Y")

  result <- lg_join(x, y, by = "USUBJID", type = "inner",
                     description = "Subject 03 has no matching Y record")
  expect_equal(nrow(result), 2L)
})

test_that("lg_join() inner/right join errors without description when rows would drop", {
  new_session()
  x <- lg_tag(data.frame(
    USUBJID = c("01", "02", "03"), A = 1:3,
    stringsAsFactors = FALSE
  ), dataset_id = "X")
  y <- lg_tag(data.frame(
    USUBJID = c("01", "02"), B = c(10L, 20L),
    stringsAsFactors = FALSE
  ), dataset_id = "Y")

  expect_error(
    lg_join(x, y, by = "USUBJID", type = "inner"),
    "drops"
  )
})

test_that("lg_join() inner join registers dropped x rows as documented exclusions", {
  new_session()
  x <- lg_tag(data.frame(
    USUBJID = c("01", "02", "03"), A = 1:3,
    stringsAsFactors = FALSE
  ), dataset_id = "X")
  y <- lg_tag(data.frame(
    USUBJID = c("01", "02"), B = c(10L, 20L),
    stringsAsFactors = FALSE
  ), dataset_id = "Y")

  lg_join(x, y, by = "USUBJID", type = "inner",
          description = "Subject 03 has no matching Y record")

  excl <- lg_exclusions(verbose = FALSE)
  expect_equal(nrow(excl), 1L)
  expect_equal(excl$usubjid[[1L]], "03")
  expect_equal(excl$reason[[1L]], "Subject 03 has no matching Y record")
})

test_that("lg_join() adds lineage_id_y column for bilateral tracing", {
  new_session()
  x <- lg_tag(data.frame(USUBJID = "01", A = 1L, stringsAsFactors = FALSE),
    dataset_id = "X"
  )
  y <- lg_tag(data.frame(USUBJID = "01", B = 2L, stringsAsFactors = FALSE),
    dataset_id = "Y"
  )

  result <- lg_join(x, y, by = "USUBJID")
  expect_true("lineage_id_y" %in% names(result))
  expect_true(!is.na(result[["lineage_id_y"]][[1L]]))
})

test_that("lg_join() preserves lineage_id from x", {
  new_session()
  x <- lg_tag(data.frame(
    USUBJID = c("01", "02"), A = 1:2,
    stringsAsFactors = FALSE
  ), dataset_id = "X")
  y <- lg_tag(data.frame(
    USUBJID = c("01", "02"), B = c(10L, 20L),
    stringsAsFactors = FALSE
  ), dataset_id = "Y")

  lids_x <- x[["lineage_id"]]
  result <- lg_join(x, y, by = "USUBJID")
  expect_equal(result[["lineage_id"]], lids_x)
})

test_that("lg_join() preserves lg_df class", {
  new_session()
  x <- lg_tag(data.frame(USUBJID = "01", A = 1L, stringsAsFactors = FALSE),
    dataset_id = "X"
  )
  y <- lg_tag(data.frame(USUBJID = "01", B = 2L, stringsAsFactors = FALSE),
    dataset_id = "Y"
  )
  expect_s3_class(lg_join(x, y, by = "USUBJID"), "lg_df")
})

test_that("lg_join() records a JOIN operation in the store", {
  new_session()
  x <- lg_tag(data.frame(USUBJID = "01", A = 1L, stringsAsFactors = FALSE),
    dataset_id = "X"
  )
  y <- lg_tag(data.frame(USUBJID = "01", B = 2L, stringsAsFactors = FALSE),
    dataset_id = "Y"
  )
  lg_join(x, y, by = "USUBJID", description = "Merge Y onto X")

  ops <- lg_operations(verbose = FALSE)
  expect_equal(nrow(ops), 1L)
  expect_true(grepl("JOIN", ops$op_type[[1L]]))
  expect_equal(ops$description[[1L]], "Merge Y onto X")
})

test_that("lg_join() description defaults when NULL", {
  new_session()
  x <- lg_tag(data.frame(USUBJID = "01", A = 1L, stringsAsFactors = FALSE),
    dataset_id = "X"
  )
  y <- lg_tag(data.frame(USUBJID = "01", B = 2L, stringsAsFactors = FALSE),
    dataset_id = "Y"
  )
  lg_join(x, y, by = "USUBJID")

  ops <- lg_operations(verbose = FALSE)
  expect_true(grepl("join", ops$description[[1L]], ignore.case = TRUE))
})

test_that("lg_join() chained joins use a distinct y-tracing column, not a collision", {
  # Covers the fallback-naming branch: when x already carries a
  # "lineage_id_y" column from an earlier join in the chain, the second
  # join must not silently overwrite it.
  new_session()
  x  <- lg_tag(data.frame(USUBJID = c("01", "02"), A = 1:2, stringsAsFactors = FALSE),
               dataset_id = "X")
  y1 <- lg_tag(data.frame(USUBJID = c("01", "02"), B = c(10L, 20L), stringsAsFactors = FALSE),
               dataset_id = "Y1")
  y2 <- lg_tag(data.frame(USUBJID = c("01", "02"), C = c(100L, 200L), stringsAsFactors = FALSE),
               dataset_id = "Y2")

  step1 <- lg_join(x, y1, by = "USUBJID", description = "add Y1")
  expect_true("lineage_id_y" %in% names(step1))

  step2 <- lg_join(step1, y2, by = "USUBJID", description = "add Y2")
  y_cols <- grep("^lineage_id_y", names(step2), value = TRUE)

  expect_equal(length(y_cols), 2L)
  expect_true("lineage_id_y" %in% y_cols)                 # first join's name preserved
  expect_true(any(grepl("^lineage_id_y__op_", y_cols)))   # second join got a distinct name
})
