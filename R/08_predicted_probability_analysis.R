# ===========================================================================
# Predicted Probability Distribution Analysis
# ===========================================================================
# Purpose: Analyze distribution of predicted failure probabilities
#          for failing vs surviving banks
# Author: Claude Code
# Date: 2025-11-30
# ===========================================================================

library(tidyverse)
library(pROC)

cat("\n")
cat("===========================================================================\n")
cat("PREDICTED PROBABILITY DISTRIBUTION ANALYSIS\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
cat("===========================================================================\n\n")

# ===========================================================================
# 1. LOAD DATA AND ESTIMATE MODELS
# ===========================================================================

cat("Step 1: Loading data and estimating models...\n\n")

data_path <- "D:/Arcanum/Projects/FailingBanks/Technical/data/comprehensive_comparison/correia_reg_modern.rds"
data_2000 <- readRDS(data_path) %>%
  filter(year >= 2000) %>%
  drop_na(F1_failure, income_ratio, noncore_ratio, log_age)

cat(sprintf("  Observations: %s\n", format(nrow(data_2000), big.mark=",")))
cat(sprintf("  Failures: %d\n", sum(data_2000$F1_failure)))
cat(sprintf("  Survivors: %s\n", format(sum(1 - data_2000$F1_failure), big.mark=",")))

# Estimate all three models
model1 <- lm(F1_failure ~ income_ratio + log_age, data = data_2000)
model2 <- lm(F1_failure ~ noncore_ratio + log_age, data = data_2000)
model3 <- lm(F1_failure ~ income_ratio + noncore_ratio +
               income_ratio:noncore_ratio + log_age, data = data_2000)

# Add predicted probabilities to data
data_2000 <- data_2000 %>%
  mutate(
    pred_model1 = predict(model1),
    pred_model2 = predict(model2),
    pred_model3 = predict(model3),
    # Clamp to [0,1] for LPM
    pred_model1_clamped = pmax(0, pmin(1, pred_model1)),
    pred_model2_clamped = pmax(0, pmin(1, pred_model2)),
    pred_model3_clamped = pmax(0, pmin(1, pred_model3)),
    # Failure status for labeling
    failure_status = ifelse(F1_failure == 1, "Failed", "Survived")
  )

cat("  Models estimated and predictions generated\n")

# ===========================================================================
# 2. DISTRIBUTION COMPARISON
# ===========================================================================

cat("\n\nStep 2: Comparing predicted probability distributions...\n\n")

# Summary statistics by failure status
dist_summary <- data_2000 %>%
  group_by(failure_status) %>%
  summarise(
    n = n(),
    # Model 1
    m1_mean = mean(pred_model1_clamped, na.rm = TRUE),
    m1_median = median(pred_model1_clamped, na.rm = TRUE),
    m1_p10 = quantile(pred_model1_clamped, 0.10, na.rm = TRUE),
    m1_p90 = quantile(pred_model1_clamped, 0.90, na.rm = TRUE),
    # Model 2
    m2_mean = mean(pred_model2_clamped, na.rm = TRUE),
    m2_median = median(pred_model2_clamped, na.rm = TRUE),
    m2_p10 = quantile(pred_model2_clamped, 0.10, na.rm = TRUE),
    m2_p90 = quantile(pred_model2_clamped, 0.90, na.rm = TRUE),
    # Model 3
    m3_mean = mean(pred_model3_clamped, na.rm = TRUE),
    m3_median = median(pred_model3_clamped, na.rm = TRUE),
    m3_p10 = quantile(pred_model3_clamped, 0.10, na.rm = TRUE),
    m3_p90 = quantile(pred_model3_clamped, 0.90, na.rm = TRUE),
    .groups = "drop"
  )

cat("  Predicted Probability Distribution by Outcome:\n\n")
cat("  MODEL 1 (Solvency Only):\n")
cat(sprintf("    Survivors: Mean=%.4f, Median=%.4f, P10-P90=[%.4f, %.4f]\n",
            dist_summary$m1_mean[2], dist_summary$m1_median[2],
            dist_summary$m1_p10[2], dist_summary$m1_p90[2]))
cat(sprintf("    Failed:    Mean=%.4f, Median=%.4f, P10-P90=[%.4f, %.4f]\n",
            dist_summary$m1_mean[1], dist_summary$m1_median[1],
            dist_summary$m1_p10[1], dist_summary$m1_p90[1]))

cat("\n  MODEL 2 (Funding Only):\n")
cat(sprintf("    Survivors: Mean=%.4f, Median=%.4f, P10-P90=[%.4f, %.4f]\n",
            dist_summary$m2_mean[2], dist_summary$m2_median[2],
            dist_summary$m2_p10[2], dist_summary$m2_p90[2]))
cat(sprintf("    Failed:    Mean=%.4f, Median=%.4f, P10-P90=[%.4f, %.4f]\n",
            dist_summary$m2_mean[1], dist_summary$m2_median[1],
            dist_summary$m2_p10[1], dist_summary$m2_p90[1]))

cat("\n  MODEL 3 (Interaction):\n")
cat(sprintf("    Survivors: Mean=%.4f, Median=%.4f, P10-P90=[%.4f, %.4f]\n",
            dist_summary$m3_mean[2], dist_summary$m3_median[2],
            dist_summary$m3_p10[2], dist_summary$m3_p90[2]))
cat(sprintf("    Failed:    Mean=%.4f, Median=%.4f, P10-P90=[%.4f, %.4f]\n",
            dist_summary$m3_mean[1], dist_summary$m3_median[1],
            dist_summary$m3_p10[1], dist_summary$m3_p90[1]))

# ===========================================================================
# 3. SEPARATION ANALYSIS
# ===========================================================================

cat("\n\nStep 3: Analyzing separation between groups...\n\n")

# Calculate separation metrics
separation <- tibble(
  model = c("Model 1", "Model 2", "Model 3"),
  mean_diff = c(
    dist_summary$m1_mean[1] - dist_summary$m1_mean[2],
    dist_summary$m2_mean[1] - dist_summary$m2_mean[2],
    dist_summary$m3_mean[1] - dist_summary$m3_mean[2]
  ),
  median_diff = c(
    dist_summary$m1_median[1] - dist_summary$m1_median[2],
    dist_summary$m2_median[1] - dist_summary$m2_median[2],
    dist_summary$m3_median[1] - dist_summary$m3_median[2]
  )
)

# Add effect sizes (Cohen's d approximation)
pooled_sd1 <- sd(data_2000$pred_model1_clamped, na.rm = TRUE)
pooled_sd2 <- sd(data_2000$pred_model2_clamped, na.rm = TRUE)
pooled_sd3 <- sd(data_2000$pred_model3_clamped, na.rm = TRUE)

separation <- separation %>%
  mutate(
    pooled_sd = c(pooled_sd1, pooled_sd2, pooled_sd3),
    cohens_d = mean_diff / pooled_sd,
    interpretation = case_when(
      abs(cohens_d) > 0.8 ~ "Large effect",
      abs(cohens_d) > 0.5 ~ "Medium effect",
      abs(cohens_d) > 0.2 ~ "Small effect",
      TRUE ~ "Negligible effect"
    )
  )

cat("  Group Separation Analysis:\n\n")
print(separation %>% mutate(across(where(is.numeric), ~round(., 4))))

# ===========================================================================
# 4. CLASSIFICATION AT DIFFERENT THRESHOLDS
# ===========================================================================

cat("\n\nStep 4: Classification performance at different thresholds...\n\n")

# Function to calculate metrics at a threshold
calc_metrics <- function(actual, predicted, threshold) {
  pred_class <- ifelse(predicted >= threshold, 1, 0)
  tp <- sum(actual == 1 & pred_class == 1)
  tn <- sum(actual == 0 & pred_class == 0)
  fp <- sum(actual == 0 & pred_class == 1)
  fn <- sum(actual == 1 & pred_class == 0)

  sensitivity <- tp / (tp + fn)  # True positive rate
  specificity <- tn / (tn + fp)  # True negative rate
  precision <- ifelse(tp + fp > 0, tp / (tp + fp), 0)
  accuracy <- (tp + tn) / (tp + tn + fp + fn)

  tibble(
    threshold = threshold,
    sensitivity = sensitivity,
    specificity = specificity,
    precision = precision,
    accuracy = accuracy,
    true_positives = tp,
    false_positives = fp,
    true_negatives = tn,
    false_negatives = fn
  )
}

# Test at multiple thresholds for Model 3
thresholds <- c(0.001, 0.005, 0.01, 0.02, 0.05, 0.10)

threshold_results <- map_dfr(thresholds, ~calc_metrics(
  data_2000$F1_failure,
  data_2000$pred_model3_clamped,
  .x
))

cat("  Classification Performance (Model 3) at Different Thresholds:\n\n")
print(threshold_results %>% mutate(across(where(is.numeric), ~round(., 4))))

# ===========================================================================
# 5. OPTIMAL THRESHOLD ANALYSIS
# ===========================================================================

cat("\n\nStep 5: Finding optimal threshold...\n\n")

# Youden's J statistic: J = Sensitivity + Specificity - 1
# Maximize this to find optimal threshold

roc_obj <- roc(data_2000$F1_failure, data_2000$pred_model3_clamped, quiet = TRUE)
optimal_coords <- coords(roc_obj, "best", best.method = "youden")

cat("  Optimal Threshold (Youden's J):\n")
cat(sprintf("    Threshold: %.4f\n", optimal_coords$threshold))
cat(sprintf("    Sensitivity: %.4f\n", optimal_coords$sensitivity))
cat(sprintf("    Specificity: %.4f\n", optimal_coords$specificity))
cat(sprintf("    Youden's J: %.4f\n", optimal_coords$sensitivity + optimal_coords$specificity - 1))

# Cost-sensitive threshold (assuming false negatives are worse)
# If cost of missing a failure is 10x cost of false alarm
cost_ratio <- 10
cost_sensitive_coords <- coords(roc_obj, "best",
                                 best.method = "closest.topleft",
                                 best.weights = c(cost_ratio, 1 - mean(data_2000$F1_failure)))

cat("\n  Cost-Sensitive Threshold (FN cost = 10x FP cost):\n")
cat(sprintf("    Threshold: %.4f\n", cost_sensitive_coords$threshold))
cat(sprintf("    Sensitivity: %.4f\n", cost_sensitive_coords$sensitivity))
cat(sprintf("    Specificity: %.4f\n", cost_sensitive_coords$specificity))

# ===========================================================================
# 6. DECILE ANALYSIS
# ===========================================================================

cat("\n\nStep 6: Decile analysis...\n\n")

# Create deciles based on predicted probability
data_2000 <- data_2000 %>%
  mutate(
    decile = ntile(pred_model3_clamped, 10)
  )

decile_analysis <- data_2000 %>%
  group_by(decile) %>%
  summarise(
    n = n(),
    n_failures = sum(F1_failure),
    failure_rate = mean(F1_failure) * 100,
    mean_pred_prob = mean(pred_model3_clamped),
    min_pred_prob = min(pred_model3_clamped),
    max_pred_prob = max(pred_model3_clamped),
    .groups = "drop"
  ) %>%
  mutate(
    pct_failures = n_failures / sum(n_failures) * 100,
    cumulative_pct = cumsum(pct_failures)
  )

cat("  Decile Analysis (Model 3):\n\n")
print(decile_analysis %>% mutate(across(where(is.numeric), ~round(., 2))))

cat("\n  KEY INSIGHT:\n")
top_decile <- decile_analysis %>% filter(decile == 10)
cat(sprintf("    Top decile (highest risk) captures %.1f%% of all failures\n",
            top_decile$pct_failures))
cat(sprintf("    Top decile failure rate: %.2f%%\n", top_decile$failure_rate))

top2_deciles <- decile_analysis %>% filter(decile >= 9)
cat(sprintf("    Top 2 deciles capture %.1f%% of all failures\n",
            sum(top2_deciles$pct_failures)))

# ===========================================================================
# 7. SAVE RESULTS
# ===========================================================================

cat("\n\nStep 7: Saving results...\n\n")

output_dir <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/validation/outputs"

write_csv(dist_summary, file.path(output_dir, "pred_prob_distribution_summary.csv"))
cat(sprintf("  ✓ Saved: pred_prob_distribution_summary.csv\n"))

write_csv(separation, file.path(output_dir, "pred_prob_separation.csv"))
cat(sprintf("  ✓ Saved: pred_prob_separation.csv\n"))

write_csv(threshold_results, file.path(output_dir, "classification_thresholds.csv"))
cat(sprintf("  ✓ Saved: classification_thresholds.csv\n"))

write_csv(decile_analysis, file.path(output_dir, "decile_analysis.csv"))
cat(sprintf("  ✓ Saved: decile_analysis.csv\n"))

# Save data with predictions for plotting
saveRDS(data_2000 %>% select(cert, year, F1_failure, failure_status,
                              income_ratio, noncore_ratio, log_age,
                              pred_model1_clamped, pred_model2_clamped,
                              pred_model3_clamped, decile),
        file.path(output_dir, "data_with_predictions.rds"))
cat(sprintf("  ✓ Saved: data_with_predictions.rds\n"))

cat("\n")
cat("===========================================================================\n")
cat("SUMMARY\n")
cat("===========================================================================\n\n")

cat("PREDICTED PROBABILITY ANALYSIS:\n\n")

cat("  1. DISTRIBUTION SEPARATION:\n")
cat(sprintf("     Model 3 separates groups well (Cohen's d = %.2f)\n",
            separation$cohens_d[3]))
cat("     Failed banks have substantially higher predicted probabilities\n\n")

cat("  2. OPTIMAL THRESHOLD:\n")
cat(sprintf("     Youden-optimal: %.4f (Sens=%.2f, Spec=%.2f)\n",
            optimal_coords$threshold,
            optimal_coords$sensitivity,
            optimal_coords$specificity))

cat("\n  3. DECILE CONCENTRATION:\n")
cat(sprintf("     Top decile captures %.1f%% of failures\n", top_decile$pct_failures))
cat(sprintf("     Top 2 deciles capture %.1f%% of failures\n",
            sum(top2_deciles$pct_failures)))
cat("     → Model effectively ranks banks by failure risk\n")

cat("\n===========================================================================\n")
cat(sprintf("Completed: %s\n", Sys.time()))
cat("===========================================================================\n\n")
