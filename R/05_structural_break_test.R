# ===========================================================================
# Structural Break Test (Chow Test)
# ===========================================================================
# Purpose: Test for structural break in coefficients at year 2000
# H0: Coefficients are equal across 1959-1999 vs 2000-2023
# H1: Structural break exists at 2000
# Author: Claude Code
# Date: 2025-11-30
# ===========================================================================

library(tidyverse)
library(haven)
library(lmtest)  # For waldtest

cat("\n")
cat("===========================================================================\n")
cat("STRUCTURAL BREAK TEST (CHOW TEST)\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
cat("===========================================================================\n\n")

# ===========================================================================
# 1. LOAD FULL MODERN PERIOD DATA
# ===========================================================================

cat("Step 1: Loading full modern period data...\n\n")

# Load the full modern dataset
data_path <- "D:/Arcanum/Projects/FailingBanks/Technical/data/comprehensive_comparison/correia_reg_modern.rds"

if (!file.exists(data_path)) {
  stop("ERROR: Full modern data file not found")
}

data_full <- readRDS(data_path)

cat(sprintf("  Full dataset: %s observations\n", format(nrow(data_full), big.mark=",")))
cat(sprintf("  Year range: %d - %d\n", min(data_full$year), max(data_full$year)))

# Create period indicator
data_full <- data_full %>%
  mutate(
    period = ifelse(year >= 2000, "post2000", "pre2000"),
    period_dummy = ifelse(year >= 2000, 1, 0)
  )

# Summary by period
period_summary <- data_full %>%
  group_by(period) %>%
  summarise(
    n_obs = n(),
    n_failures = sum(F1_failure, na.rm = TRUE),
    failure_rate = mean(F1_failure, na.rm = TRUE) * 100,
    .groups = "drop"
  )

cat("\n  Period summary:\n")
print(period_summary)

# ===========================================================================
# 2. ESTIMATE POOLED MODEL (RESTRICTED)
# ===========================================================================

cat("\n\nStep 2: Estimating pooled model (restricted - no structural break)...\n\n")

# Model 3 specification: Interaction model
model_pooled <- lm(F1_failure ~ income_ratio + noncore_ratio +
                     income_ratio:noncore_ratio + log_age,
                   data = data_full)

cat("  Pooled model estimated\n")
cat(sprintf("  Observations: %s\n", format(nobs(model_pooled), big.mark=",")))
cat(sprintf("  R-squared: %.4f\n", summary(model_pooled)$r.squared))

# RSS for pooled model
RSS_pooled <- sum(residuals(model_pooled)^2)
cat(sprintf("  RSS (pooled): %.4f\n", RSS_pooled))

# ===========================================================================
# 3. ESTIMATE SEPARATE MODELS BY PERIOD (UNRESTRICTED)
# ===========================================================================

cat("\n\nStep 3: Estimating separate models by period (unrestricted)...\n\n")

# Pre-2000 model
data_pre2000 <- data_full %>% filter(year < 2000)
model_pre2000 <- lm(F1_failure ~ income_ratio + noncore_ratio +
                      income_ratio:noncore_ratio + log_age,
                    data = data_pre2000)

cat("  Pre-2000 model:\n")
cat(sprintf("    Observations: %s\n", format(nobs(model_pre2000), big.mark=",")))
cat(sprintf("    R-squared: %.4f\n", summary(model_pre2000)$r.squared))

RSS_pre2000 <- sum(residuals(model_pre2000)^2)
cat(sprintf("    RSS: %.4f\n", RSS_pre2000))

# Post-2000 model
data_post2000 <- data_full %>% filter(year >= 2000)
model_post2000 <- lm(F1_failure ~ income_ratio + noncore_ratio +
                       income_ratio:noncore_ratio + log_age,
                     data = data_post2000)

cat("\n  Post-2000 model:\n")
cat(sprintf("    Observations: %s\n", format(nobs(model_post2000), big.mark=",")))
cat(sprintf("    R-squared: %.4f\n", summary(model_post2000)$r.squared))

RSS_post2000 <- sum(residuals(model_post2000)^2)
cat(sprintf("    RSS: %.4f\n", RSS_post2000))

# Total RSS unrestricted
RSS_unrestricted <- RSS_pre2000 + RSS_post2000
cat(sprintf("\n  RSS (unrestricted): %.4f\n", RSS_unrestricted))

# ===========================================================================
# 4. CHOW TEST CALCULATION
# ===========================================================================

cat("\n\nStep 4: Computing Chow test statistic...\n\n")

# Number of parameters (including intercept)
k <- length(coef(model_pooled))  # 5 parameters

# Sample sizes
n1 <- nobs(model_pre2000)
n2 <- nobs(model_post2000)
n <- n1 + n2

# Chow F-statistic
# F = [(RSS_pooled - RSS_unrestricted) / k] / [RSS_unrestricted / (n - 2k)]
F_stat <- ((RSS_pooled - RSS_unrestricted) / k) / (RSS_unrestricted / (n - 2*k))

# Degrees of freedom
df1 <- k
df2 <- n - 2*k

# P-value
p_value <- pf(F_stat, df1, df2, lower.tail = FALSE)

cat("  CHOW TEST RESULTS:\n")
cat("  ==================\n\n")
cat(sprintf("  H0: No structural break at year 2000\n"))
cat(sprintf("  H1: Structural break exists at year 2000\n\n"))
cat(sprintf("  F-statistic: %.4f\n", F_stat))
cat(sprintf("  Degrees of freedom: (%d, %s)\n", df1, format(df2, big.mark=",")))
cat(sprintf("  P-value: %.2e\n\n", p_value))

if (p_value < 0.001) {
  cat("  CONCLUSION: *** HIGHLY SIGNIFICANT ***\n")
  cat("  REJECT H0: Strong evidence of structural break at year 2000\n")
} else if (p_value < 0.01) {
  cat("  CONCLUSION: ** SIGNIFICANT **\n")
  cat("  REJECT H0: Evidence of structural break at year 2000\n")
} else if (p_value < 0.05) {
  cat("  CONCLUSION: * SIGNIFICANT *\n")
  cat("  REJECT H0: Moderate evidence of structural break at year 2000\n")
} else {
  cat("  CONCLUSION: NOT SIGNIFICANT\n")
  cat("  FAIL TO REJECT H0: No evidence of structural break\n")
}

# ===========================================================================
# 5. COEFFICIENT COMPARISON
# ===========================================================================

cat("\n\nStep 5: Comparing coefficients across periods...\n\n")

# Extract coefficients
coef_pre <- broom::tidy(model_pre2000) %>%
  select(term, estimate_pre = estimate, se_pre = std.error)

coef_post <- broom::tidy(model_post2000) %>%
  select(term, estimate_post = estimate, se_post = std.error)

coef_comparison <- coef_pre %>%
  left_join(coef_post, by = "term") %>%
  mutate(
    change = estimate_post - estimate_pre,
    pct_change = (estimate_post / estimate_pre - 1) * 100,
    # Wald test for individual coefficient differences
    se_diff = sqrt(se_pre^2 + se_post^2),
    z_stat = change / se_diff,
    p_value_coef = 2 * pnorm(-abs(z_stat))
  )

cat("  Coefficient comparison (Pre-2000 vs Post-2000):\n\n")
print(coef_comparison %>%
        select(term, estimate_pre, estimate_post, change, pct_change, p_value_coef) %>%
        mutate(across(where(is.numeric), ~round(., 4))))

# ===========================================================================
# 6. INTERACTION MODEL FOR STRUCTURAL BREAK
# ===========================================================================

cat("\n\nStep 6: Estimating interaction model with period dummy...\n\n")

# Full interaction model
model_interaction <- lm(F1_failure ~ income_ratio * period_dummy +
                          noncore_ratio * period_dummy +
                          income_ratio:noncore_ratio * period_dummy +
                          log_age * period_dummy,
                        data = data_full)

cat("  Interaction model with period dummy:\n\n")
interaction_results <- broom::tidy(model_interaction) %>%
  filter(grepl("period_dummy", term)) %>%
  select(term, estimate, std.error, statistic, p.value)

print(interaction_results %>% mutate(across(where(is.numeric), ~round(., 4))))

# Joint F-test for all interaction terms
cat("\n\n  Joint F-test for period interactions:\n")

# Use anova to compare restricted vs unrestricted
model_no_interactions <- lm(F1_failure ~ income_ratio + noncore_ratio +
                              income_ratio:noncore_ratio + log_age + period_dummy,
                            data = data_full)

anova_result <- anova(model_no_interactions, model_interaction)
cat(sprintf("    F-statistic: %.4f\n", anova_result$F[2]))
cat(sprintf("    P-value: %.2e\n", anova_result$`Pr(>F)`[2]))

# ===========================================================================
# 7. SAVE RESULTS
# ===========================================================================

cat("\n\nStep 7: Saving results...\n\n")

output_dir <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/validation/outputs"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Save coefficient comparison
write_csv(coef_comparison, file.path(output_dir, "chow_test_coefficient_comparison.csv"))
cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "chow_test_coefficient_comparison.csv")))

