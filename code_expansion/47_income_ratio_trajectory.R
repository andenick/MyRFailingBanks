# ==============================================================================
# Script 47: Income Ratio Trajectory - Failed Bank Lifecycle
# ==============================================================================
# Purpose: Show profitability deterioration in years leading to failure
#          Failed banks show declining/negative income ratios as failure approaches
# Output:  47_income_ratio_trajectory.png (300 DPI)
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
# Note: income_ratio primarily available in Q4
failed_trajectory <- panel_data %>%
  filter(failed_bank == 1, !is.na(income_ratio), !is.na(time_to_fail)) %>%
  filter(time_to_fail >= -5 & time_to_fail <= 0) %>%
  mutate(
    # Convert to percentage
    income_ratio_pct = income_ratio * 100,
    period = case_when(
      year >= 1863 & year <= 1904 ~ "National Banking (1863-1904)",
      year >= 1914 & year <= 1928 ~ "Early Fed/WWI (1914-1928)",
      year >= 1929 & year <= 1934 ~ "Great Depression (1929-1934)",
      year >= 1959 & year <= 2006 ~ "Modern Pre-Crisis (1959-2006)",
      year >= 2007 & year <= 2023 ~ "Financial Crisis (2007-2023)",
      TRUE ~ "Other"
    )
  ) %>%
  filter(period != "Other")

# Calculate mean income ratio by time-to-failure
trajectory_overall <- failed_trajectory %>%
  group_by(time_to_fail) %>%
  summarize(
    mean_income = mean(income_ratio_pct, na.rm = TRUE),
    se_income = sd(income_ratio_pct, na.rm = TRUE) / sqrt(n()),
    median_income = median(income_ratio_pct, na.rm = TRUE),
    n_obs = n(),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = mean_income - 1.96 * se_income,
    ci_upper = mean_income + 1.96 * se_income
  )

# Calculate by period for comparison
trajectory_by_period <- failed_trajectory %>%
  group_by(time_to_fail, period) %>%
  summarize(
    mean_income = mean(income_ratio_pct, na.rm = TRUE),
    n_obs = n(),
    .groups = "drop"
  )

# Get baseline for non-failed banks
nonfailed_baseline <- panel_data %>%
  filter(failed_bank == 0, !is.na(income_ratio)) %>%
  summarize(
    mean_income = mean(income_ratio * 100, na.rm = TRUE),
    se_income = sd(income_ratio * 100, na.rm = TRUE) / sqrt(n())
  )

# Define period colors
period_colors <- c(
  "National Banking (1863-1904)" = color_national,
  "Early Fed/WWI (1914-1928)" = color_earlyfed,
  "Great Depression (1929-1934)" = color_depression,
  "Modern Pre-Crisis (1959-2006)" = color_modern,
  "Financial Crisis (2007-2023)" = color_crisis
)

# Create visualization
p <- ggplot() +
  # Non-failed baseline (horizontal band)
  geom_hline(yintercept = nonfailed_baseline$mean_income,
             linetype = "dashed", color = color_success, linewidth = 1) +
  geom_rect(aes(xmin = -5.5, xmax = 0.5,
                ymin = nonfailed_baseline$mean_income - 1.96 * nonfailed_baseline$se_income,
                ymax = nonfailed_baseline$mean_income + 1.96 * nonfailed_baseline$se_income),
            fill = color_success, alpha = 0.1) +
  annotate("text", x = -4.5, y = nonfailed_baseline$mean_income + 0.3,
           label = "Non-Failed Bank Avg (±95% CI)", color = color_success, size = 3, hjust = 0) +
  # Individual period trajectories (thin lines)
  geom_line(data = trajectory_by_period,
            aes(x = time_to_fail, y = mean_income, color = period, group = period),
            alpha = 0.4, linewidth = 0.8) +
  # Overall trajectory (thick line with ribbon)
  geom_ribbon(data = trajectory_overall,
              aes(x = time_to_fail, ymin = ci_lower, ymax = ci_upper),
              fill = color_failure, alpha = 0.2) +
  geom_line(data = trajectory_overall,
            aes(x = time_to_fail, y = mean_income),
            color = color_failure, linewidth = 2, alpha = 0.9) +
  geom_point(data = trajectory_overall,
             aes(x = time_to_fail, y = mean_income),
             color = color_failure, size = 3) +
  # Zero profitability line
  geom_hline(yintercept = 0, linetype = "dotted", color = color_neutral, linewidth = 0.6) +
  annotate("text", x = -4.8, y = -0.15,
           label = "Break-even", color = color_neutral, size = 2.5, hjust = 0) +
  scale_x_continuous(
    name = "Years Before Failure",
    breaks = -5:0,
    labels = c("-5", "-4", "-3", "-2", "-1", "Failure")
  ) +
  scale_y_continuous(
    name = "Mean Net Income / Assets (%)",
    labels = function(x) paste0(x, "%")
  ) +
  scale_color_manual(
    name = "Period",
    values = period_colors
  ) +
  labs(
    title = "Profitability Deteriorates as Failure Approaches: Income Plummets in Final Years",
    subtitle = "Mean income-to-assets ratio from 5 years before failure to failure. Bold line = all periods. Thin lines = by era.",
    caption = "Source: Combined panel dataset. Income ratio = net income / total assets. Failed banks aligned by time-to-failure. Ribbon = 95% CI."
  ) +
  theme_failing_banks()

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "47_income_ratio_trajectory.png"),
  plot = p,
  width = 12,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== INCOME RATIO TRAJECTORY: FAILED BANKS ===\n\n")
cat("Overall trajectory (all periods):\n")
print(trajectory_overall %>% select(time_to_fail, mean_income, median_income, n_obs), n = Inf)

cat("\n\nNon-failed baseline:", round(nonfailed_baseline$mean_income, 3), "%\n")

cat("\nKey insight: Income ratio declines from",
    round(trajectory_overall$mean_income[trajectory_overall$time_to_fail == -5], 2), "% (t-5) to",
    round(trajectory_overall$mean_income[trajectory_overall$time_to_fail == 0], 2), "% at failure.\n")

cat("\n✓ Saved: 47_income_ratio_trajectory.png (12\" × 8\", 300 DPI)\n")
