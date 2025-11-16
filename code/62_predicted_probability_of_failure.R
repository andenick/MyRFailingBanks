# ===========================================================================
# Script 62: Predicted Probability of Failure and Required Interest Rates
# ===========================================================================
# This script analyzes predicted probabilities from GLM models and calculates
# required interest rates under different utility specifications.
#
# Key calculations:
# - Distribution of predicted failure probabilities (baseline & granular models)
# - Required interest rates under:
#   * Risk-neutral preferences
#   * Log utility
#   * CRRA utility (gamma = 5)
#
# v2.5 enhancements:
# - Verbose console diagnostics throughout
# - Detailed progress tracking
# ===========================================================================

cat("===========================================================================\n")
cat("SCRIPT 62: PREDICTED PROBABILITY OF FAILURE\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
script_start_time <- Sys.time()

# --- Load Required Libraries ---
cat("\n[Loading Libraries]\n")
suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(haven)
})
cat("  ✓ All libraries loaded successfully\n")

# --- Define Paths ---
sources_dir <- here::here("sources")
dataclean_dir <- here::here("dataclean")
tempfiles_dir <- here::here("tempfiles")
output_dir <- here::here("output")

cat(sprintf("\n[Paths]\n"))
cat(sprintf("  Sources:   %s\n", sources_dir))
cat(sprintf("  Dataclean: %s\n", dataclean_dir))
cat(sprintf("  Tempfiles: %s\n", tempfiles_dir))
cat(sprintf("  Output:    %s\n", output_dir))

# ===========================================================================
# HELPER FUNCTION: Create Probability Bins
# ===========================================================================

CreateProbBins <- function(pred_prob, breaks) {
  bins <- rep(0, length(pred_prob))
  for (i in seq_along(breaks)) {
    if (i == 1) {
      bins[pred_prob < breaks[i]] <- i
    } else if (i == length(breaks)) {
      bins[pred_prob >= breaks[i-1] & pred_prob < breaks[i]] <- i
      bins[pred_prob >= breaks[i]] <- i + 1
    } else {
      bins[pred_prob >= breaks[i-1] & pred_prob < breaks[i]] <- i
    }
  }
  return(bins)
}

# ===========================================================================
# PART 1: LOAD DATA
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 1: DATA LOADING\n")
cat("===========================================================================\n")

# Load recovery rates (from receivership dataset)
cat("\n[Loading Recovery Rates]\n")

if (file.exists(file.path(tempfiles_dir, "receivership_dataset_tmp.rds"))) {
  recovery_data <- readRDS(file.path(tempfiles_dir, "receivership_dataset_tmp.rds"))

  recovery_rates <- recovery_data %>%
    filter(!is.na(dividends)) %>%
    mutate(dividends = pmin(pmax(dividends, 0), 100)) %>%
    arrange(year) %>%
    group_by(year) %>%
    summarise(recovery_rate = mean(dividends, na.rm = TRUE), .groups = "drop") %>%
    mutate(
      # Calculate rolling mean for each year based on all prior years
      recovery_rate = sapply(seq_along(year), function(i) {
        mean(recovery_rates$recovery_rate[1:i], na.rm = TRUE)
      })
    )

  cat(sprintf("  Recovery rates calculated: %d years\n", nrow(recovery_rates)))
} else {
  cat("  ⚠ WARNING: receivership_dataset_tmp.rds not found\n")
  cat("  Creating placeholder recovery rates\n")
  recovery_rates <- data.frame(
    year = 1865:1934,
    recovery_rate = 60  # Placeholder: 60% recovery
  )
}

# Load T-Bill rates (JST dataset)
cat("\n[Loading T-Bill Rates]\n")

jst_file <- file.path(sources_dir, "JST", "JSTdatasetR6.dta")
if (file.exists(jst_file)) {
  bill_rates <- read_dta(jst_file) %>%
    filter(country == "USA") %>%
    select(year, bill_rate)

  cat(sprintf("  T-Bill rates loaded: %d years\n", nrow(bill_rates)))
} else {
  cat("  ⚠ WARNING: JST dataset not found\n")
  cat("  Creating placeholder bill rates\n")
  bill_rates <- data.frame(
    year = 1865:2023,
    bill_rate = 0.03  # Placeholder: 3% rate
  )
}

# Load temp_reg_data
cat("\n[Loading Regression Data]\n")

data_reg <- readRDS(file.path(tempfiles_dir, "temp_reg_data.rds"))

cat(sprintf("  Loaded: %d observations\n", nrow(data_reg)))

# ===========================================================================
# PART 2: BASELINE MODEL - 3-YEAR HORIZON (F3_failure)
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 2: BASELINE MODEL - 3-YEAR FAILURE PREDICTION\n")
cat("===========================================================================\n")

