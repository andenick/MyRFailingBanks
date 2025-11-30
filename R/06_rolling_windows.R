# ===========================================================================
# Rolling Window Coefficient Evolution
# ===========================================================================
# Purpose: Estimate models on rolling 10-year windows to examine coefficient stability
# Author: Claude Code
# Date: 2025-11-30
# ===========================================================================

library(tidyverse)
library(haven)

cat("\n")
cat("===========================================================================\n")
cat("ROLLING WINDOW COEFFICIENT EVOLUTION\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
cat("===========================================================================\n\n")

# Load data
cat("Step 1: Loading data...\n\n")
data_path <- "D:/Arcanum/Projects/FailingBanks/Technical/data/comprehensive_comparison/correia_reg_modern.rds"
data_modern <- readRDS(data_path) %>% filter(year >= 2000)

cat(sprintf("  Data loaded: %s observations (2000-2023)\n\n",
            format(nrow(data_modern), big.mark=",")))

# ===========================================================================
# 2. DEFINE ROLLING WINDOWS
# ===========================================================================

cat("Step 2: Defining rolling 10-year windows...\n\n")

# Create windows: 2000-2010, 2001-2011, ..., 2013-2023
windows <- tibble(
  window_id = 1:14,
  start_year = 2000:2013,
  end_year = 2010:2023
) %>%
  mutate(window_label = paste0(start_year, "-", end_year))

cat("  Rolling windows defined:\n")
print(windows)

# ===========================================================================
# 3. ESTIMATE MODEL 3 FOR EACH WINDOW
# ===========================================================================

cat("\nStep 3: Estimating Model 3 (Interaction) for each window...\n\n")

# Storage for results
coef_evolution <- tibble()

for (i in 1:nrow(windows)) {
  start_yr <- windows$start_year[i]
  end_yr <- windows$end_year[i]
  window_label <- windows$window_label[i]

  cat(sprintf("  Window %d: %s\n", i, window_label))

  # Filter data
  data_window <- data_modern %>%
    filter(year >= start_yr & year <= end_yr)

  # Estimate LPM Model 3
  model <- lm(F1_failure ~ income_ratio + noncore_ratio +
                income_ratio:noncore_ratio + log_age,
              data = data_window)

  # Extract coefficients
  coefs <- broom::tidy(model) %>%
    select(term, estimate, std.error, statistic, p.value) %>%
    mutate(
      window_id = i,
      window_label = window_label,
      midpoint_year = start_yr + 5
    )

  coef_evolution <- bind_rows(coef_evolution, coefs)
}

cat("\n  ✓ Estimation complete\n")

# ===========================================================================
# 4. ANALYZE COEFFICIENT TRENDS
# ===========================================================================

cat("\nStep 4: Analyzing coefficient trends...\n\n")

# Focus on key variables
key_vars <- c("income_ratio", "noncore_ratio", "income_ratio:noncore_ratio")

coef_trends <- coef_evolution %>%
  filter(term %in% key_vars)

cat("  Coefficient evolution (key variables):\n\n")
print(coef_trends %>%
        select(window_label, term, estimate, std.error) %>%
        arrange(term, window_label),
      n = 50)

# ===========================================================================
# 5. PRE-CRISIS VS POST-CRISIS COMPARISON
# ===========================================================================

cat("\nStep 5: Comparing pre-crisis vs post-crisis coefficients...\n\n")

# Pre-crisis: 2000-2008 (window 1)
# Post-crisis: 2009-2023 (window containing 2009-2019)

pre_crisis <- coef_evolution %>%
  filter(window_label == "2000-2010", term %in% key_vars) %>%
  select(term, estimate_pre = estimate, se_pre = std.error)

post_crisis <- coef_evolution %>%
  filter(window_label == "2013-2023", term %in% key_vars) %>%
  select(term, estimate_post = estimate, se_post = std.error)

comparison <- pre_crisis %>%
  left_join(post_crisis, by = "term") %>%
  mutate(
    change = estimate_post - estimate_pre,
    pct_change = (estimate_post / estimate_pre - 1) * 100
  )

cat("  Pre-crisis (2000-2010) vs Post-crisis (2013-2023):\n\n")
print(comparison)

# ===========================================================================
# 6. SAVE RESULTS
# ===========================================================================

cat("\nStep 6: Saving results...\n\n")

output_dir <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/extended_analysis/outputs"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

write_csv(coef_evolution, file.path(output_dir, "rolling_window_coefficients.csv"))
cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "rolling_window_coefficients.csv")))

write_csv(comparison, file.path(output_dir, "prepost_crisis_coefficient_comparison.csv"))
cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "prepost_crisis_coefficient_comparison.csv")))

# Save plot data
saveRDS(coef_trends, file.path(output_dir, "coefficient_evolution_plot_data.rds"))
cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "coefficient_evolution_plot_data.rds")))

cat("\n")
cat("===========================================================================\n")
cat("INTERPRETATION\n")
cat("===========================================================================\n\n")

cat("COEFFICIENT STABILITY:\n\n")

for (var in key_vars) {
  var_data <- coef_trends %>% filter(term == var)
  var_range <- max(var_data$estimate) - min(var_data$estimate)
  var_mean <- mean(var_data$estimate)
  cv <- var_range / abs(var_mean)

  cat(sprintf("  %s:\n", var))
  cat(sprintf("    Range: %.4f to %.4f\n", min(var_data$estimate), max(var_data$estimate)))
  cat(sprintf("    CV: %.2f\n", cv))

  if (cv < 0.2) {
    cat("    ✓ Stable across windows\n\n")
  } else if (cv < 0.5) {
    cat("    ⚠ Moderate variation\n\n")
  } else {
    cat("    ⚠ Substantial variation - evidence of structural change\n\n")
  }
}

cat("===========================================================================\n")
cat(sprintf("Completed: %s\n", Sys.time()))
cat("===========================================================================\n\n")
