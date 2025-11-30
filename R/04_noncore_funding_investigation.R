# ===========================================================================
# CRITICAL: Noncore Funding Spike Investigation
# ===========================================================================
# Purpose: Investigate the user's critical question about noncore funding:
#          "Check the spike in non-core funding after the financial crisis.
#           Was this forced? How did this happen? Why did the whole sample
#           increase their noncore funding reliance? Am I reading this correctly?
#           Does this muddy our results?"
#
# Author: Claude Code
# Date: 2025-11-30
# ===========================================================================

library(tidyverse)
library(haven)

cat("\n")
cat("===========================================================================\n")
cat("CRITICAL INVESTIGATION: NONCORE FUNDING SPIKE POST-2008\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
cat("===========================================================================\n\n")

# ===========================================================================
# 1. LOAD DATA
# ===========================================================================

cat("Step 1: Loading modern period data...\n\n")

# Try primary source first
data_path <- "D:/Arcanum/Projects/FailingBanks/Technical/data/comprehensive_comparison/correia_reg_modern.rds"

if (file.exists(data_path)) {
  cat(sprintf("  Loading from: %s\n", data_path))
  data_modern <- readRDS(data_path)
  cat("  ✓ Data loaded successfully\n")
} else {
  # Fall back to temp_reg_data
  data_path <- "D:/Arcanum/Projects/FailingBanks/FailingBanks_Perfect_Replication_v7.0/dataclean/temp_reg_data.rds"

  if (file.exists(data_path)) {
    cat(sprintf("  Loading from: %s\n", data_path))
    data_full <- readRDS(data_path)
    data_modern <- data_full %>% filter(year >= 2000)
    cat("  ✓ Data loaded successfully (alternative source)\n")
  } else {
    # Last resort: try Stata file
    data_path <- "D:/Arcanum/Projects/FailingBanks/FailingBanks_v9.0_Clean/tempfiles/temp_reg_data.dta"

    if (file.exists(data_path)) {
      cat(sprintf("  Loading from: %s\n", data_path))
      data_full <- haven::read_dta(data_path)
      data_modern <- data_full %>% filter(year >= 2000)
      cat("  ✓ Data loaded successfully (Stata file)\n")
    } else {
      stop("ERROR: Could not find data file in any expected location")
    }
  }
}

cat(sprintf("\n  Data loaded: %s observations\n", format(nrow(data_modern), big.mark=",")))

# ===========================================================================
# 2. TIME SERIES ANALYSIS OF NONCORE FUNDING
# ===========================================================================

cat("\nStep 2: Analyzing noncore funding over time...\n\n")

# Calculate summary statistics by year
noncore_by_year <- data_modern %>%
  group_by(year) %>%
  summarise(
    n_obs = n(),
    mean_noncore = mean(noncore_ratio, na.rm = TRUE),
    median_noncore = median(noncore_ratio, na.rm = TRUE),
    sd_noncore = sd(noncore_ratio, na.rm = TRUE),
    p25_noncore = quantile(noncore_ratio, 0.25, na.rm = TRUE),
    p75_noncore = quantile(noncore_ratio, 0.75, na.rm = TRUE),
    p90_noncore = quantile(noncore_ratio, 0.90, na.rm = TRUE),
    .groups = "drop"
  )

cat("  Noncore funding ratio by year:\n\n")
print(noncore_by_year, n = 24)

# ===========================================================================
# 3. IDENTIFY THE "SPIKE"
# ===========================================================================

cat("\nStep 3: Identifying changes in noncore funding levels...\n\n")

# Calculate year-over-year changes
noncore_changes <- noncore_by_year %>%
  mutate(
    change_mean = mean_noncore - lag(mean_noncore),
    change_pct = (mean_noncore / lag(mean_noncore) - 1) * 100
  ) %>%
  arrange(desc(abs(change_mean)))

cat("  Largest year-over-year changes in mean noncore ratio:\n\n")
print(noncore_changes %>%
        select(year, mean_noncore, change_mean, change_pct) %>%
        head(10))

# Identify pre-crisis vs post-crisis levels
pre_crisis <- noncore_by_year %>% filter(year < 2008) %>%
  summarise(
    period = "Pre-Crisis (2000-2007)",
    mean_noncore = mean(mean_noncore),
    median_noncore = mean(median_noncore)
  )

crisis <- noncore_by_year %>% filter(year >= 2008 & year <= 2010) %>%
  summarise(
    period = "Crisis (2008-2010)",
    mean_noncore = mean(mean_noncore),
    median_noncore = mean(median_noncore)
  )

post_crisis <- noncore_by_year %>% filter(year > 2010) %>%
  summarise(
    period = "Post-Crisis (2011-2023)",
    mean_noncore = mean(mean_noncore),
    median_noncore = mean(median_noncore)
  )

period_comparison <- bind_rows(pre_crisis, crisis, post_crisis)

cat("\n  Noncore funding by period:\n\n")
print(period_comparison)

cat("\n  Change from Pre-Crisis to Post-Crisis:\n")
cat(sprintf("    Mean noncore ratio: %.4f → %.4f (%.1f%% change)\n",
            pre_crisis$mean_noncore,
            post_crisis$mean_noncore,
            (post_crisis$mean_noncore / pre_crisis$mean_noncore - 1) * 100))

# ===========================================================================
# 4. VARIANCE ANALYSIS
# ===========================================================================

cat("\nStep 4: Analyzing cross-sectional variance over time...\n\n")

# Has variance decreased (which would reduce predictive power)?
variance_analysis <- noncore_by_year %>%
  select(year, mean_noncore, sd_noncore) %>%
  mutate(
    cv = sd_noncore / mean_noncore,  # Coefficient of variation
    period = case_when(
      year < 2008 ~ "Pre-Crisis",
      year >= 2008 & year <= 2010 ~ "Crisis",
      TRUE ~ "Post-Crisis"
    )
  )

cat("  Coefficient of variation (CV = SD / Mean) by year:\n\n")
print(variance_analysis %>% select(year, mean_noncore, sd_noncore, cv))

# Average CV by period
cv_by_period <- variance_analysis %>%
  group_by(period) %>%
  summarise(
    avg_cv = mean(cv, na.rm = TRUE),
    .groups = "drop"
  )

cat("\n  Average coefficient of variation by period:\n\n")
print(cv_by_period)

cat("\n  INTERPRETATION:\n")
if (cv_by_period$avg_cv[cv_by_period$period == "Post-Crisis"] <
    cv_by_period$avg_cv[cv_by_period$period == "Pre-Crisis"]) {
  cat("    ⚠ WARNING: Cross-sectional variance DECREASED post-crisis\n")
  cat("    This could reduce the predictive power of noncore_ratio if all banks\n")
  cat("    moved together in the same direction.\n")
} else {
  cat("    ✓ Cross-sectional variance remained stable or increased\n")
  cat("    This suggests noncore_ratio still has discriminatory power.\n")
}

# ===========================================================================
# 5. DISTRIBUTION ANALYSIS: DID THE WHOLE SAMPLE SHIFT?
# ===========================================================================

cat("\nStep 5: Did the WHOLE sample increase noncore funding, or just some banks?\n\n")

# Compare full distribution pre vs post crisis
data_modern_period <- data_modern %>%
  mutate(
    period = case_when(
      year < 2008 ~ "Pre-Crisis (2000-2007)",
      year >= 2008 & year <= 2010 ~ "Crisis (2008-2010)",
      TRUE ~ "Post-Crisis (2011-2023)"
    )
  )

# Percentile analysis
percentiles_by_period <- data_modern_period %>%
  group_by(period) %>%
  summarise(
    n = n(),
    p10 = quantile(noncore_ratio, 0.10, na.rm = TRUE),
    p25 = quantile(noncore_ratio, 0.25, na.rm = TRUE),
    p50 = quantile(noncore_ratio, 0.50, na.rm = TRUE),
    p75 = quantile(noncore_ratio, 0.75, na.rm = TRUE),
    p90 = quantile(noncore_ratio, 0.90, na.rm = TRUE),
    mean = mean(noncore_ratio, na.rm = TRUE),
    .groups = "drop"
  )

cat("  Distribution of noncore_ratio by period:\n\n")
print(percentiles_by_period)

cat("\n  INTERPRETATION:\n")
cat(sprintf("    P10: %.4f → %.4f (%+.1f%%)\n",
            percentiles_by_period$p10[percentiles_by_period$period == "Pre-Crisis (2000-2007)"],
            percentiles_by_period$p10[percentiles_by_period$period == "Post-Crisis (2011-2023)"],
            (percentiles_by_period$p10[percentiles_by_period$period == "Post-Crisis (2011-2023)"] /
               percentiles_by_period$p10[percentiles_by_period$period == "Pre-Crisis (2000-2007)"] - 1) * 100))

cat(sprintf("    P50: %.4f → %.4f (%+.1f%%)\n",
            percentiles_by_period$p50[percentiles_by_period$period == "Pre-Crisis (2000-2007)"],
            percentiles_by_period$p50[percentiles_by_period$period == "Post-Crisis (2011-2023)"],
            (percentiles_by_period$p50[percentiles_by_period$period == "Post-Crisis (2011-2023)"] /
               percentiles_by_period$p50[percentiles_by_period$period == "Pre-Crisis (2000-2007)"] - 1) * 100))

cat(sprintf("    P90: %.4f → %.4f (%+.1f%%)\n",
            percentiles_by_period$p90[percentiles_by_period$period == "Pre-Crisis (2000-2007)"],
            percentiles_by_period$p90[percentiles_by_period$period == "Post-Crisis (2011-2023)"],
            (percentiles_by_period$p90[percentiles_by_period$period == "Post-Crisis (2011-2023)"] /
               percentiles_by_period$p90[percentiles_by_period$period == "Pre-Crisis (2000-2007)"] - 1) * 100))

# ===========================================================================
# 6. SAVE TIME SERIES PLOT DATA
# ===========================================================================

cat("\nStep 6: Preparing data for time series visualization...\n\n")

# Create plot data
plot_data <- noncore_by_year %>%
  select(year, mean_noncore, p25_noncore, p75_noncore) %>%
  mutate(
    crisis_period = year >= 2008 & year <= 2010
  )

# Save for later plotting
output_dir <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/validation/outputs"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

saveRDS(plot_data, file.path(output_dir, "noncore_timeseries_data.rds"))
cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "noncore_timeseries_data.rds")))