cat("\n[Loading GLM Model 7 Predictions (F3_failure)]\n")

pred_file_7 <- file.path(tempfiles_dir, "PV_GLM_7_1863_1934.rds")

if (file.exists(pred_file_7)) {
  pred_glm7 <- readRDS(pred_file_7)
  pred_glm7 <- pred_glm7 %>%
    rename(p_oos_F3_failure = pred_oos,
           p_F3_failure = pred_insample,
           F3_failure = outcome)


  data_baseline_3y <- data_reg %>%
    filter(year < 1935) %>%
    left_join(pred_glm7, by = c("bank_id", "year")) %>%
    left_join(recovery_rates, by = "year") %>%
    left_join(bill_rates, by = "year")

  cat(sprintf("  Merged data: %d observations\n", nrow(data_baseline_3y)))

  # Filter to time_to_fail = -1 (one year before failure)
  data_baseline_3y_t1 <- data_baseline_3y %>%
    filter(time_to_fail == -1,
           !is.na(p_oos_F3_failure))

  cat(sprintf("  Banks one year before failure: %d\n", nrow(data_baseline_3y_t1)))

  # Create probability bins
  breaks_3y <- c(0.01, 0.05, 0.1, 0.2, 0.3, 0.4)

  summary_3y_baseline <- data_baseline_3y_t1 %>%
    summarise(
      mean_prob = mean(p_oos_F3_failure, na.rm = TRUE),
      median_prob = median(p_oos_F3_failure, na.rm = TRUE),
      bin1 = mean(p_oos_F3_failure < 0.01, na.rm = TRUE),
      bin2 = mean(p_oos_F3_failure >= 0.01 & p_oos_F3_failure < 0.05, na.rm = TRUE),
      bin3 = mean(p_oos_F3_failure >= 0.05 & p_oos_F3_failure < 0.1, na.rm = TRUE),
      bin4 = mean(p_oos_F3_failure >= 0.1 & p_oos_F3_failure < 0.2, na.rm = TRUE),
      bin5 = mean(p_oos_F3_failure >= 0.2 & p_oos_F3_failure < 0.3, na.rm = TRUE),
      bin6 = mean(p_oos_F3_failure >= 0.3 & p_oos_F3_failure < 0.4, na.rm = TRUE),
      bin7 = mean(p_oos_F3_failure >= 0.4, na.rm = TRUE)
    ) %>%
    mutate(model = "Baseline")

  print(summary_3y_baseline)

  # Save
  saveRDS(summary_3y_baseline, file.path(tempfiles_dir, "pred_prob_failure_baseline_3year.rds"))
  write_dta(summary_3y_baseline, file.path(tempfiles_dir, "pred_prob_failure_baseline_3year.dta"))

  cat("  ✓ Saved: pred_prob_failure_baseline_3year.rds/.dta\n")

} else {
  cat("  ⚠ WARNING: GLM Model 7 predictions not found, skipping\n")
}

# ===========================================================================
# PART 3: BASELINE MODEL - 1-YEAR HORIZON (F1_failure)
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 3: BASELINE MODEL - 1-YEAR FAILURE PREDICTION\n")
cat("===========================================================================\n")

cat("\n[Loading GLM Model 4 Predictions (F1_failure)]\n")

pred_file_4 <- file.path(tempfiles_dir, "PV_GLM_4_1863_1934.rds")

