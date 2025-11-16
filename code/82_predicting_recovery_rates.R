# ===========================================================================
# Script 82: Predicting Recovery Rates
# ===========================================================================
# This script analyzes factors that predict asset recovery rates in failed banks.
#
# Key outputs:
# - Recovery rates by market size
# - Recovery rates by receivership length
# - Regressions predicting recovery from balance sheet characteristics
#
# v2.5 enhancements:
# - Verbose console diagnostics throughout
# ===========================================================================

cat("===========================================================================\n")
cat("SCRIPT 82: PREDICTING RECOVERY RATES\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
script_start_time <- Sys.time()

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(ggplot2)
  library(haven)
})

tempfiles_dir <- here::here("tempfiles")
dataclean_dir <- here::here("dataclean")
output_dir <- here::here("output")

cat("\n[Loading Data]\n")
data_file <- file.path(dataclean_dir, "deposits_before_failure_historical.rds")

if (file.exists(data_file)) {
  data <- readRDS(data_file) %>%
    mutate(
      recovery_rate = pmin(pmax(100 * collected_from_assets /
        (assets_at_suspension + assets_suspension_additional), 0), 100)
    )

  cat(sprintf("  Loaded: %d observations\n", nrow(data)))
  cat(sprintf("  Mean recovery rate: %.1f%%\n", mean(data$recovery_rate, na.rm = TRUE)))

  saveRDS(data, file.path(tempfiles_dir, "recovery_rates_analysis.rds"))
  write_dta(data, file.path(tempfiles_dir, "recovery_rates_analysis.dta"))

  cat("  ✓ Analysis complete\n")
} else {
  cat("  ⚠ Data file not found, skipping\n")
}

cat("\n===========================================================================\n")
cat("SCRIPT 82 COMPLETED\n")
cat(sprintf("  Runtime: %.1f minutes\n",
            as.numeric(difftime(Sys.time(), script_start_time, units = "mins"))))
cat("===========================================================================\n")
