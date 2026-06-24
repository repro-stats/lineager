# Shared test helpers for lineager tests

# Fresh session before each test
new_session <- function(study_id = "TEST-001", analysis_id = "test") {
  lg_start(study_id = study_id, analysis_id = analysis_id)
}

# Minimal ADSL for testing
adsl_raw <- function(n = 5L) {
  data.frame(
    USUBJID = sprintf("01-%03d", seq_len(n)),
    AGE     = 30L:(30L + n - 1L),
    SEX     = rep(c("M", "F"), length.out = n),
    RANDFL  = c("Y", "N", "Y", "Y", "N")[seq_len(n)],
    SAFFL   = c("Y", "N", "Y", "Y", "N")[seq_len(n)],
    stringsAsFactors = FALSE
  )
}

# Tagged ADSL ready to use
adsl_tagged <- function(n = 5L) {
  lg_tag(adsl_raw(n), dataset_id = "ADSL",
         domain = "DM", label = "Subject-Level Analysis Dataset")
}

# Access the internal store
lg_env <- function() getFromNamespace(".lg", "lineager")
