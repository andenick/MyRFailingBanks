# ===========================================================================
# Marginal Effects at Representative Values
# ===========================================================================
# Purpose: Compute marginal effects of income_ratio and noncore_ratio
#          at various percentiles of the other variable
# Author: Claude Code
# Date: 2025-11-30
# ===========================================================================

library(tidyverse)

cat("\n")
cat("===========================================================================\n")
cat("MARGINAL EFFECTS AT REPRESENTATIVE VALUES\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
cat("===========================================================================\n\n")

# ===========================================================================
# 1. LOAD DATA AND ESTIMATE MODEL
# ===========================================================================

cat("Step 1: Loading data and estimating Model 3...\n\n")

data_path <- "D:/Arcanum/Projects/FailingBanks/Technical/data/comprehensive_comparison/correia_reg_modern.rds"
data_2000 <- readRDS(data_path) %>%
  filter(year >= 2000) %>%
  drop_na(F1_failure, income_ratio, noncore_ratio, log_age)

# Estimate Model 3 (Interaction)
model3 <- lm(F1_failure ~ income_ratio + noncore_ratio +
               income_ratio:noncore_ratio + log_age,
             data = data_2000)

cat("  Model 3 (Interaction) estimated:\n\n")
print(summary(model3)$coefficients)

# Extract coefficients
beta_income <- coef(model3)["income_ratio"]
beta_noncore <- coef(model3)["noncore_ratio"]
beta_interaction <- coef(model3)["income_ratio:noncore_ratio"]

cat(sprintf("\n  Key coefficients:\n"))
cat(sprintf("    β_income: %.6f\n", beta_income))
cat(sprintf("    β_noncore: %.6f\n", beta_noncore))
cat(sprintf("    β_interaction: %.6f\n", beta_interaction))

# ===========================================================================
# 2. COMPUTE DISTRIBUTION PERCENTILES
# ===========================================================================

cat("\n\nStep 2: Computing variable distributions...\n\n")

# Percentiles for both variables
percentiles <- c(0.10, 0.25, 0.50, 0.75, 0.90)

income_pctiles <- quantile(data_2000$income_ratio, percentiles, na.rm = TRUE)
noncore_pctiles <- quantile(data_2000$noncore_ratio, percentiles, na.rm = TRUE)

cat("  Income Ratio Distribution:\n")
cat(sprintf("    Mean: %.4f\n", mean(data_2000$income_ratio, na.rm = TRUE)))
cat(sprintf("    SD: %.4f\n", sd(data_2000$income_ratio, na.rm = TRUE)))
for (i in seq_along(percentiles)) {
  cat(sprintf("    P%d: %.4f\n", percentiles[i]*100, income_pctiles[i]))
}

cat("\n  Noncore Ratio Distribution:\n")
cat(sprintf("    Mean: %.4f\n", mean(data_2000$noncore_ratio, na.rm = TRUE)))
cat(sprintf("    SD: %.4f\n", sd(data_2000$noncore_ratio, na.rm = TRUE)))
for (i in seq_along(percentiles)) {
  cat(sprintf("    P%d: %.4f\n", percentiles[i]*100, noncore_pctiles[i]))
}

# ===========================================================================
# 3. MARGINAL EFFECT OF INCOME RATIO
# ===========================================================================

cat("\n\nStep 3: Computing marginal effect of income_ratio...\n\n")

# ME(income_ratio) = β_income + β_interaction × noncore_ratio
# This tells us how much a 1-unit change in income_ratio changes P(failure)
# at different levels of noncore_ratio

me_income <- tibble(
  noncore_percentile = paste0("P", percentiles * 100),
  noncore_value = as.numeric(noncore_pctiles),
  marginal_effect = beta_income + beta_interaction * noncore_value
) %>%
  mutate(
    interpretation = case_when(
      marginal_effect > 0 ~ "Higher income INCREASES failure risk",
      marginal_effect < 0 ~ "Higher income DECREASES failure risk",
      TRUE ~ "No effect"
    ),
    effect_magnitude = abs(marginal_effect)
  )

cat("  Marginal Effect of Income Ratio at Different Noncore Levels:\n\n")
cat("  Formula: ME(income) = β_income + β_interaction × noncore_ratio\n")
cat(sprintf("           ME(income) = %.4f + (%.4f) × noncore_ratio\n\n",
            beta_income, beta_interaction))

print(me_income %>% select(noncore_percentile, noncore_value, marginal_effect, interpretation))

cat("\n  INTERPRETATION:\n")
cat("  - At LOW noncore levels (P10): Income ratio effect is ",
    ifelse(me_income$marginal_effect[1] > 0, "POSITIVE", "NEGATIVE"), "\n")
cat("  - At HIGH noncore levels (P90): Income ratio effect is ",
    ifelse(me_income$marginal_effect[5] > 0, "POSITIVE", "NEGATIVE"), "\n")

# Find the threshold where ME crosses zero
threshold_noncore <- -beta_income / beta_interaction
cat(sprintf("\n  Threshold noncore_ratio where ME(income) = 0: %.4f\n", threshold_noncore))
cat(sprintf("  This corresponds to approximately P%.0f of the distribution\n",
            ecdf(data_2000$noncore_ratio)(threshold_noncore) * 100))

# ===========================================================================
# 4. MARGINAL EFFECT OF NONCORE RATIO
# ===========================================================================

cat("\n\nStep 4: Computing marginal effect of noncore_ratio...\n\n")

# ME(noncore_ratio) = β_noncore + β_interaction × income_ratio
# This tells us how much a 1-unit change in noncore_ratio changes P(failure)
# at different levels of income_ratio

me_noncore <- tibble(
  income_percentile = paste0("P", percentiles * 100),
  income_value = as.numeric(income_pctiles),
  marginal_effect = beta_noncore + beta_interaction * income_value
) %>%
  mutate(
    interpretation = case_when(
      marginal_effect > 0 ~ "Higher noncore INCREASES failure risk",
      marginal_effect < 0 ~ "Higher noncore DECREASES failure risk",
      TRUE ~ "No effect"
    ),
    effect_magnitude = abs(marginal_effect)
  )

cat("  Marginal Effect of Noncore Ratio at Different Income Levels:\n\n")
cat("  Formula: ME(noncore) = β_noncore + β_interaction × income_ratio\n")
cat(sprintf("           ME(noncore) = %.4f + (%.4f) × income_ratio\n\n",
            beta_noncore, beta_interaction))

print(me_noncore %>% select(income_percentile, income_value, marginal_effect, interpretation))

cat("\n  INTERPRETATION:\n")
cat("  - At LOW income levels (P10, unprofitable banks): Noncore effect is ",
    ifelse(me_noncore$marginal_effect[1] > 0, "POSITIVE (more risky)", "NEGATIVE"), "\n")
cat("  - At HIGH income levels (P90, profitable banks): Noncore effect is ",
    ifelse(me_noncore$marginal_effect[5] > 0, "POSITIVE", "NEGATIVE (less risky)"), "\n")

# Find the threshold where ME crosses zero
threshold_income <- -beta_noncore / beta_interaction
cat(sprintf("\n  Threshold income_ratio where ME(noncore) = 0: %.4f\n", threshold_income))
cat(sprintf("  This corresponds to approximately P%.0f of the distribution\n",
            ecdf(data_2000$income_ratio)(threshold_income) * 100))

# ===========================================================================
# 5. CREATE MARGINAL EFFECTS GRID
# ===========================================================================

cat("\n\nStep 5: Creating marginal effects grid (heatmap data)...\n\n")

# Create grid of income x noncore values
income_grid <- seq(quantile(data_2000$income_ratio, 0.05),
                   quantile(data_2000$income_ratio, 0.95),
                   length.out = 20)
noncore_grid <- seq(quantile(data_2000$noncore_ratio, 0.05),
                    quantile(data_2000$noncore_ratio, 0.95),
                    length.out = 20)

me_grid <- expand_grid(
  income_ratio = income_grid,
  noncore_ratio = noncore_grid
) %>%
  mutate(
    # Predicted probability (at mean log_age)
    mean_log_age = mean(data_2000$log_age, na.rm = TRUE),
    predicted_prob = coef(model3)["(Intercept)"] +
      beta_income * income_ratio +
      beta_noncore * noncore_ratio +
      beta_interaction * income_ratio * noncore_ratio +
      coef(model3)["log_age"] * mean_log_age,
    # Marginal effects
    me_income = beta_income + beta_interaction * noncore_ratio,
    me_noncore = beta_noncore + beta_interaction * income_ratio
  )

cat("  Marginal effects grid created (20 x 20 = 400 cells)\n")

# Summary statistics
cat("\n  Predicted Probability Range:\n")
cat(sprintf("    Min: %.4f\n", min(me_grid$predicted_prob)))
cat(sprintf("    Max: %.4f\n", max(me_grid$predicted_prob)))
cat(sprintf("    Mean: %.4f\n", mean(me_grid$predicted_prob)))

# ===========================================================================
# 6. ECONOMIC INTERPRETATION
# ===========================================================================

cat("\n\nStep 6: Economic interpretation...\n\n")

cat("  THE SOLVENCY-FUNDING INTERACTION:\n")
cat("  =================================\n\n")

cat("  1. MAIN EFFECT OF INCOME (Solvency):\n")
cat(sprintf("     β_income = %.4f\n", beta_income))
cat("     Interpretation: Positive base effect suggests income alone\n")
cat("     doesn't reduce failure risk (counterintuitive without interaction)\n\n")

cat("  2. MAIN EFFECT OF NONCORE (Funding Fragility):\n")
cat(sprintf("     β_noncore = %.4f\n", beta_noncore))
cat("     Interpretation: Higher noncore funding increases failure risk\n\n")

cat("  3. INTERACTION EFFECT:\n")
cat(sprintf("     β_interaction = %.4f\n", beta_interaction))
cat("     Interpretation: NEGATIVE interaction means:\n")
cat("     - Profitability PROTECTS against funding fragility\n")
cat("     - The protective effect is LARGER for banks with high noncore\n\n")

cat("  4. COMBINED INTERPRETATION:\n")
cat("     For a bank with HIGH noncore funding (P90 = %.2f):\n", noncore_pctiles[5])
cat(sprintf("       ME(income) = %.4f + (%.4f)(%.2f) = %.4f\n",
            beta_income, beta_interaction, noncore_pctiles[5],
            beta_income + beta_interaction * noncore_pctiles[5]))
cat("       → Higher profitability STRONGLY reduces failure probability\n\n")

cat("     For a bank with LOW noncore funding (P10 = %.2f):\n", noncore_pctiles[1])
cat(sprintf("       ME(income) = %.4f + (%.4f)(%.2f) = %.4f\n",
            beta_income, beta_interaction, noncore_pctiles[1],
            beta_income + beta_interaction * noncore_pctiles[1]))
cat("       → Profitability effect is weaker (funding already stable)\n\n")

cat("  KEY INSIGHT:\n")
cat("  Profitability is most protective for banks with fragile funding.\n")
cat("  This explains why funding-reliant banks (like SVB) failed despite\n")
cat("  appearing profitable - small income shocks can't offset funding runs.\n")

# ===========================================================================
# 7. SAVE RESULTS
# ===========================================================================

cat("\n\nStep 7: Saving results...\n\n")

output_dir <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/validation/outputs"

write_csv(me_income, file.path(output_dir, "marginal_effects_income.csv"))
cat(sprintf("  ✓ Saved: marginal_effects_income.csv\n"))

write_csv(me_noncore, file.path(output_dir, "marginal_effects_noncore.csv"))
cat(sprintf("  ✓ Saved: marginal_effects_noncore.csv\n"))

write_csv(me_grid, file.path(output_dir, "marginal_effects_grid.csv"))
cat(sprintf("  ✓ Saved: marginal_effects_grid.csv\n"))

# Save summary
me_summary <- tibble(
  coefficient = c("income_ratio", "noncore_ratio", "interaction"),
  estimate = c(beta_income, beta_noncore, beta_interaction),
  threshold_value = c(threshold_noncore, threshold_income, NA),
  threshold_percentile = c(
    ecdf(data_2000$noncore_ratio)(threshold_noncore) * 100,
    ecdf(data_2000$income_ratio)(threshold_income) * 100,
    NA
  )
)
write_csv(me_summary, file.path(output_dir, "marginal_effects_summary.csv"))
cat(sprintf("  ✓ Saved: marginal_effects_summary.csv\n"))

cat("\n")
cat("===========================================================================\n")
cat("SUMMARY\n")
cat("===========================================================================\n\n")

cat("MARGINAL EFFECTS AT REPRESENTATIVE VALUES:\n\n")

cat("  Effect of Income Ratio (profitability):\n")
for (i in 1:nrow(me_income)) {
  cat(sprintf("    At %s noncore (%.2f): ME = %+.4f %s\n",
              me_income$noncore_percentile[i],
              me_income$noncore_value[i],
              me_income$marginal_effect[i],
              ifelse(me_income$marginal_effect[i] < 0, "(protective)", "(risk-increasing)")))
}

cat("\n  Effect of Noncore Ratio (funding fragility):\n")
for (i in 1:nrow(me_noncore)) {
  cat(sprintf("    At %s income (%.4f): ME = %+.4f %s\n",
              me_noncore$income_percentile[i],
              me_noncore$income_value[i],
              me_noncore$marginal_effect[i],
              ifelse(me_noncore$marginal_effect[i] > 0, "(risk-increasing)", "(protective)")))
}

cat("\n===========================================================================\n")
cat(sprintf("Completed: %s\n", Sys.time()))
cat("===========================================================================\n\n")