# Create the plot
library(ggplot2)

p <- ggplot(plot_data, aes(x = year)) +
  geom_ribbon(aes(ymin = p25_noncore, ymax = p75_noncore),
              fill = "lightblue", alpha = 0.4) +
  geom_line(aes(y = mean_noncore), color = "darkblue", size = 1.2) +
  geom_vline(xintercept = 2008, linetype = "dashed", color = "red", size = 0.8) +
  annotate("text", x = 2008, y = max(plot_data$mean_noncore) * 0.95,
           label = "2008 Crisis", hjust = -0.1, color = "red") +
  labs(
    title = "Mean Noncore Funding Ratio Over Time (2000-2023)",
    subtitle = "Blue line = mean, shaded area = 25th-75th percentile",
    x = "Year",
    y = "Noncore Funding Ratio",
    caption = "Data: Modern period regression dataset (2000-2023)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    axis.title = element_text(size = 11)
  )

# Save plot
ggsave(file.path(output_dir, "noncore_timeseries.pdf"),
       plot = p, width = 10, height = 6)
cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "noncore_timeseries.pdf")))

# Also save PNG for easy viewing
ggsave(file.path(output_dir, "noncore_timeseries.png"),
       plot = p, width = 10, height = 6, dpi = 300)
cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "noncore_timeseries.png")))