# Save test results summary
chow_results <- tibble(
  test = "Chow Test",
  null_hypothesis = "No structural break at year 2000",
  f_statistic = F_stat,
  df1 = df1,
  df2 = df2,
  p_value = p_value,
  conclusion = ifelse(p_value < 0.05, "REJECT H0: Structural break confirmed", "FAIL TO REJECT H0"),
  n_pre2000 = n1,
  n_post2000 = n2,
  rss_pooled = RSS_pooled,
  rss_unrestricted = RSS_unrestricted
)

write_csv(chow_results, file.path(output_dir, "chow_test_results.csv"))
cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "chow_test_results.csv")))

# Save models
saveRDS(list(
  pooled = model_pooled,
  pre2000 = model_pre2000,
  post2000 = model_post2000,
  interaction = model_interaction
), file.path(output_dir, "chow_test_models.rds"))
cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "chow_test_models.rds")))

cat("\n")
cat("===========================================================================\n")
cat("SUMMARY\n")
cat("===========================================================================\n\n")

cat("CHOW TEST FOR STRUCTURAL BREAK AT YEAR 2000\n\n")
cat(sprintf("  F-statistic: %.2f\n", F_stat))
cat(sprintf("  P-value: %.2e\n", p_value))
cat(sprintf("  Conclusion: %s\n\n", ifelse(p_value < 0.05, "STRUCTURAL BREAK CONFIRMED", "NO STRUCTURAL BREAK")))

cat("KEY COEFFICIENT CHANGES (Pre-2000 → Post-2000):\n\n")
for (i in 1:nrow(coef_comparison)) {
  if (coef_comparison$term[i] != "(Intercept)") {
    cat(sprintf("  %s: %.4f → %.4f (%.1f%%)\n",
                coef_comparison$term[i],
                coef_comparison$estimate_pre[i],
                coef_comparison$estimate_post[i],
                coef_comparison$pct_change[i]))
  }
}

cat("\n")
cat("INTERPRETATION:\n")
if (p_value < 0.05) {
  cat("  The Chow test confirms a statistically significant structural break\n")
  cat("  in the relationship between bank characteristics and failure probability\n")
  cat("  at year 2000. This justifies estimating separate models for the\n")
  cat("  pre-2000 and post-2000 periods.\n")
}

cat("\n===========================================================================\n")
cat(sprintf("Completed: %s\n", Sys.time()))
cat("===========================================================================\n\n")
