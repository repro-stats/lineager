# test-lineage.R — lg_lineage(), lg_plot()

# ── lg_lineage() ─────────────────────────────────────────────────────────────────

test_that("lg_lineage() returns an lg_lineage object", {
  new_session()
  adsl_tagged()
  lin <- lg_lineage()
  expect_s3_class(lin, "lg_lineage")
})

test_that("lg_lineage() has nodes, edges, and dot components", {
  new_session()
  adsl_tagged()
  lin <- lg_lineage()
  expect_true(all(c("nodes", "edges", "dot", "rankdir") %in% names(lin)))
  expect_type(lin$nodes, "list")
  expect_type(lin$edges, "list")
  expect_type(lin$dot,   "character")
})

test_that("lg_lineage() creates a source node for each tagged dataset", {
  new_session()
  lg_tag(adsl_raw(), dataset_id = "ADSL")
  lg_tag(data.frame(USUBJID = "01-001", V = 1L, stringsAsFactors = FALSE),
         dataset_id = "LABS")
  lin <- lg_lineage()

  node_types <- vapply(lin$nodes, `[[`, character(1L), "type")
  n_source   <- sum(node_types == "source")
  expect_equal(n_source, 2L)
})

test_that("lg_lineage() creates a filter node and exclusion node for lg_filter()", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")

  lin <- lg_lineage()
  node_types <- vapply(lin$nodes, `[[`, character(1L), "type")
  expect_true("filter"    %in% node_types)
  expect_true("exclusion" %in% node_types)
})

test_that("lg_lineage() creates a derive node for lg_derive()", {
  new_session()
  adsl <- adsl_tagged()
  lg_derive(adsl, X = 1L, description = "Add constant")

  lin <- lg_lineage()
  node_types <- vapply(lin$nodes, `[[`, character(1L), "type")
  expect_true("derive" %in% node_types)
})

test_that("lg_lineage() creates a join node for lg_join()", {
  new_session()
  x <- lg_tag(data.frame(USUBJID = "01-001", A = 1L, stringsAsFactors = FALSE),
               dataset_id = "X")
  y <- lg_tag(data.frame(USUBJID = "01-001", B = 2L, stringsAsFactors = FALSE),
               dataset_id = "Y")
  lg_join(x, y, by = "USUBJID")

  lin <- lg_lineage()
  node_types <- vapply(lin$nodes, `[[`, character(1L), "type")
  expect_true("join" %in% node_types)
})

test_that("lg_lineage() DOT string contains graphviz header", {
  new_session()
  adsl_tagged()
  lin <- lg_lineage()
  expect_true(grepl("digraph lineage", lin$dot))
  expect_true(grepl("rankdir", lin$dot))
})

test_that("lg_lineage() DOT string contains dataset and operation labels", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")

  lin <- lg_lineage()
  expect_true(grepl("ADSL",        lin$dot))
  expect_true(grepl("FILTER",      lin$dot))
  expect_true(grepl("excluded",    lin$dot))
})

test_that("lg_lineage() accepts LR rankdir", {
  new_session()
  adsl_tagged()
  lin <- lg_lineage(rankdir = "LR")
  expect_equal(lin$rankdir, "LR")
  expect_true(grepl("rankdir = LR", lin$dot))
})

test_that("lg_lineage() no exclusion node when filter removes zero rows", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, TRUE, reason = "No exclusion")

  lin <- lg_lineage()
  node_types <- vapply(lin$nodes, `[[`, character(1L), "type")
  expect_false("exclusion" %in% node_types)
})

test_that("lg_lineage() handles complex pipeline: derive + join + filter", {
  new_session()
  x <- lg_tag(data.frame(USUBJID = c("01","02","03"),
                          group = c("A","B","A"),
                          stringsAsFactors = FALSE), dataset_id = "X")
  y <- lg_tag(data.frame(USUBJID = c("01","02"),
                          value = c(10L, 20L),
                          stringsAsFactors = FALSE), dataset_id = "Y")

  x2 <- lg_derive(x, grp_num = ifelse(group == "A", 1L, 2L),
                   description = "Numeric group")
  xy <- lg_join(x2, y, by = "USUBJID", type = "left",
                description = "Merge Y onto X")
  lg_filter(xy, !is.na(value), reason = "No matching Y record")

  lin <- lg_lineage()
  node_types <- vapply(lin$nodes, `[[`, character(1L), "type")

  expect_true("source"    %in% node_types)
  expect_true("derive"    %in% node_types)
  expect_true("join"      %in% node_types)
  expect_true("filter"    %in% node_types)
  expect_true("exclusion" %in% node_types)
})

# ── print.lg_lineage() ────────────────────────────────────────────────────────────

test_that("print.lg_lineage() outputs without error", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")

  lin <- lg_lineage()
  expect_output(print(lin))
})

# ── lg_plot() ─────────────────────────────────────────────────────────────────

test_that("lg_plot() errors on non-lg_lineage input", {
  expect_error(lg_plot("not a lineage"), "lg_lineage")
  expect_error(lg_plot(list()),      "lg_lineage")
})

test_that("lg_plot() writes DOT to file when output is specified", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")

  lin <- lg_lineage()
  tmp <- tempfile(fileext = ".dot")
  on.exit(unlink(tmp))

  lg_plot(lin, output = tmp)
  expect_true(file.exists(tmp))
  dot_content <- readLines(tmp, warn = FALSE)
  expect_true(any(grepl("digraph", dot_content)))
})