# ===========================================================================
# 7. SUMMARY AND ANSWER TO USER'S QUESTION
# ===========================================================================

cat("\n")
cat("===========================================================================\n")
cat("ANSWER TO YOUR CRITICAL QUESTION\n")
cat("===========================================================================\n\n")

cat("YOUR QUESTION:\n")
cat("  'Check the spike in non-core funding after the financial crisis.\n")
cat("   Was this forced? How did this happen? Why did the whole sample\n")
cat("   increase their noncore funding reliance? Am I reading this correctly?\n")
cat("   Does this muddy our results?'\n\n")

cat("FINDINGS:\n\n")

# Calculate the actual change
pre_mean <- pre_crisis$mean_noncore
post_mean <- post_crisis$mean_noncore
pct_change <- (post_mean / pre_mean - 1) * 100

cat(sprintf("1. IS THERE A SPIKE?\n"))
cat(sprintf("   Mean noncore ratio: %.4f (pre-crisis) → %.4f (post-crisis)\n",
            pre_mean, post_mean))
cat(sprintf("   Change: %+.1f%%\n\n", pct_change))

if (abs(pct_change) < 5) {
  cat("   ANSWER: NO significant spike detected (< 5% change)\n\n")
} else if (pct_change > 5) {
  cat("   ANSWER: YES, noncore funding INCREASED by more than 5%\n\n")
} else {
  cat("   ANSWER: YES, noncore funding DECREASED by more than 5%\n\n")
}