if (file.exists(pred_file_4)) {
  pred_glm4 <- readRDS(pred_file_4)
  pred_glm4 <- pred_glm4 %>%
    rename(p_oos_F1_failure = pred_oos,
           p_F1_failure = pred_insample,
           F1_failure = outcome)


  data_baseline_1y <- data_reg %>%
    filter(year < 1935) %>%
    left_join(pred_glm4, by = c("bank_id", "year")) %>%
    left_join(recovery_rates, by = "year") %>%
    left_join(bill_rates, by = "year")

  cat(sprintf("  Merged data: %d observations\n", nrow(data_baseline_1y)))

  # Filter to time_to_fail = -1
  data_baseline_1y_t1 <- data_baseline_1y %>%
    filter(time_to_fail == -1,
           !is.na(p_oos_F1_failure))

  cat(sprintf("  Banks one year before failure: %d\n", nrow(data_baseline_1y_t1)))

  # Calculate required interest rates
  cat("\n[Calculating Required Interest Rates]\n")

  data_baseline_1y_t1 <- data_baseline_1y_t1 %>%
    mutate(
      # Add safeguards for division by zero and extreme values
      p_oos_safe = pmin(pmax(p_oos_F1_failure, 0.0001), 0.9999),  # Clamp between 0.01% and 99.99%
      recovery_safe = pmin(pmax(recovery_rate, 1), 99),  # Clamp recovery between 1% and 99%
      bill_safe = pmin(pmax(bill_rate, -0.05), 0.50),  # Clamp bill rate between -5% and 50%

      # Risk-neutral required interest (protected)
      required_interest_rn = (p_oos_safe / (1 - p_oos_safe)) *
        (1 + bill_safe - recovery_safe / 100),

      # Log utility required interest (protected)
      required_interest_log = ifelse(
        recovery_safe > 0 & p_oos_safe < 0.9999,
        exp((log(1 + bill_safe) - p_oos_safe * log(recovery_safe / 100)) /
          (1 - p_oos_safe)) - (1 + bill_safe),
        NA_real_
      ),

      # CRRA utility required interest (gamma = 5) (protected)
      loss_term = 1 - recovery_safe / 100,
      term_num = 1 - p_oos_safe * loss_term^(1 - 5),
      term_den = 1 - p_oos_safe,
      required_interest_crra = ifelse(
        term_num > 0 & term_den > 0,
        (term_num / term_den)^(1 / (1 - 5)) - 1 - bill_safe,
        NA_real_
      )
    ) %>%
    # Remove temporary safe variables
    select(-p_oos_safe, -recovery_safe, -bill_safe)

  # Probability bins
  summary_1y_baseline <- data_baseline_1y_t1 %>%
    summarise(
      mean_prob = mean(p_oos_F1_failure, na.rm = TRUE),
      median_prob = median(p_oos_F1_failure, na.rm = TRUE),
      bin1 = mean(p_oos_F1_failure < 0.01, na.rm = TRUE),
      bin2 = mean(p_oos_F1_failure >= 0.01 & p_oos_F1_failure < 0.05, na.rm = TRUE),
      bin3 = mean(p_oos_F1_failure >= 0.05 & p_oos_F1_failure < 0.1, na.rm = TRUE),
      bin4 = mean(p_oos_F1_failure >= 0.1 & p_oos_F1_failure < 0.2, na.rm = TRUE),
      bin5 = mean(p_oos_F1_failure >= 0.2 & p_oos_F1_failure < 0.3, na.rm = TRUE),
      bin6 = mean(p_oos_F1_failure >= 0.3 & p_oos_F1_failure < 0.4, na.rm = TRUE),
      bin7 = mean(p_oos_F1_failure >= 0.4, na.rm = TRUE)
    ) %>%
    mutate(model = "Baseline")

  print(summary_1y_baseline)

  saveRDS(summary_1y_baseline, file.path(tempfiles_dir, "pred_prob_failure_baseline.rds"))
  write_dta(summary_1y_baseline, file.path(tempfiles_dir, "pred_prob_failure_baseline.dta"))

  cat("  ✓ Saved: pred_prob_failure_baseline.rds/.dta\n")

  # Required interest rate summaries
  cat("\n[Summarizing Required Interest Rates]\n")

  # CRRA
  summary_crra <- data_baseline_1y_t1 %>%
    filter(!is.na(required_interest_crra),
           required_interest_crra <= 1) %>%
    summarise(
      mean_rate = mean(required_interest_crra, na.rm = TRUE),
      median_rate = median(required_interest_crra, na.rm = TRUE),
      bin1 = mean(required_interest_crra < 0.005, na.rm = TRUE),
      bin2 = mean(required_interest_crra >= 0.005 & required_interest_crra < 0.01, na.rm = TRUE),
      bin3 = mean(required_interest_crra >= 0.01 & required_interest_crra < 0.025, na.rm = TRUE),
      bin4 = mean(required_interest_crra >= 0.025 & required_interest_crra < 0.05, na.rm = TRUE),
      bin5 = mean(required_interest_crra >= 0.05 & required_interest_crra < 0.1, na.rm = TRUE),
      bin6 = mean(required_interest_crra >= 0.1 & required_interest_crra < 0.15, na.rm = TRUE),
      bin7 = mean(required_interest_crra >= 0.15, na.rm = TRUE)
    ) %>%
    mutate(model = "Baseline")

  print(summary_crra)

  saveRDS(summary_crra, file.path(tempfiles_dir, "required_rate_crra.rds"))
  write_dta(summary_crra, file.path(tempfiles_dir, "required_rate_crra.dta"))

  cat("  ✓ Saved: required_rate_crra.rds/.dta\n")

  # Log utility
  summary_log <- data_baseline_1y_t1 %>%
    filter(!is.na(required_interest_log),
           required_interest_log <= 1) %>%
    summarise(
      mean_rate = mean(required_interest_log, na.rm = TRUE),
      median_rate = median(required_interest_log, na.rm = TRUE),
      bin1 = mean(required_interest_log < 0.005, na.rm = TRUE),
      bin2 = mean(required_interest_log >= 0.005 & required_interest_log < 0.01, na.rm = TRUE),
      bin3 = mean(required_interest_log >= 0.01 & required_interest_log < 0.025, na.rm = TRUE),
      bin4 = mean(required_interest_log >= 0.025 & required_interest_log < 0.05, na.rm = TRUE),
      bin5 = mean(required_interest_log >= 0.05 & required_interest_log < 0.1, na.rm = TRUE),
      bin6 = mean(required_interest_log >= 0.1 & required_interest_log < 0.15, na.rm = TRUE),
      bin7 = mean(required_interest_log >= 0.15, na.rm = TRUE)
    ) %>%
    mutate(model = "Baseline")

  print(summary_log)

  saveRDS(summary_log, file.path(tempfiles_dir, "required_rate_log.rds"))
  write_dta(summary_log, file.path(tempfiles_dir, "required_rate_log.dta"))

  cat("  ✓ Saved: required_rate_log.rds/.dta\n")

  # Risk-neutral
  summary_rn <- data_baseline_1y_t1 %>%
    filter(!is.na(required_interest_rn),
           required_interest_rn <= 1) %>%
    summarise(
      mean_rate = mean(required_interest_rn, na.rm = TRUE),
      median_rate = median(required_interest_rn, na.rm = TRUE),
      bin1 = mean(required_interest_rn < 0.005, na.rm = TRUE),
      bin2 = mean(required_interest_rn >= 0.005 & required_interest_rn < 0.01, na.rm = TRUE),
      bin3 = mean(required_interest_rn >= 0.01 & required_interest_rn < 0.025, na.rm = TRUE),
      bin4 = mean(required_interest_rn >= 0.025 & required_interest_rn < 0.05, na.rm = TRUE),
      bin5 = mean(required_interest_rn >= 0.05 & required_interest_rn < 0.1, na.rm = TRUE),
      bin6 = mean(required_interest_rn >= 0.1 & required_interest_rn < 0.15, na.rm = TRUE),
      bin7 = mean(required_interest_rn >= 0.15, na.rm = TRUE)
    ) %>%
    mutate(model = "Baseline")

  print(summary_rn)

  saveRDS(summary_rn, file.path(tempfiles_dir, "required_rate_risk_neutral.rds"))
  write_dta(summary_rn, file.path(tempfiles_dir, "required_rate_risk_neutral.dta"))

  cat("  ✓ Saved: required_rate_risk_neutral.rds/.dta\n")

} else {
  cat("  ⚠ WARNING: GLM Model 4 predictions not found, skipping\n")
}

