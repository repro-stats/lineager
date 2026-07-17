# test-internal-helpers.R — .html_escape(), .esc_or_dash()
#
# These are internal (@noRd) functions used throughout lg_report(). Testing
# them directly (via :::, the same pattern already used elsewhere in this
# suite for lineager:::.lg) is the only way to reliably exercise the NA/NULL
# guard branches -- every call site in report.R happens to pass non-missing
# values in the other tests, which left these specific branches uncovered.

test_that(".html_escape() escapes &, <, >, quotes correctly", {
  esc <- lineager:::.html_escape
  expect_equal(esc("a < b & c > d"), "a &lt; b &amp; c &gt; d")
  expect_equal(esc("say \"hi\""), "say &quot;hi&quot;")
  expect_equal(esc("it's"), "it&#39;s")
})

test_that(".html_escape() escapes & before other entities (no double-escaping)", {
  esc <- lineager:::.html_escape
  # If '&' were escaped after '<', "&lt;" would become "&amp;lt;" -- wrong.
  expect_equal(esc("<"), "&lt;")
  expect_false(grepl("&amp;lt;", esc("<"), fixed = TRUE))
})

test_that(".html_escape() passes through NULL unchanged", {
  esc <- lineager:::.html_escape
  expect_null(esc(NULL))
})

test_that(".html_escape() preserves NA as NA, not the string 'NA'", {
  esc <- lineager:::.html_escape
  result <- esc(c("safe", NA_character_))
  expect_equal(result[[1L]], "safe")
  expect_true(is.na(result[[2L]]))
})

test_that(".esc_or_dash() renders NA as the em-dash placeholder", {
  dash <- lineager:::.esc_or_dash
  expect_equal(dash(NA_character_), "&mdash;")
})

test_that(".esc_or_dash() renders a real value escaped, not the placeholder", {
  dash <- lineager:::.esc_or_dash
  expect_equal(dash("Site A & B"), "Site A &amp; B")
})

test_that(".esc_or_dash() treats zero-length input like NA (em-dash)", {
  dash <- lineager:::.esc_or_dash
  expect_equal(dash(character(0)), "&mdash;")
})
