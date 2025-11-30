# ===========================================================================
# K-Fold Cross-Validation for Robust Out-of-Sample AUC
# ===========================================================================
# Purpose: Perform 5-fold and 10-fold CV to get robust OOS AUC estimates
# Author: Claude Code
# Date: 2025-11-30
# ===========================================================================

library(tidyverse)
library(pROC)

cat("\n")
cat("===========================================================================\n")
cat("K-FOLD CROSS-VALIDATION\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
cat("===========================================================================\n\n")

# ===========================================================================
# 1. LOAD DATA
# ===========================================================================

cat("Step 1: Loading 2000+ period data...\n\n")

data_path <- "D:/Arcanum/Projects/FailingBanks/Technical/data/comprehensive_comparison/correia_reg_modern.rds"
data_2000 <- readRDS(data_path) %>%
  filter(year >= 2000) %>%
  drop_na(F1_failure, income_ratio, noncore_ratio, log_age)

cat(sprintf("  Observations: %s\n", format(nrow(data_2000), big.mark=",")))
cat(sprintf("  Failures: %d (%.2f%%)\n", sum(data_2000$F1_failure),
            mean(data_2000$F1_failure) * 100))

# ===========================================================================
# 2. DEFINE CV FUNCTION
# ===========================================================================

cat("\n\nStep 2: Setting up cross-validation...\n\n")

perform_cv <- function(data, k = 5, seed = 42) {
  set.seed(seed)

  # Create fold assignments
  n <- nrow(data)
  fold_ids <- sample(rep(1:k, length.out = n))

  # Storage for results
  results <- tibble()

  for (fold in 1:k) {
    # Split data
    test_idx <- which(fold_ids == fold)
    train_data <- data[-test_idx, ]
    test_data <- data[test_idx, ]

    # Check for failures in both sets
    train_failures <- sum(train_data$F1_failure)
    test_failures <- sum(test_data$F1_failure)

    if (test_failures < 2) {
      cat(sprintf("    Fold %d: Skipping - only %d failures in test set\n", fold, test_failures))
      next
    }

    # Estimate models on training data
    # Model 1: Solvency Only
    m1 <- lm(F1_failure ~ income_ratio + log_age, data = train_data)

    # Model 2: Funding Only
    m2 <- lm(F1_failure ~ noncore_ratio + log_age, data = train_data)

    # Model 3: Interaction
    m3 <- lm(F1_failure ~ income_ratio + noncore_ratio +
               income_ratio:noncore_ratio + log_age, data = train_data)

    # Predict on test data
    pred1 <- predict(m1, newdata = test_data)
    pred2 <- predict(m2, newdata = test_data)
    pred3 <- predict(m3, newdata = test_data)

    # Calculate AUC
    auc1 <- tryCatch(as.numeric(auc(roc(test_data$F1_failure, pred1, quiet = TRUE))),
                     error = function(e) NA)
    auc2 <- tryCatch(as.numeric(auc(roc(test_data$F1_failure, pred2, quiet = TRUE))),
                     error = function(e) NA)
    auc3 <- tryCatch(as.numeric(auc(roc(test_data$F1_failure, pred3, quiet = TRUE))),
                     error = function(e) NA)

    # Store results
    fold_results <- tibble(
      fold = fold,
      n_train = nrow(train_data),
      n_test = nrow(test_data),
      failures_train = train_failures,
      failures_test = test_failures,
      auc_model1 = auc1,
      auc_model2 = auc2,
      auc_model3 = auc3
    )

    results <- bind_rows(results, fold_results)
  }

  return(results)
}

# ===========================================================================
# 3. RUN 5-FOLD CV
# ===========================================================================

cat("Step 3: Running 5-fold cross-validation...\n\n")

cv5_results <- perform_cv(data_2000, k = 5, seed = 42)

cat("  5-Fold CV Results:\n\n")
print(cv5_results)

cv5_summary <- cv5_results %>%
  summarise(
    k = 5,
    n_folds_completed = n(),
    mean_auc_model1 = mean(auc_model1, na.rm = TRUE),
    sd_auc_model1 = sd(auc_model1, na.rm = TRUE),
    mean_auc_model2 = mean(auc_model2, na.rm = TRUE),
    sd_auc_model2 = sd(auc_model2, na.rm = TRUE),
    mean_auc_model3 = mean(auc_model3, na.rm = TRUE),
    sd_auc_model3 = sd(auc_model3, na.rm = TRUE),
    total_test_failures = sum(failures_test)
  )

cat("\n  5-Fold CV Summary:\n")
print(cv5_summary)

# ===========================================================================
# 4. RUN 10-FOLD CV
# ===========================================================================

cat("\n\nStep 4: Running 10-fold cross-validation...\n\n")

cv10_results <- perform_cv(data_2000, k = 10, seed = 42)

cat("  10-Fold CV Results:\n\n")
print(cv10_results)

cv10_summary <- cv10_results %>%
  summarise(
    k = 10,
    n_folds_completed = n(),
    mean_auc_model1 = mean(auc_model1, na.rm = TRUE),
    sd_auc_model1 = sd(auc_model1, na.rm = TRUE),
    mean_auc_model2 = mean(auc_model2, na.rm = TRUE),
    sd_auc_model2 = sd(auc_model2, na.rm = TRUE),
    mean_auc_model3 = mean(auc_model3, na.rm = TRUE),
    sd_auc_model3 = sd(auc_model3, na.rm = TRUE),
    total_test_failures = sum(failures_test)
  )

cat("\n  10-Fold CV Summary:\n")
print(cv10_summary)

# ===========================================================================
# 5. REPEATED CV (5x5-fold)
# ===========================================================================

cat("\n\nStep 5: Running repeated cross-validation (5 repetitions of 5-fold)...\n\n")

repeated_results <- tibble()

for (rep in 1:5) {
  rep_results <- perform_cv(data_2000, k = 5, seed = 42 + rep)
  rep_results <- rep_results %>% mutate(repetition = rep)
  repeated_results <- bind_rows(repeated_results, rep_results)
}

repeated_summary <- repeated_results %>%
  summarise(
    total_folds = n(),
    mean_auc_model1 = mean(auc_model1, na.rm = TRUE),
    sd_auc_model1 = sd(auc_model1, na.rm = TRUE),
    ci_lower_model1 = mean_auc_model1 - 1.96 * sd_auc_model1 / sqrt(n()),
    ci_upper_model1 = mean_auc_model1 + 1.96 * sd_auc_model1 / sqrt(n()),
    mean_auc_model2 = mean(auc_model2, na.rm = TRUE),
    sd_auc_model2 = sd(auc_model2, na.rm = TRUE),
    ci_lower_model2 = mean_auc_model2 - 1.96 * sd_auc_model2 / sqrt(n()),
    ci_upper_model2 = mean_auc_model2 + 1.96 * sd_auc_model2 / sqrt(n()),
    mean_auc_model3 = mean(auc_model3, na.rm = TRUE),
    sd_auc_model3 = sd(auc_model3, na.rm = TRUE),
    ci_lower_model3 = mean_auc_model3 - 1.96 * sd_auc_model3 / sqrt(n()),
    ci_upper_model3 = mean_auc_model3 + 1.96 * sd_auc_model3 / sqrt(n())
  )

cat("  Repeated 5x5-Fold CV Summary:\n\n")
print(repeated_summary)

# ===========================================================================
# 6. COMPARE TO IN-SAMPLE AUC
# ===========================================================================

cat("\n\nStep 6: Comparing CV AUC to in-sample AUC...\n\n")

# Calculate in-sample AUC
m1_full <- lm(F1_failure ~ income_ratio + log_age, data = data_2000)
m2_full <- lm(F1_failure ~ noncore_ratio + log_age, data = data_2000)
m3_full <- lm(F1_failure ~ income_ratio + noncore_ratio +
                income_ratio:noncore_ratio + log_age, data = data_2000)

insample_auc1 <- as.numeric(auc(roc(data_2000$F1_failure, predict(m1_full), quiet = TRUE)))
insample_auc2 <- as.numeric(auc(roc(data_2000$F1_failure, predict(m2_full), quiet = TRUE)))
insample_auc3 <- as.numeric(auc(roc(data_2000$F1_failure, predict(m3_full), quiet = TRUE)))

comparison <- tibble(
  model = c("Model 1 (Solvency)", "Model 2 (Funding)", "Model 3 (Interaction)"),
  insample_auc = c(insample_auc1, insample_auc2, insample_auc3),
  cv5_auc = c(cv5_summary$mean_auc_model1, cv5_summary$mean_auc_model2, cv5_summary$mean_auc_model3),
  cv10_auc = c(cv10_summary$mean_auc_model1, cv10_summary$mean_auc_model2, cv10_summary$mean_auc_model3),
  repeated_cv_auc = c(repeated_summary$mean_auc_model1, repeated_summary$mean_auc_model2, repeated_summary$mean_auc_model3)
) %>%
  mutate(
    degradation_5fold = (insample_auc - cv5_auc) / insample_auc * 100,
    degradation_10fold = (insample_auc - cv10_auc) / insample_auc * 100,
    degradation_repeated = (insample_auc - repeated_cv_auc) / insample_auc * 100
  )

cat("  In-Sample vs Cross-Validated AUC:\n\n")
print(comparison %>% mutate(across(where(is.numeric), ~round(., 4))))

# ===========================================================================
# 7. SAVE RESULTS
# ===========================================================================

cat("\n\nStep 7: Saving results...\n\n")

output_dir <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/validation/outputs"

# Save detailed fold results
write_csv(cv5_results, file.path(output_dir, "cv5_fold_results.csv"))
cat(sprintf("  ✓ Saved: cv5_fold_results.csv\n"))

write_csv(cv10_results, file.path(output_dir, "cv10_fold_results.csv"))
cat(sprintf("  ✓ Saved: cv10_fold_results.csv\n"))

write_csv(repeated_results, file.path(output_dir, "repeated_cv_results.csv"))
cat(sprintf("  ✓ Saved: repeated_cv_results.csv\n"))

# Save comparison summary
write_csv(comparison, file.path(output_dir, "cv_auc_comparison.csv"))
cat(sprintf("  ✓ Saved: cv_auc_comparison.csv\n"))

# Save summary with confidence intervals
cv_summary_all <- bind_rows(
  cv5_summary %>% mutate(cv_type = "5-fold"),
  cv10_summary %>% mutate(cv_type = "10-fold")
)
write_csv(cv_summary_all, file.path(output_dir, "cv_summary.csv"))
cat(sprintf("  ✓ Saved: cv_summary.csv\n"))

cat("\n")
cat("===========================================================================\n")
cat("CROSS-VALIDATION SUMMARY\n")
cat("===========================================================================\n\n")

cat("MODEL PERFORMANCE (Out-of-Sample via CV):\n\n")

for (i in 1:nrow(comparison)) {
  cat(sprintf("  %s:\n", comparison$model[i]))
  cat(sprintf("    In-sample AUC:     %.4f\n", comparison$insample_auc[i]))
  cat(sprintf("    5-Fold CV AUC:     %.4f (%.1f%% degradation)\n",
              comparison$cv5_auc[i], comparison$degradation_5fold[i]))
  cat(sprintf("    10-Fold CV AUC:    %.4f (%.1f%% degradation)\n",
              comparison$cv10_auc[i], comparison$degradation_10fold[i]))
  cat(sprintf("    Repeated CV AUC:   %.4f (%.1f%% degradation)\n\n",
              comparison$repeated_cv_auc[i], comparison$degradation_repeated[i]))
}

cat("INTERPRETATION:\n")
avg_degradation <- mean(c(comparison$degradation_5fold, comparison$degradation_10fold), na.rm = TRUE)
cat(sprintf("  Average AUC degradation: %.1f%%\n", avg_degradation))
if (avg_degradation < 5) {
  cat("  ✓ EXCELLENT: Very low overfitting, models generalize well\n")
} else if (avg_degradation < 10) {
  cat("  ✓ GOOD: Acceptable overfitting, models generalize reasonably\n")
} else if (avg_degradation < 15) {
  cat("  ⚠ MODERATE: Some overfitting, use caution in out-of-sample prediction\n")
} else {
  cat("  ⚠ HIGH: Significant overfitting, models may not generalize well\n")
}

cat("\n===========================================================================\n")
cat(sprintf("Completed: %s\n", Sys.time()))
cat("===========================================================================\n\n")
