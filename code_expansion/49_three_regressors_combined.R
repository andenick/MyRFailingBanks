# ==============================================================================
# Script 49: Three Regressors Combined - Panel View
# ==============================================================================
# Purpose: Show all three main predictors in one comprehensive view
#          Clear "signature" of failure across asset growth, income, and funding
# Output:  49_three_regressors_combined.png (300 DPI)
# ==============================================================================

library(tidyverse)
library(here)
library(scales)

# Load Tableau color palette
source(here::here("code_expansion", "00_tableau_colors.R"))

# Set paths
output_dir <- here::here("code_expansion", "presentation_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Load main panel data
panel_data <- readRDS(here::here("tempfiles", "temp_reg_data.rds"))

# Prepare failed bank data aligned by time-to-failure
failed_data <- panel_data %>%
  filter(failed_bank == 1, !is.na(time_to_fail)) %>%
  filter(time_to_fail >= -5 & time_to_fail <= 0)

# Calculate trajectories for all three regressors
# 1. Asset Growth
growth_trajectory <- failed_data %>%
  filter(!is.na(growth)) %>%
  group_by(time_to_fail) %>%
  summarize(
    mean_value = mean(growth, na.rm = TRUE),
    se_value = sd(growth, na.rm = TRUE) / sqrt(n()),
    n_obs = n(),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = mean_value - 1.96 * se_value,
    ci_upper = mean_value + 1.96 * se_value,
    regressor = "Asset Growth (%)"
  )

# 2. Income Ratio (convert to percentage)
income_trajectory <- failed_data %>%
  filter(!is.na(income_ratio)) %>%
  group_by(time_to_fail) %>%
  summarize(
    mean_value = mean(income_ratio * 100, na.rm = TRUE),
    se_value = sd(income_ratio * 100, na.rm = TRUE) / sqrt(n()),
    n_obs = n(),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = mean_value - 1.96 * se_value,
    ci_upper = mean_value + 1.96 * se_value,
    regressor = "Net Income / Assets (%)"
  )

# 3. Noncore Funding Ratio (convert to percentage)
noncore_trajectory <- failed_data %>%
  filter(!is.na(noncore_ratio)) %>%
  group_by(time_to_fail) %>%
  summarize(
    mean_value = mean(noncore_ratio * 100, na.rm = TRUE),
    se_value = sd(noncore_ratio * 100, na.rm = TRUE) / sqrt(n()),
    n_obs = n(),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = mean_value - 1.96 * se_value,
    ci_upper = mean_value + 1.96 * se_value,
    regressor = "Noncore Funding / Assets (%)"
  )

# Combine all three
combined_trajectory <- bind_rows(
  growth_trajectory,
  income_trajectory,
  noncore_trajectory
) %>%
  mutate(
    regressor = factor(regressor, levels = c(
      "Asset Growth (%)",
      "Net Income / Assets (%)",
      "Noncore Funding / Assets (%)"
    ))
  )

# Get non-failed baselines
nonfailed_baselines <- tibble(
  regressor = factor(c(
    "Asset Growth (%)",
    "Net Income / Assets (%)",
    "Noncore Funding / Assets (%)"
  ), levels = c(
    "Asset Growth (%)",
    "Net Income / Assets (%)",
    "Noncore Funding / Assets (%)"
  )),
  baseline = c(
    panel_data %>% filter(failed_bank == 0, !is.na(growth)) %>% pull(growth) %>% mean(na.rm = TRUE),
    panel_data %>% filter(failed_bank == 0, !is.na(income_ratio)) %>% pull(income_ratio) %>% mean(na.rm = TRUE) * 100,
    panel_data %>% filter(failed_bank == 0, !is.na(noncore_ratio)) %>% pull(noncore_ratio) %>% mean(na.rm = TRUE) * 100
  )
)

# Create visualization
p <- ggplot(combined_trajectory, aes(x = time_to_fail, y = mean_value)) +
  # Non-failed baselines
  geom_hline(data = nonfailed_baselines,
             aes(yintercept = baseline),
             linetype = "dashed", color = color_success, linewidth = 0.8) +
  # Failed bank trajectories
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper),
              fill = color_failure, alpha = 0.2) +
  geom_line(color = color_failure, linewidth = 1.5, alpha = 0.9) +
  geom_point(color = color_failure, size = 3) +
  # Zero line for reference
  geom_hline(yintercept = 0, linetype = "dotted", color = color_neutral, linewidth = 0.5, alpha = 0.5) +
  # Facet by regressor
  facet_wrap(~ regressor, ncol = 1, scales = "free_y") +
  scale_x_continuous(
    name = "Years Before Failure",
    breaks = -5:0,
    labels = c("-5", "-4", "-3", "-2", "-1", "Failure")
  ) +
  scale_y_continuous(
    name = "Mean Value"
  ) +
  labs(
    title = "The Three Signatures of Bank Failure: Growth, Profitability, and Funding Stress",
    subtitle = "Mean values for three main failure predictors from 5 years before failure. Red = failed banks. Green dashed = non-failed baseline.",
    caption = "Source: Combined panel dataset (1863-2024). Failed banks aligned by time-to-failure. Ribbons = 95% CI. Pattern consistent across all eras."
  ) +
  theme_failing_banks() +
  theme(
    strip.text = element_text(face = "bold", size = 11),
    strip.background = element_rect(fill = "gray90", color = NA),
    panel.spacing = unit(1.5, "lines")
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "49_three_regressors_combined.png"),
  plot = p,
  width = 12,
  height = 12,
  dpi = 300,
  bg = "white"
)

# Print summary statistics for all three regressors
cat("\n=== THREE MAIN REGRESSORS: COMPREHENSIVE TRAJECTORY ===\n\n")

cat("1. ASSET GROWTH:\n")
print(growth_trajectory %>% select(time_to_fail, mean_value, n_obs), n = Inf)
cat("\n   Non-failed baseline:", round(nonfailed_baselines$baseline[1], 2), "%\n")

cat("\n2. INCOME RATIO:\n")
print(income_trajectory %>% select(time_to_fail, mean_value, n_obs), n = Inf)
cat("\n   Non-failed baseline:", round(nonfailed_baselines$baseline[2], 3), "%\n")

cat("\n3. NONCORE FUNDING RATIO:\n")
print(noncore_trajectory %>% select(time_to_fail, mean_value, n_obs), n = Inf)
cat("\n   Non-failed baseline:", round(nonfailed_baselines$baseline[3], 2), "%\n")

cat("\n✓ Saved: 49_three_regressors_combined.png (12\" × 12\", 300 DPI)\n")
cat("\nThis visualization shows the canonical failure signature across ALL three main predictors.\n")