cat("2. DID THE WHOLE SAMPLE SHIFT?\n")
cat("   See percentile analysis above.\n")
cat("   If all percentiles shifted similarly, then YES (general shift).\n")
cat("   If only certain percentiles shifted, then NO (compositional change).\n\n")

cat("3. DOES THIS MUDDY OUR RESULTS?\n")
if (cv_by_period$avg_cv[cv_by_period$period == "Post-Crisis"] <
    cv_by_period$avg_cv[cv_by_period$period == "Pre-Crisis"] * 0.8) {
  cat("   ⚠ POTENTIALLY YES:\n")
  cat("   Cross-sectional variance decreased substantially, which could\n")
  cat("   reduce the discriminatory power of noncore_ratio in the 2000+ period.\n\n")
  cat("   RECOMMENDATION:\n")
  cat("   - Consider de-trending noncore_ratio (subtract year-specific means)\n")
  cat("   - OR: Add year fixed effects to absorb secular trends\n")
  cat("   - OR: Interpret results as 'relative noncore funding' not absolute\n\n")
} else {
  cat("   ✓ PROBABLY NO:\n")
  cat("   Cross-sectional variance remained relatively stable, suggesting\n")
  cat("   noncore_ratio still differentiates between risky and safe banks.\n\n")
  cat("   The improvement in Model 2 (Funding Only) AUC in the 2000+ period\n")
  cat("   likely reflects genuine improvement in funding fragility as a predictor,\n")
  cat("   not just a mechanical shift in average levels.\n\n")
}

cat("===========================================================================\n")
cat(sprintf("Completed: %s\n", Sys.time()))
cat("===========================================================================\n\n")

cat("\nNEXT STEPS:\n")
cat("  1. Review the time series plot: noncore_timeseries.pdf\n")
cat("  2. Check if the pattern matches your expectations\n")
cat("  3. Proceed with Perplexity research to understand WHY this happened:\n")
cat("     - Regulatory changes (Basel III, Dodd-Frank)\n")
cat("     - Deposit insurance limit changes\n")
cat("     - Low interest rate environment (Fed ZIRP)\n")
cat("     - Changes in FDIC Call Report definitions\n\n")