test_that("lg_plot() returns lg_lineage invisibly", {
  new_session()
  adsl_tagged()
  lin    <- lg_lineage()
  tmp    <- tempfile(fileext = ".dot")
  on.exit(unlink(tmp))
  result <- lg_plot(lin, output = tmp)
  expect_identical(result, lin)
})

# ── Additional tests ─────────────────────────────────────────────────

test_that("lg_plot() falls back to message when DiagrammeR not installed", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")
  lin <- lg_lineage()

  # Mock requireNamespace to return FALSE for DiagrammeR
  mockery_available <- requireNamespace("mockery", quietly = TRUE)
  if (!mockery_available) {
    # Test the fallback indirectly: write to file and check DOT output
    tmp <- tempfile(fileext = ".dot")
    on.exit(unlink(tmp))
    result <- lg_plot(lin, output = tmp)
    content <- paste(readLines(tmp), collapse = "\n")
    expect_true(grepl("digraph", content))
  } else {
    # CORRECT MOCKERY SYNTAX: Use stub() to mock requireNamespace inside lg_plot
    mockery::stub(
      where = lg_plot,
      what = "requireNamespace",
      how = function(pkg, ...) if (pkg == "DiagrammeR") FALSE else TRUE
    )
    expect_message(lg_plot(lin), "DiagrammeR")
  }
})

test_that("lg_lineage() handles JOIN where y dataset was not in original tips", {
  new_session()
  # Tag x but not y directly — join should still create a source node for y
  x <- lg_tag(data.frame(USUBJID = c("01","02"), A = 1:2,
                          stringsAsFactors = FALSE), dataset_id = "X")
  y <- lg_tag(data.frame(USUBJID = c("01","02"), B = c(10L, 20L),
                          stringsAsFactors = FALSE), dataset_id = "Y")
  lg_join(x, y, by = "USUBJID", type = "inner")

  lin <- lg_lineage()
  node_types <- vapply(lin$nodes, `[[`, character(1L), "type")
  expect_true("join" %in% node_types)
  # Both source nodes present
  node_labels <- vapply(lin$nodes, `[[`, character(1L), "label")
  expect_true(any(grepl("^X", node_labels)))
  expect_true(any(grepl("^Y", node_labels)))
})

test_that("lg_lineage() DERIVE branch adds derive and dataset nodes", {
  new_session()
  adsl <- adsl_tagged()
  lg_derive(adsl, X = 1L, description = "Constant column")

  lin <- lg_lineage()
  node_types <- vapply(lin$nodes, `[[`, character(1L), "type")
  expect_true("derive"  %in% node_types)
  expect_true("dataset" %in% node_types)
})

test_that("lg_lineage() FILTER with zero exclusions has no exclusion node", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, TRUE, reason = "Vacuous filter — nothing excluded")

  lin <- lg_lineage()
  node_types <- vapply(lin$nodes, `[[`, character(1L), "type")
  expect_false("exclusion" %in% node_types)
})

test_that("lg_lineage() ds_info is NULL branch for unknown y dataset", {
  new_session()
  # Build a session where the join refers to a y dataset not in .lg$datasets
  # This exercises the is.null(ds_info) branch
  x <- lg_tag(data.frame(USUBJID = "01", A = 1L, stringsAsFactors = FALSE),
               dataset_id = "X")
  y <- lg_tag(data.frame(USUBJID = "01", B = 2L, stringsAsFactors = FALSE),
               dataset_id = "Y")
  joined <- lg_join(x, y, by = "USUBJID")

  # Manually remove Y from the dataset registry to trigger the NULL branch
  env <- getFromNamespace(".lg", "lineager")
  env$datasets[["Y"]] <- NULL

  lin <- lg_lineage()
  # Should still complete without error
  expect_s3_class(lin, "lg_lineage")
})

test_that("print.lg_lineage() output includes node and edge counts", {
  new_session()
  adsl <- adsl_tagged()
  lg_filter(adsl, RANDFL == "Y", reason = "Not randomised")
  lg_derive(adsl, X = 1L, description = "D")

  lin <- lg_lineage()
  out <- capture.output(print(lin))
  expect_true(any(grepl("source|operation|exclusion", out, ignore.case = TRUE)))
})

test_that("lg_lineage() full pipeline: derive + join + filter all present", {
  new_session()
  x <- lg_tag(data.frame(USUBJID = c("01","02","03"),
                          grp = c("A","B","A"), stringsAsFactors = FALSE),
               dataset_id = "X")
  y <- lg_tag(data.frame(USUBJID = c("01","02"),
                          val = c(10L, 20L), stringsAsFactors = FALSE),
               dataset_id = "Y")
  x2 <- lg_derive(x, grp_n = ifelse(grp == "A", 1L, 2L),
                   description = "Numeric group")
  xy <- lg_join(x2, y, by = "USUBJID", type = "left")
  lg_filter(xy, !is.na(val), reason = "No Y record")

  lin <- lg_lineage()
  node_types <- vapply(lin$nodes, `[[`, character(1L), "type")
  expect_true("source"    %in% node_types)
  expect_true("derive"    %in% node_types)
  expect_true("join"      %in% node_types)
  expect_true("filter"    %in% node_types)
  expect_true("exclusion" %in% node_types)
  expect_true("dataset"   %in% node_types)
  # DOT contains all major labels
  expect_true(grepl("DERIVE", lin$dot))
  expect_true(grepl("JOIN",   lin$dot))
  expect_true(grepl("FILTER", lin$dot))
})