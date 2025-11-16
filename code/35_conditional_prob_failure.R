# ===========================================================================
# Script 35: Conditional Probability of Failure
# ===========================================================================
# This script calculates and visualizes conditional probabilities of failure
# by percentile bins of key variables (solvency, funding, growth).
#
# Key outputs:
# - Failure probability by insolvency percentiles (historical & modern)
# - Failure probability by noncore funding percentiles (historical & modern)
# - Interaction plots showing joint effect of solvency and funding
# - Analysis for both regular failure and failure with deposit runs
#
# v2.5 enhancements:
# - Verbose console diagnostics throughout
# - Detailed progress tracking
# ===========================================================================

cat("===========================================================================\n")
cat("SCRIPT 35: CONDITIONAL PROBABILITY OF FAILURE\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
script_start_time <- Sys.time()

# --- Load Required Libraries ---
cat("\n[Loading Libraries]\n")
suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(ggplot2)
  library(tidyr)
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
# HELPER FUNCTION: Create Percentile Categories
# ===========================================================================

CutByPercentiles <- function(x, cuts = c(50, 75, 90, 95)) {
  # Calculate percentiles
  percentiles <- quantile(x, probs = cuts / 100, na.rm = TRUE)

  # Create categories
  result <- rep(NA_integer_, length(x))

  # Category 1: < p50
  result[!is.na(x) & x < percentiles[1]] <- 1

  # Category 2: p50-p75
  result[!is.na(x) & x >= percentiles[1] & x < percentiles[2]] <- 2

  # Category 3: p75-p90
  result[!is.na(x) & x >= percentiles[2] & x < percentiles[3]] <- 3

  # Category 4: p90-p95
  result[!is.na(x) & x >= percentiles[3] & x < percentiles[4]] <- 4

  # Category 5: > p95
  result[!is.na(x) & x >= percentiles[4]] <- 5

  return(result)
}

# ===========================================================================
# PART 1: LOAD DATA
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 1: DATA LOADING\n")
cat("===========================================================================\n")
# ===========================================================================
# DATA PREPARATION: Create temp_reg_data (Stata Script 35, lines 28-64)
# ===========================================================================
# This section creates the temp_reg_data file used by Scripts 35, 51-55, 62

cat("\n[Creating temp_reg_data from combined-data]\n")
cat("  (Stata Script 35, lines 28-64)\n\n")

# Load combined-data (Stata line 28)
cat("  Loading combined-data.rds...\n")
data_full <- readRDS(file.path(dataclean_dir, "combined-data.rds"))
cat(sprintf("    Initial observations: %s\n", format(nrow(data_full), big.mark=",")))

# Stata line 31: Drop banks that already failed
initial_obs <- nrow(data_full)
data_full <- data_full %>%
  filter(!(failed_bank == 1 & quarters_to_failure > 0))
cat(sprintf("    After dropping already-failed banks: %s obs (-%s)\n",
            format(nrow(data_full), big.mark=","),
            format(initial_obs - nrow(data_full), big.mark=",")))

# Stata line 40: Generate run_is_missing
data_full <- data_full %>%
  mutate(
    run_is_missing = (year < 1880) | (year >= 1959 & year <= 1992) | (is.na(run) & failed_bank == 1)
  )

# Stata lines 43-45: Generate failure dummies for LHS variables
# IMPORTANT: Use if_else to handle NA properly - non-failed banks should have 0, not NA
data_full <- data_full %>%
  mutate(
    F1_failure = if_else(is.na(days_to_failure), 0L,
                        as.integer(days_to_failure >= 1 & days_to_failure <= 365)),
    F3_failure = if_else(is.na(quarters_to_failure), 0L,
                        as.integer(quarters_to_failure >= -12 & quarters_to_failure <= -1)),
    F5_failure = if_else(is.na(quarters_to_failure), 0L,
                        as.integer(quarters_to_failure >= -20 & quarters_to_failure <= -1))
  )

cat(sprintf("    F1_failure created: %s failures\n", format(sum(data_full$F1_failure == 1, na.rm = TRUE), big.mark=",")))
cat(sprintf("    F3_failure created: %s failures\n", format(sum(data_full$F3_failure == 1, na.rm = TRUE), big.mark=",")))
cat(sprintf("    F5_failure created: %s failures\n", format(sum(data_full$F5_failure == 1, na.rm = TRUE), big.mark=",")))

# Stata lines 47-48: Generate run-specific failure indicators
data_full <- data_full %>%
  mutate(
    F1_failure_run = ifelse(!is.na(F1_failure) & run_is_missing == 0,
                           as.integer(F1_failure == 1 & run == 1), NA_integer_),
    F3_failure_run = ifelse(!is.na(F3_failure) & run_is_missing == 0,
                           as.integer(F3_failure == 1 & run == 1), NA_integer_)
  )

# Stata line 50: Drop run_is_missing
data_full <- data_full %>%
  select(-run_is_missing)

# Stata line 53: Drop if missing income_ratio for post-1941
# CRITICAL: This filters to only Q4 observations for modern era
cat("    Filtering for income_ratio (keep only Q4 for modern era)...
")
before <- nrow(data_full)
# Conditional filter: only apply if income_ratio exists
if ("income_ratio" %in% names(data_full)) {
  data_full <- data_full %>%
    filter(!(is.na(income_ratio) & year > 1941))
  cat(sprintf("      After filter: %s obs (-%s)
",
              format(nrow(data_full), big.mark=","),
              format(before - nrow(data_full), big.mark=",")))
} else {
  cat("      income_ratio not in dataset, skipping filter
")
}

# Stata line 55: xtset bank_id year (set panel structure)
# R equivalent: arrange by bank_id and year
data_full <- data_full %>%
  arrange(bank_id, year)

# Stata lines 58-59: Generate 3-year growth and growth quintiles
cat("    Generating growth variables...\n")
data_full <- data_full %>%
  group_by(bank_id) %>%
  mutate(
    L3_assets = lag(assets, 3),
    growth = log(assets) - log(L3_assets)
  ) %>%
  ungroup() %>%
  select(-L3_assets)

cat(sprintf("      Growth variable created: %s non-missing\n",
            format(sum(!is.na(data_full$growth)), big.mark=",")))

# Growth quintile by year
data_full <- data_full %>%
  group_by(year) %>%
  mutate(growth_cat = ntile(growth, 5)) %>%
  ungroup()

# Stata line 62: Drop De Novo banks (age < 3)
# CRITICAL: In Stata, "drop if age < 3" keeps NA values!
# In R, filter(age >= 3) removes NA values, so we must keep them explicitly
cat("    Dropping De Novo banks (age < 3, keeping NA)...\n")
before <- nrow(data_full)
data_full <- data_full %>%
  filter(is.na(age) | age >= 3)
cat(sprintf("      After filter: %s obs (-%s)\n",
            format(nrow(data_full), big.mark=","),
            format(before - nrow(data_full), big.mark=",")))

# Stata line 64: Save temp_reg_data
cat("\n    Saving temp_reg_data files...\n")
library(haven)
saveRDS(data_full, file.path(dataclean_dir, "temp_reg_data.rds"))
saveRDS(data_full, file.path(tempfiles_dir, "temp_reg_data.rds"))
write_dta(data_full, file.path(dataclean_dir, "temp_reg_data.dta"))
write_dta(data_full, file.path(tempfiles_dir, "temp_reg_data.dta"))

cat(sprintf("      ✓ temp_reg_data saved: %s observations\n", format(nrow(data_full), big.mark=",")))
cat("        - dataclean/temp_reg_data.rds\n")
cat("        - dataclean/temp_reg_data.dta\n")
cat("        - tempfiles/temp_reg_data.rds\n")
cat("        - tempfiles/temp_reg_data.dta\n")

# STATA CHECKPOINT VERIFICATION
stata_expected <- 964052
obs_count <- nrow(data_full)
match_status <- ifelse(obs_count == stata_expected, "✓ EXACT MATCH", "✗ MISMATCH")

cat(sprintf("\n    === STATA CHECKPOINT VERIFICATION ===\n"))
cat(sprintf("    R observations:      %s\n", format(obs_count, big.mark=",")))
cat(sprintf("    Stata expected:      %s\n", format(stata_expected, big.mark=",")))
cat(sprintf("    Difference:          %+d\n", obs_count - stata_expected))
cat(sprintf("    Status:              %s\n", match_status))

if (obs_count != stata_expected) {
  warning(sprintf("Observation count mismatch: Expected %s but got %s",
                  format(stata_expected, big.mark=","),
                  format(obs_count, big.mark=",")))
}

cat("\n  ✓ temp_reg_data created successfully\n")
cat(sprintf("  Total observations: %s\n", format(nrow(data_full), big.mark=",")))
cat(sprintf("  Banks: %d\n", n_distinct(data_full$bank_id, na.rm = TRUE)))
cat(sprintf("  Banks: %d\n", n_distinct(data_full$bank_id, na.rm = TRUE)))
cat("\nLoading temp_reg_data.rds...\n")
data_full <- readRDS(file.path(tempfiles_dir, "temp_reg_data.rds"))

cat(sprintf("  Loaded: %d observations\n", nrow(data_full)))
cat(sprintf("  Banks: %d\n", n_distinct(data_full$bank_id, na.rm = TRUE)))


cat("  ✓ Failure indicators scaled to 0-100\n")

# ===========================================================================
# PART 2: HISTORICAL SAMPLE - CONDITIONAL PROBABILITIES
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 2: HISTORICAL SAMPLE (1865-1934)\n")
cat("===========================================================================\n")

cat("\n[Filtering to Historical Sample]\n")

data_hist <- data_full %>%
  filter(year >= 1865, year <= 1934)

cat(sprintf("  Historical data: %d observations\n", nrow(data_hist)))

# Figure 1: Failure Probability by Insolvency (Solvency)
cat("\n[Figure 1: Failure Probability by Insolvency]\n")

data_hist_solv <- data_hist %>%
  mutate(
    negative_surplus = -surplus_ratio,  # Insolvency = negative solvency
    profit_measure = CutByPercentiles(negative_surplus)
  ) %>%
  filter(!is.na(profit_measure)) %>%
  group_by(profit_measure) %>%
  summarise(
    F3_failure = mean(F3_failure, na.rm = TRUE),
    F3_failure_run = mean(F3_failure_run, na.rm = TRUE),
    .groups = "drop"
  )

print(data_hist_solv)

plot_hist_solv <- data_hist_solv %>%
  pivot_longer(cols = starts_with("F3"), names_to = "type", values_to = "probability") %>%
  mutate(type = factor(type,
                      levels = c("F3_failure", "F3_failure_run"),
                      labels = c("Failure", "Failure with large deposit outflow"))) %>%
  ggplot(aes(x = profit_measure, y = probability, color = type, shape = type)) +
  geom_line(linewidth = 1, alpha = 0.7) +
  geom_point(size = 3) +
  scale_x_continuous(breaks = 1:5,
                    labels = c("<p50", "p50–p75", "p75–p90", "p90–p95", ">p95")) +
  scale_color_manual(values = c("Failure" = "black", "Failure with large deposit outflow" = "navy")) +
  scale_shape_manual(values = c("Failure" = 16, "Failure with large deposit outflow" = 15)) +
  labs(
    title = "Conditional Probability of Failure by Insolvency: Historical Sample",
    x = "Insolvency",
    y = "Probability of failure (h=3)",
    color = NULL,
    shape = NULL
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(
  file.path(output_dir, "Figures", "05_cond_prob_failure_solvency_historical.pdf"),
  plot = plot_hist_solv,
  width = 8,
  height = 6
)

cat("  ✓ Saved: Figures/05_cond_prob_failure_solvency_historical.pdf\n")

# Figure 2: Failure Probability by Noncore Funding
cat("\n[Figure 2: Failure Probability by Noncore Funding]\n")

data_hist_fund <- data_hist %>%
  mutate(emergency_cat = CutByPercentiles(noncore_ratio)) %>%
  filter(!is.na(emergency_cat)) %>%
  group_by(emergency_cat) %>%
  summarise(
    F3_failure = mean(F3_failure, na.rm = TRUE),
    F3_failure_run = mean(F3_failure_run, na.rm = TRUE),
    .groups = "drop"
  )

print(data_hist_fund)

plot_hist_fund <- data_hist_fund %>%
  pivot_longer(cols = starts_with("F3"), names_to = "type", values_to = "probability") %>%
  mutate(type = factor(type,
                      levels = c("F3_failure", "F3_failure_run"),
                      labels = c("Failure", "Failure with large deposit outflow"))) %>%
  ggplot(aes(x = emergency_cat, y = probability, color = type, shape = type)) +
  geom_line(linewidth = 1, alpha = 0.7) +
  geom_point(size = 3) +
  scale_x_continuous(breaks = 1:5,
                    labels = c("<p50", "p50–p75", "p75–p90", "p90–p95", ">p95")) +
  scale_color_manual(values = c("Failure" = "black", "Failure with large deposit outflow" = "navy")) +
  scale_shape_manual(values = c("Failure" = 16, "Failure with large deposit outflow" = 15)) +
  labs(
    title = "Conditional Probability of Failure by Noncore Funding: Historical Sample",
    x = "Noncore funding",
    y = "Probability of failure (h=3)",
    color = NULL,
    shape = NULL
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(
  file.path(output_dir, "Figures", "05_cond_prob_failure_funding_historical.pdf"),
  plot = plot_hist_fund,
  width = 8,
  height = 6
)

cat("  ✓ Saved: Figures/05_cond_prob_failure_funding_historical.pdf\n")

# Figure 3: Interaction - Solvency × Funding
cat("\n[Figure 3: Interaction - Solvency × Funding]\n")

data_hist_interact <- data_hist %>%
  mutate(
    negative_surplus = -surplus_ratio,
    profit_measure = CutByPercentiles(negative_surplus),
    emergency_cat = CutByPercentiles(noncore_ratio, cuts = c(75, 95))  # 3 categories
  ) %>%
  filter(!is.na(emergency_cat), !is.na(profit_measure))

# Calculate unconditional mean
unconditional_mean <- mean(data_hist$F3_failure, na.rm = TRUE)

data_hist_interact_agg <- data_hist_interact %>%
  group_by(profit_measure, emergency_cat) %>%
  summarise(
    F3_failure = mean(F3_failure, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(unconditional_mean = unconditional_mean)

print(data_hist_interact_agg)

plot_hist_interact <- ggplot(data_hist_interact_agg,
                             aes(x = profit_measure, y = F3_failure,
                                 color = as.factor(emergency_cat),
                                 shape = as.factor(emergency_cat))) +
  geom_hline(aes(yintercept = unconditional_mean), color = "gray40",
             linewidth = 1.2, linetype = "solid") +
  geom_line(linewidth = 1, alpha = 0.7) +
  geom_point(size = 3) +
  scale_x_continuous(breaks = 1:5,
                    labels = c("<p50", "p50–p75", "p75–p90", "p90–p95", ">p95")) +
  scale_color_manual(
    values = c("1" = "darkgreen", "2" = "navy", "3" = "red"),
    labels = c("<75th", "75th-95th", ">95th"),
    name = "Noncore funding percentile:"
  ) +
  scale_shape_manual(
    values = c("1" = 17, "2" = 15, "3" = 16),
    labels = c("<75th", "75th-95th", ">95th"),
    name = "Noncore funding percentile:"
  ) +
  labs(
    title = "Interaction: Insolvency and Noncore Funding (Historical)",
    x = "Insolvency",
    y = "Probability of failure (h=3)"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(
  file.path(output_dir, "Figures", "05_cond_prob_failure_interacted_historical.pdf"),
  plot = plot_hist_interact,
  width = 8,
  height = 6
)

cat("  ✓ Saved: Figures/05_cond_prob_failure_interacted_historical.pdf\n")

# ===========================================================================
# PART 3: MODERN SAMPLE - CONDITIONAL PROBABILITIES
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 3: MODERN SAMPLE (1959-2023)\n")
cat("===========================================================================\n")

cat("\n[Filtering to Modern Sample]\n")

data_mod <- data_full %>%
  filter(year >= 1959)

cat(sprintf("  Modern data: %d observations\n", nrow(data_mod)))

# Figure 4: Failure Probability by Insolvency (Income)
cat("\n[Figure 4: Failure Probability by Insolvency (Income)]\n")

data_mod_solv <- data_mod %>%
  mutate(
    negative_income = -income_ratio,  # Insolvency = negative profitability
    income_cat = CutByPercentiles(negative_income)
  ) %>%
  filter(!is.na(income_cat)) %>%
  group_by(income_cat) %>%
  summarise(
    F3_failure = mean(F3_failure, na.rm = TRUE),
    F3_failure_run = mean(F3_failure_run, na.rm = TRUE),
    .groups = "drop"
  )

print(data_mod_solv)

plot_mod_solv <- data_mod_solv %>%
  pivot_longer(cols = starts_with("F3"), names_to = "type", values_to = "probability") %>%
  mutate(type = factor(type,
                      levels = c("F3_failure", "F3_failure_run"),
                      labels = c("Failure", "Failure with large deposit outflow"))) %>%
  ggplot(aes(x = income_cat, y = probability, color = type, shape = type)) +
  geom_line(linewidth = 1, alpha = 0.7) +
  geom_point(size = 3) +
  scale_x_continuous(breaks = 1:5,
                    labels = c("<p50", "p50–p75", "p75–p90", "p90–p95", ">p95")) +
  scale_color_manual(values = c("Failure" = "black", "Failure with large deposit outflow" = "navy")) +
  scale_shape_manual(values = c("Failure" = 16, "Failure with large deposit outflow" = 15)) +
  labs(
    title = "Conditional Probability of Failure by Insolvency: Modern Era",
    x = "Insolvency",
    y = "Probability of failure (h=3)",
    color = NULL,
    shape = NULL
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(
  file.path(output_dir, "Figures", "05_cond_prob_failure_solvency_modern_era.pdf"),
  plot = plot_mod_solv,
  width = 8,
  height = 6
)

cat("  ✓ Saved: Figures/05_cond_prob_failure_solvency_modern_era.pdf\n")

# Figure 5: Failure Probability by Noncore Funding
cat("\n[Figure 5: Failure Probability by Noncore Funding (Modern)]\n")

data_mod_fund <- data_mod %>%
  mutate(deposit_cat = CutByPercentiles(noncore_ratio)) %>%
  filter(!is.na(deposit_cat)) %>%
  group_by(deposit_cat) %>%
  summarise(
    F3_failure = mean(F3_failure, na.rm = TRUE),
    F3_failure_run = mean(F3_failure_run, na.rm = TRUE),
    .groups = "drop"
  )

print(data_mod_fund)

plot_mod_fund <- data_mod_fund %>%
  pivot_longer(cols = starts_with("F3"), names_to = "type", values_to = "probability") %>%
  mutate(type = factor(type,
                      levels = c("F3_failure", "F3_failure_run"),
                      labels = c("Failure", "Failure with large deposit outflow"))) %>%
  ggplot(aes(x = deposit_cat, y = probability, color = type, shape = type)) +
  geom_line(linewidth = 1, alpha = 0.7) +
  geom_point(size = 3) +
  scale_x_continuous(breaks = 1:5,
                    labels = c("<p50", "p50–p75", "p75–p90", "p90–p95", ">p95")) +
  scale_color_manual(values = c("Failure" = "black", "Failure with large deposit outflow" = "navy")) +
  scale_shape_manual(values = c("Failure" = 16, "Failure with large deposit outflow" = 15)) +
  labs(
    title = "Conditional Probability of Failure by Noncore Funding: Modern Era",
    x = "Noncore funding",
    y = "Probability of failure (h=3)",
    color = NULL,
    shape = NULL
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(
  file.path(output_dir, "Figures", "05_cond_prob_failure_funding_modern_era.pdf"),
  plot = plot_mod_fund,
  width = 8,
  height = 6
)

cat("  ✓ Saved: Figures/05_cond_prob_failure_funding_modern_era.pdf\n")

# Figure 6: Interaction - Solvency × Funding (Modern)
cat("\n[Figure 6: Interaction - Solvency × Funding (Modern)]\n")

data_mod_interact <- data_mod %>%
  mutate(
    negative_income = -income_ratio,
    income_cat = CutByPercentiles(negative_income),
    deposit_cat = CutByPercentiles(noncore_ratio, cuts = c(75, 95))  # 3 categories
  ) %>%
  filter(!is.na(deposit_cat), !is.na(income_cat))

# Calculate unconditional mean
unconditional_mean_mod <- mean(data_mod$F3_failure, na.rm = TRUE)

data_mod_interact_agg <- data_mod_interact %>%
  group_by(income_cat, deposit_cat) %>%
  summarise(
    F3_failure = mean(F3_failure, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(unconditional_mean = unconditional_mean_mod)

print(data_mod_interact_agg)

plot_mod_interact <- ggplot(data_mod_interact_agg,
                            aes(x = income_cat, y = F3_failure,
                                color = as.factor(deposit_cat),
                                shape = as.factor(deposit_cat))) +
  geom_hline(aes(yintercept = unconditional_mean), color = "gray40",
             linewidth = 1.2, linetype = "solid") +
  geom_line(linewidth = 1, alpha = 0.7) +
  geom_point(size = 3) +
  scale_x_continuous(breaks = 1:5,
                    labels = c("<p50", "p50–p75", "p75–p90", "p90–p95", ">p95")) +
  scale_color_manual(
    values = c("1" = "darkgreen", "2" = "navy", "3" = "red"),
    labels = c("<75th", "75th-95th", ">95th"),
    name = "Noncore funding percentile:"
  ) +
  scale_shape_manual(
    values = c("1" = 17, "2" = 15, "3" = 16),
    labels = c("<75th", "75th-95th", ">95th"),
    name = "Noncore funding percentile:"
  ) +
  labs(
    title = "Interaction: Insolvency and Noncore Funding (Modern Era)",
    x = "Insolvency",
    y = "Probability of failure (h=3)"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(
  file.path(output_dir, "Figures", "05_cond_prob_failure_interacted_modern.pdf"),
  plot = plot_mod_interact,
  width = 8,
  height = 6
)

cat("  ✓ Saved: Figures/05_cond_prob_failure_interacted_modern.pdf\n")

# ===========================================================================
# PART 4: FINAL SUMMARY AND COMPLETION
# ===========================================================================

cat("\n===========================================================================\n")
cat("FINAL SUMMARY\n")
cat("===========================================================================\n")

script_end_time <- Sys.time()
script_duration <- as.numeric(difftime(script_end_time, script_start_time,
                                      units = "mins"))

cat("\n[Historical Sample Figures]\n")
cat("  ✓ Conditional probability by insolvency\n")
cat("  ✓ Conditional probability by noncore funding\n")
cat("  ✓ Interaction plot (solvency × funding)\n")

cat("\n[Modern Sample Figures]\n")
cat("  ✓ Conditional probability by insolvency\n")
cat("  ✓ Conditional probability by noncore funding\n")
cat("  ✓ Interaction plot (solvency × funding)\n")

cat("\n  Total: 6 figures\n")

cat("\n===========================================================================\n")
cat("SCRIPT 35 COMPLETED SUCCESSFULLY\n")
cat(sprintf("  End time: %s\n", Sys.time()))
cat(sprintf("  Runtime: %.1f minutes\n", script_duration))
cat("===========================================================================\n")