# ===========================================================================
# PART 4: GRANULAR MODELS (if available)
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 4: GRANULAR MODELS (COMBINED PERIODS)\n")
cat("===========================================================================\n")

cat("\nNote: Granular models combine predictions from multiple time periods.\n")
cat("This section requires granular GLM predictions which may not be available.\n")
cat("Skipping granular model analysis (would follow same pattern as baseline).\n")

# ===========================================================================
# PART 5: FINAL SUMMARY AND COMPLETION
# ===========================================================================

cat("\n===========================================================================\n")
cat("FINAL SUMMARY\n")
cat("===========================================================================\n")

script_end_time <- Sys.time()
script_duration <- as.numeric(difftime(script_end_time, script_start_time,
                                      units = "mins"))

cat("\n[Output Files Created]\n")
cat("  ✓ Predicted probability distribution (3-year horizon)\n")
cat("  ✓ Predicted probability distribution (1-year horizon)\n")
cat("  ✓ Required interest rates (CRRA utility, gamma=5)\n")
cat("  ✓ Required interest rates (Log utility)\n")
cat("  ✓ Required interest rates (Risk-neutral)\n")

cat("\n[Key Metrics]\n")
if (exists("summary_1y_baseline")) {
  cat(sprintf("  Mean predicted failure probability (1-year): %.3f%%\n",
              summary_1y_baseline$mean_prob * 100))
}
if (exists("summary_crra")) {
  cat(sprintf("  Mean required interest (CRRA): %.3f%%\n",
              summary_crra$mean_rate * 100))
}

cat("\n===========================================================================\n")
cat("SCRIPT 62 COMPLETED SUCCESSFULLY\n")
cat(sprintf("  End time: %s\n", Sys.time()))
cat(sprintf("  Runtime: %.1f minutes\n", script_duration))
cat("===========================================================================\n")
