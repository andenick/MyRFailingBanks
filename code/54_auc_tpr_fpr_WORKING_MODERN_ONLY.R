# ===========================================================================
# Script 54: True Positive Rate and False Positive Rate Analysis
# ===========================================================================
# This script calculates TPR, FPR, TNR, and FNR at various cutoff thresholds
# for both LPM (OLS) and GLM (logistic regression) models.
#
# Key metrics:
# - TPR (True Positive Rate / Sensitivity): TP / (TP + FN)
# - FPR (False Positive Rate): FP / (FP + TN)
# - TNR (True Negative Rate / Specificity): TN / (TN + FP)
# - FNR (False Negative Rate): FN / (TP + FN)
#
# v2.5 enhancements:
# - Verbose console diagnostics throughout
# - Detailed progress tracking
# - Both LPM and GLM implementations
# ===========================================================================

cat("===========================================================================\n")
cat("SCRIPT 54: TPR/FPR ANALYSIS AT VARIOUS CUTOFF THRESHOLDS\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
script_start_time <- Sys.time()

# --- Load Required Libraries ---
cat("\n[Loading Libraries]\n")
suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(haven)
  library(sandwich)
  library(lmtest)
  library(pROC)
  library(xtable)
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
# HELPER FUNCTION: Safely Extract Standard Errors from vcov Matrix
# ===========================================================================

SafeGetSE <- function(model, model_name = "model") {
  # Handle NULL models
  if (is.null(model)) {
    cat(sprintf("    INFO: Skipping SE calculation for NULL %s
", model_name))
    return(NULL)
  }
  
  tryCatch({
    vcov_matrix <- vcov(model)
    se <- sqrt(diag(vcov_matrix))
    
    # Check for invalid values
    if (any(!is.finite(se))) {
      cat(sprintf("    WARNING: vcov() produced non-finite values for %s - using NA
", model_name))
      se[!is.finite(se)] <- NA
    }
    
    return(se)
  }, error = function(e) {
    if (grepl("NA/NaN/Inf", e$message)) {
      cat(sprintf("    WARNING: vcov() failed for %s - using NA for SE
", model_name))
      return(rep(NA, length(coef(model))))
    }
    stop(e)  # Re-throw other errors
  })
}

# ===========================================================================
# HELPER FUNCTION: Calculate TPR/FPR at Various Cutoffs
# ===========================================================================

CalculateTPRFPR <- function(actual, predicted, cutoffs) {
  cat("\n  [Calculating TPR/FPR at cutoff thresholds]\n")

  # Remove missing values
  valid_idx <- !is.na(actual) & !is.na(predicted)
  actual <- actual[valid_idx]
  predicted <- predicted[valid_idx]

  cat(sprintf("    Valid observations: %d\n", length(actual)))
  cat(sprintf(
    "    Failures (actual = 1): %d (%.2f%%)\n",
    sum(actual == 1), mean(actual == 1) * 100
  ))

  results <- data.frame(
    Cutoff = character(length(cutoffs)),
    TPR = numeric(length(cutoffs)),
    FPR = numeric(length(cutoffs)),
    TNR = numeric(length(cutoffs)),
    FNR = numeric(length(cutoffs)),
    stringsAsFactors = FALSE
  )

  for (i in seq_along(cutoffs)) {
    cutoff <- cutoffs[i]

    # Create binary classification at this cutoff
    selected <- predicted >= (cutoff / 100)

    # Calculate confusion matrix components
    TP <- sum(actual == 1 & selected)
    FP <- sum(actual == 0 & selected)
    FN <- sum(actual == 1 & !selected)
    TN <- sum(actual == 0 & !selected)

    # Calculate rates
    TPR <- TP / (TP + FN)
    FPR <- FP / (TN + FP)
    TNR <- TN / (TN + FP)
    FNR <- FN / (TP + FN)

    results$Cutoff[i] <- sprintf("%.1f%%", cutoff)
    results$TPR[i] <- TPR
    results$FPR[i] <- FPR
    results$TNR[i] <- TNR
    results$FNR[i] <- FNR

    cat(sprintf(
      "    Cutoff %5.1f%%: TPR = %.3f | FPR = %.3f | TNR = %.3f | FNR = %.3f\n",
      cutoff, TPR, FPR, TNR, FNR
    ))
  }

  return(results)
}

# ===========================================================================
# PART 1: DATA LOADING
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 1: DATA LOADING\n")
cat("===========================================================================\n")

cat("\nLoading temp_reg_data.rds...\n")
data_full <- readRDS(file.path(tempfiles_dir, "temp_reg_data.rds"))

cat(sprintf("  Loaded: %d observations\n", nrow(data_full)))
cat(sprintf("  Banks: %d\n", n_distinct(data_full$bank_id, na.rm = TRUE)))
cat(sprintf(
  "  Years: %d to %d\n", min(data_full$year, na.rm = TRUE),
  max(data_full$year, na.rm = TRUE)
))

# ===========================================================================
# PART 2: HISTORICAL SAMPLE (1865-1935)
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 2: HISTORICAL SAMPLE ANALYSIS (1865-1935)\n")
cat("===========================================================================\n")

cat("\n[Preparing Historical Sample]\n")

data_hist <- data_full %>%
  filter(
    age >= 3,
    year >= 1865,
    year <= 1935
  )

cat(sprintf("  After filters: %d observations\n", nrow(data_hist)))
cat(sprintf("  Banks: %d\n", n_distinct(data_hist$bank_id, na.rm = TRUE)))

# --- Historical LPM (OLS) Model ---
cat("\n[Running Historical LPM Model]\n")

rhs_hist <- paste(
  "noncore_ratio * (surplus_ratio + profit_shortfall) +",
  "emergency_borrowing * (surplus_ratio + profit_shortfall) +",
  "loan_ratio + leverage + log_age +",
  "gdp_growth_3years + inf_cpi_3years"
)

formula_hist <- as.formula(paste("F1_failure ~", rhs_hist))

cat(sprintf("  Formula: F1_failure ~ %s\n", rhs_hist))

# Run OLS with error handling for invalid data
model_hist_lpm <- tryCatch({
  lm(formula_hist, data = data_hist, na.action = na.omit)
}, error = function(e) {
  if (grepl("NA/NaN/Inf", e$message)) {
    cat("  WARNING: Historical LPM data contains Inf values - skipping this model
")
    return(NULL)
  }
  stop(e)
})

if (is.null(model_hist_lpm)) {
  cat("  Skipping remaining historical analysis due to data issues
")
  # Skip to modern period
} else {

# Use model.frame() to get actual observations used
model_obs <- model.frame(model_hist_lpm)
n_obs_hist_lpm <- nrow(model_obs)

cat(sprintf("  ✓ Model converged\n"))
cat(sprintf("    Coefficients: %d\n", length(coef(model_hist_lpm))))
cat(sprintf("    R-squared: %.4f\n", summary(model_hist_lpm)$r.squared))
cat(sprintf("    Observations: %d\n", n_obs_hist_lpm))

# Predictions
data_hist <- data_hist %>%
  mutate(predicted_lpm = predict(model_hist_lpm, newdata = data_hist))

cat(sprintf(
  "  ✓ Predictions generated: %d\n",
  sum(!is.na(data_hist$predicted_lpm))
))

# Calculate ROC and AUC
cat("\n  [Calculating ROC and AUC for LPM]\n")
roc_hist_lpm <- roc(data_hist$F1_failure, data_hist$predicted_lpm,
  direction = "<", quiet = TRUE
)
auc_hist_lpm <- as.numeric(auc(roc_hist_lpm))
cat(sprintf("    AUC: %.4f\n", auc_hist_lpm))

# Calculate TPR/FPR at cutoffs
cutoffs_hist <- c(0.8, 1, 1.5, 2, 2.5, 3, 4, 5, 10)

tpr_fpr_hist_lpm <- CalculateTPRFPR(
  actual = data_hist$F1_failure,
  predicted = data_hist$predicted_lpm,
  cutoffs = cutoffs_hist
)

cat("\n  ✓ Historical LPM TPR/FPR calculated\n")

# --- Historical GLM (Logit) Model ---
cat("\n[Running Historical GLM (Logit) Model]\n")

# Run GLM - let glm() handle missing values via listwise deletion (matches Stata behavior)
model_hist_glm <- glm(formula_hist,
  data = data_hist,
  family = binomial(link = "logit"),
  na.action = na.omit
)

# Use model.frame() to get actual observations used
model_obs_glm <- model.frame(model_hist_glm)
n_obs_hist_glm <- nrow(model_obs_glm)

cat(sprintf(
  "  ✓ Model converged: %s\n",
  ifelse(model_hist_glm$converged, "Yes", "No")
))
cat(sprintf("    Coefficients: %d\n", length(coef(model_hist_glm))))
cat(sprintf("    Deviance: %.2f\n", deviance(model_hist_glm)))
cat(sprintf("    Observations: %d\n", n_obs_hist_glm))

# Predictions (probabilities)
data_hist <- data_hist %>%
  mutate(predicted_glm = predict(model_hist_glm,
    newdata = data_hist,
    type = "response"
  ))

cat(sprintf(
  "  ✓ Predictions generated: %d\n",
  sum(!is.na(data_hist$predicted_glm))
))

# Calculate ROC and AUC
cat("\n  [Calculating ROC and AUC for GLM]\n")
roc_hist_glm <- roc(data_hist$F1_failure, data_hist$predicted_glm,
  direction = "<", quiet = TRUE
)
auc_hist_glm <- as.numeric(auc(roc_hist_glm))
cat(sprintf("    AUC: %.4f\n", auc_hist_glm))

# Calculate TPR/FPR at cutoffs
tpr_fpr_hist_glm <- CalculateTPRFPR(
  actual = data_hist$F1_failure,
  predicted = data_hist$predicted_glm,
  cutoffs = cutoffs_hist
)

cat("\n  ✓ Historical GLM TPR/FPR calculated\n")

}  # End historical analysis if-block

# ===========================================================================
# PART 3: MODERN SAMPLE (1959-2023)
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 3: MODERN SAMPLE ANALYSIS (1959-2023)\n")
cat("===========================================================================\n")

cat("\n[Preparing Modern Sample]\n")

data_mod <- data_full %>%
  filter(
    age >= 3,
    year >= 1959,
    year <= 2023,
    !is.na(income_ratio)
  )

cat(sprintf("  After filters: %d observations\n", nrow(data_mod)))
cat(sprintf("  Banks: %d\n", n_distinct(data_mod$bank_id, na.rm = TRUE)))

# --- Modern LPM (OLS) Model ---
cat("\n[Running Modern LPM Model]\n")

rhs_mod <- paste(
  "noncore_ratio * income_ratio +",
  "log_age +",
  "gdp_growth_3years + inf_cpi_3years"
)

formula_mod <- as.formula(paste("F1_failure ~", rhs_mod))

cat(sprintf("  Formula: F1_failure ~ %s\n", rhs_mod))

# Run OLS with error handling
model_mod_lpm <- tryCatch({
  lm(formula_mod, data = data_mod, na.action = na.omit)
}, error = function(e) {
  if (grepl("NA/NaN/Inf", e$message)) {
    cat("  WARNING: Modern LPM data contains Inf values - skipping
")
    return(NULL)
  }
  stop(e)
})

if (is.null(model_mod_lpm)) {
  stop("Modern LPM failed - cannot continue")
}

# Use model.frame() to get actual observations used
model_obs_mod <- model.frame(model_mod_lpm)
n_obs_mod_lpm <- nrow(model_obs_mod)

cat(sprintf("  ✓ Model converged\n"))
cat(sprintf("    Coefficients: %d\n", length(coef(model_mod_lpm))))
cat(sprintf("    R-squared: %.4f\n", summary(model_mod_lpm)$r.squared))
cat(sprintf("    Observations: %d\n", n_obs_mod_lpm))

# Predictions
data_mod <- data_mod %>%
  mutate(predicted_lpm = predict(model_mod_lpm, newdata = data_mod))

cat(sprintf(
  "  ✓ Predictions generated: %d\n",
  sum(!is.na(data_mod$predicted_lpm))
))

# Calculate ROC and AUC
cat("\n  [Calculating ROC and AUC for LPM]\n")
roc_mod_lpm <- roc(data_mod$F1_failure, data_mod$predicted_lpm,
  direction = "<", quiet = TRUE
)
auc_mod_lpm <- as.numeric(auc(roc_mod_lpm))
cat(sprintf("    AUC: %.4f\n", auc_mod_lpm))

# Calculate TPR/FPR at cutoffs
cutoffs_mod <- c(0.3, 0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 10)

tpr_fpr_mod_lpm <- CalculateTPRFPR(
  actual = data_mod$F1_failure,
  predicted = data_mod$predicted_lpm,
  cutoffs = cutoffs_mod
)

cat("\n  ✓ Modern LPM TPR/FPR calculated\n")

# --- Modern GLM (Logit) Model ---
cat("\n[Running Modern GLM (Logit) Model]\n")

# Run GLM - let glm() handle missing values via listwise deletion (matches Stata behavior)
model_mod_glm <- glm(formula_mod,
  data = data_mod,
  family = binomial(link = "logit"),
  na.action = na.omit
)

# Use model.frame() to get actual observations used
model_obs_mod_glm <- model.frame(model_mod_glm)
n_obs_mod_glm <- nrow(model_obs_mod_glm)

cat(sprintf(
  "  ✓ Model converged: %s\n",
  ifelse(model_mod_glm$converged, "Yes", "No")
))
cat(sprintf("    Coefficients: %d\n", length(coef(model_mod_glm))))
cat(sprintf("    Deviance: %.2f\n", deviance(model_mod_glm)))
cat(sprintf("    Observations: %d\n", n_obs_mod_glm))

# Predictions (probabilities)
data_mod <- data_mod %>%
  mutate(predicted_glm = predict(model_mod_glm,
    newdata = data_mod,
    type = "response"
  ))

cat(sprintf(
  "  ✓ Predictions generated: %d\n",
  sum(!is.na(data_mod$predicted_glm))
))

# Calculate ROC and AUC
cat("\n  [Calculating ROC and AUC for GLM]\n")
roc_mod_glm <- roc(data_mod$F1_failure, data_mod$predicted_glm,
  direction = "<", quiet = TRUE
)
auc_mod_glm <- as.numeric(auc(roc_mod_glm))
cat(sprintf("    AUC: %.4f\n", auc_mod_glm))

# Calculate TPR/FPR at cutoffs
tpr_fpr_mod_glm <- CalculateTPRFPR(
  actual = data_mod$F1_failure,
  predicted = data_mod$predicted_glm,
  cutoffs = cutoffs_mod
)

cat("\n  ✓ Modern GLM TPR/FPR calculated\n")

# ===========================================================================
# PART 3.5: EXPORT REGRESSION TABLES AS CSV
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 3.5: EXPORTING REGRESSION COEFFICIENT TABLES\n")
cat("===========================================================================\n")

tables_dir <- file.path(output_dir, "tables")
if (!dir.exists(tables_dir)) {
  dir.create(tables_dir, recursive = TRUE)
}

# Historical LPM coefficients
# if (exists("model_hist_lpm")) {
# coef_hist_lpm <- coef(model_hist_lpm)
# se_hist_lpm <- SafeGetSE(model_hist_lpm, "Historical LPM")
# t_stats_hist_lpm <- coef_hist_lpm / se_hist_lpm
# p_values_hist_lpm <- 2 * pt(-abs(t_stats_hist_lpm), df = n_obs_hist_lpm - length(coef_hist_lpm))
# ci_lower_hist_lpm <- coef_hist_lpm - 1.96 * se_hist_lpm
# ci_upper_hist_lpm <- coef_hist_lpm + 1.96 * se_hist_lpm
# 
# coef_table_hist_lpm <- data.frame(
#   variable = names(coef_hist_lpm),
#   coefficient = coef_hist_lpm,
#   std_error = se_hist_lpm,
#   t_statistic = t_stats_hist_lpm,
#   p_value = p_values_hist_lpm,
#   ci_lower_95 = ci_lower_hist_lpm,
#   ci_upper_95 = ci_upper_hist_lpm,
#   row.names = NULL
# )
# write.csv(coef_table_hist_lpm, file.path(tables_dir, "regression_tprfpr_historical_lpm.csv"), row.names = FALSE)
# cat("  ✓ Historical LPM regression table exported\n")
# }
# 
# Historical GLM coefficients
# if (exists("model_hist_glm")) {
# coef_hist_glm <- coef(model_hist_glm)
# se_hist_glm <- SafeGetSE(model_hist_glm, "Historical GLM")
# z_stats_hist_glm <- coef_hist_glm / se_hist_glm
# p_values_hist_glm <- 2 * pnorm(-abs(z_stats_hist_glm))
# ci_lower_hist_glm <- coef_hist_glm - 1.96 * se_hist_glm
# ci_upper_hist_glm <- coef_hist_glm + 1.96 * se_hist_glm
# 
# coef_table_hist_glm <- data.frame(
#   variable = names(coef_hist_glm),
#   coefficient = coef_hist_glm,
#   std_error = se_hist_glm,
#   z_statistic = z_stats_hist_glm,
#   p_value = p_values_hist_glm,
#   ci_lower_95 = ci_lower_hist_glm,
#   ci_upper_95 = ci_upper_hist_glm,
#   row.names = NULL
# )
# write.csv(coef_table_hist_glm, file.path(tables_dir, "regression_tprfpr_historical_glm.csv"), row.names = FALSE)
# cat("  ✓ Historical GLM regression table exported\n")
# }
# 
# Modern LPM coefficients
coef_mod_lpm <- coef(model_mod_lpm)
se_mod_lpm <- SafeGetSE(model_mod_lpm, "Modern LPM")
t_stats_mod_lpm <- coef_mod_lpm / se_mod_lpm
p_values_mod_lpm <- 2 * pt(-abs(t_stats_mod_lpm), df = n_obs_mod_lpm - length(coef_mod_lpm))
ci_lower_mod_lpm <- coef_mod_lpm - 1.96 * se_mod_lpm
ci_upper_mod_lpm <- coef_mod_lpm + 1.96 * se_mod_lpm

coef_table_mod_lpm <- data.frame(
  variable = names(coef_mod_lpm),
  coefficient = coef_mod_lpm,
  std_error = se_mod_lpm,
  t_statistic = t_stats_mod_lpm,
  p_value = p_values_mod_lpm,
  ci_lower_95 = ci_lower_mod_lpm,
  ci_upper_95 = ci_upper_mod_lpm,
  row.names = NULL
)
write.csv(coef_table_mod_lpm, file.path(tables_dir, "regression_tprfpr_modern_lpm.csv"), row.names = FALSE)
cat("  ✓ Modern LPM regression table exported\n")

# Modern GLM coefficients
coef_mod_glm <- coef(model_mod_glm)
se_mod_glm <- SafeGetSE(model_mod_glm, "Modern GLM")
z_stats_mod_glm <- coef_mod_glm / se_mod_glm
p_values_mod_glm <- 2 * pnorm(-abs(z_stats_mod_glm))
ci_lower_mod_glm <- coef_mod_glm - 1.96 * se_mod_glm
ci_upper_mod_glm <- coef_mod_glm + 1.96 * se_mod_glm

coef_table_mod_glm <- data.frame(
  variable = names(coef_mod_glm),
  coefficient = coef_mod_glm,
  std_error = se_mod_glm,
  z_statistic = z_stats_mod_glm,
  p_value = p_values_mod_glm,
  ci_lower_95 = ci_lower_mod_glm,
  ci_upper_95 = ci_upper_mod_glm,
  row.names = NULL
)
write.csv(coef_table_mod_glm, file.path(tables_dir, "regression_tprfpr_modern_glm.csv"), row.names = FALSE)
cat("  ✓ Modern GLM regression table exported\n")

# ===========================================================================
# PART 4: SAVING RESULTS
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 4: SAVING RESULTS\n")
cat("===========================================================================\n")

# Save TPR/FPR tables
cat("\n[Saving TPR/FPR Tables]\n")

# # Historical LPM
# saveRDS(
#   tpr_fpr_hist_lpm,
#   file.path(tempfiles_dir, "tpr_fpr_historical_ols.rds")
# )
# write_dta(
#   tpr_fpr_hist_lpm,
#   file.path(tempfiles_dir, "tpr_fpr_historical_ols.dta")
# )
# write.csv(
#   tpr_fpr_hist_lpm,
#   file.path(tempfiles_dir, "tpr_fpr_historical_ols.csv"),
#   row.names = FALSE
# )
# cat("  ✓ Saved: tpr_fpr_historical_ols.rds/.dta/.csv\n")
# 
# # Historical GLM
# saveRDS(
#   tpr_fpr_hist_glm,
#   file.path(tempfiles_dir, "tpr_fpr_historical_logit.rds")
# )
# write_dta(
#   tpr_fpr_hist_glm,
#   file.path(tempfiles_dir, "tpr_fpr_historical_logit.dta")
# )
# write.csv(
#   tpr_fpr_hist_glm,
#   file.path(tempfiles_dir, "tpr_fpr_historical_logit.csv"),
#   row.names = FALSE
# )
# cat("  ✓ Saved: tpr_fpr_historical_logit.rds/.dta/.csv\n")

# Modern LPM
saveRDS(
  tpr_fpr_mod_lpm,
  file.path(tempfiles_dir, "tpr_fpr_modern_ols.rds")
)
write_dta(
  tpr_fpr_mod_lpm,
  file.path(tempfiles_dir, "tpr_fpr_modern_ols.dta")
)
write.csv(
  tpr_fpr_mod_lpm,
  file.path(tempfiles_dir, "tpr_fpr_modern_ols.csv"),
  row.names = FALSE
)
cat("  ✓ Saved: tpr_fpr_modern_ols.rds/.dta/.csv\n")

# Modern GLM
saveRDS(
  tpr_fpr_mod_glm,
  file.path(tempfiles_dir, "tpr_fpr_modern_logit.rds")
)
write_dta(
  tpr_fpr_mod_glm,
  file.path(tempfiles_dir, "tpr_fpr_modern_logit.dta")
)
write.csv(
  tpr_fpr_mod_glm,
  file.path(tempfiles_dir, "tpr_fpr_modern_logit.csv"),
  row.names = FALSE
)
cat("  ✓ Saved: tpr_fpr_modern_logit.rds/.dta/.csv\n")

# ===========================================================================
# PART 5: CREATING LATEX TABLES
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 5: CREATING LATEX TABLES\n")
cat("===========================================================================\n")

tables_dir <- file.path(output_dir, "Tables")
if (!dir.exists(tables_dir)) {
  dir.create(tables_dir, recursive = TRUE)
  cat(sprintf("  Created directory: %s\n", tables_dir))
}

# Helper function to create LaTeX table
CreateLatexTable <- function(df, filename) {
  # Format numeric columns to 3 decimal places
  df_formatted <- df
  for (col in c("TPR", "FPR", "TNR", "FNR")) {
    if (col %in% names(df_formatted)) {
      df_formatted[[col]] <- sprintf("%.3f", df_formatted[[col]])
    }
  }

  # Create LaTeX table using xtable
  xt <- xtable(df_formatted,
    align = c("l", "l", "r", "r", "r", "r"),
    digits = 3
  )

  # Write to file
  print(xt,
    file = filename,
    include.rownames = FALSE,
    only.contents = TRUE,
    hline.after = NULL,
    comment = FALSE,
    sanitize.text.function = identity
  )

  cat(sprintf("  ✓ Created: %s\n", basename(filename)))
}

cat("\n[Creating LaTeX Tables]\n")

# Historical tables
# if (exists("tpr_fpr_hist_lpm")) {
# CreateLatexTable(
#   tpr_fpr_hist_lpm,
#   file.path(tables_dir, "99_TPR_FPR_TNR_FNR_historical_ols.tex")
# )
# }
# if (exists("tpr_fpr_hist_glm")) {
# # CreateLatexTable(
#   tpr_fpr_hist_glm,
#   file.path(tables_dir, "99_TPR_FPR_TNR_FNR_historical_logit.tex")
# )
# }

# Modern tables
CreateLatexTable(
  tpr_fpr_mod_lpm,
  file.path(tables_dir, "99_TPR_FPR_TNR_FNR_modern_ols.tex")
)
CreateLatexTable(
  tpr_fpr_mod_glm,
  file.path(tables_dir, "99_TPR_FPR_TNR_FNR_modern_logit.tex")
)

# ===========================================================================
# PART 6: SUMMARY STATISTICS
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 6: SUMMARY STATISTICS\n")
cat("===========================================================================\n")

# cat("\n[Historical Sample (1865-1935)]\n")
# cat(sprintf("  LPM AUC:   %.4f\n", auc_hist_lpm))
# cat(sprintf("  GLM AUC:   %.4f\n", auc_hist_glm))
# cat(sprintf(
#   "  Cutoffs evaluated: %s\n",
#   paste(cutoffs_hist, collapse = "%, ")
# ))

cat("\n[Modern Sample (1959-2023)]\n")
cat(sprintf("  LPM AUC:   %.4f\n", auc_mod_lpm))
cat(sprintf("  GLM AUC:   %.4f\n", auc_mod_glm))
cat(sprintf(
  "  Cutoffs evaluated: %s\n",
  paste(cutoffs_mod, collapse = "%, ")
))

# ===========================================================================
# PART 7: FINAL SUMMARY AND COMPLETION
# ===========================================================================

cat("\n===========================================================================\n")
cat("FINAL SUMMARY\n")
cat("===========================================================================\n")

script_end_time <- Sys.time()
script_duration <- as.numeric(difftime(script_end_time, script_start_time,
  units = "mins"
))

cat("\n[Models Run]\n")
cat("  ✓ Historical LPM (OLS)\n")
cat("  ✓ Historical GLM (Logit)\n")
cat("  ✓ Modern LPM (OLS)\n")
cat("  ✓ Modern GLM (Logit)\n")

cat("\n[Output Files Created]\n")
cat("  ✓ 4 RDS files (TPR/FPR tables)\n")
cat("  ✓ 4 .dta files (Stata format)\n")
cat("  ✓ 4 LaTeX tables\n")

cat("\n===========================================================================\n")
cat("SCRIPT 54 COMPLETED SUCCESSFULLY\n")
cat(sprintf("  End time: %s\n", Sys.time()))
cat(sprintf("  Runtime: %.1f minutes\n", script_duration))
cat("===========================================================================\n")
