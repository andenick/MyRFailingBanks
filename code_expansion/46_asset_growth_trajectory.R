# ==============================================================================
# Script 46: Asset Growth Trajectory - Failed Bank Lifecycle
# ==============================================================================
# Purpose: Show canonical "boom-bust" pattern - asset growth trajectory from
#          5 years before failure to failure, aligned by time-to-failure
# Output:  46_asset_growth_trajectory.png (300 DPI)
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
failed_trajectory <- panel_data %>%
  filter(failed_bank == 1, !is.na(growth), !is.na(time_to_fail)) %>%
  filter(time_to_fail >= -5 & time_to_fail <= 0) %>%
  mutate(
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

# Calculate mean growth by time-to-failure and period
trajectory_summary <- failed_trajectory %>%
  group_by(time_to_fail, period) %>%
  summarize(
    mean_growth = mean(growth, na.rm = TRUE),
    se_growth = sd(growth, na.rm = TRUE) / sqrt(n()),
    n_obs = n(),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = mean_growth - 1.96 * se_growth,
    ci_upper = mean_growth + 1.96 * se_growth
  )

# Calculate overall mean (all periods combined)
trajectory_overall <- failed_trajectory %>%
  group_by(time_to_fail) %>%
  summarize(
    mean_growth = mean(growth, na.rm = TRUE),
    se_growth = sd(growth, na.rm = TRUE) / sqrt(n()),
    n_obs = n(),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = mean_growth - 1.96 * se_growth,
    ci_upper = mean_growth + 1.96 * se_growth,
    period = "All Periods Combined"
  )

# Get baseline for non-failed banks
nonfailed_baseline <- panel_data %>%
  filter(failed_bank == 0, !is.na(growth)) %>%
  summarize(
    mean_growth = mean(growth, na.rm = TRUE),
    se_growth = sd(growth, na.rm = TRUE) / sqrt(n())
  )

# Define period colors
period_colors <- c(
  "National Banking (1863-1904)" = color_national,
  "Early Fed/WWI (1914-1928)" = color_earlyfed,
  "Great Depression (1929-1934)" = color_depression,
  "Modern Pre-Crisis (1959-2006)" = color_modern,
  "Financial Crisis (2007-2023)" = color_crisis,
  "All Periods Combined" = color_failure
)

# Create visualization
p <- ggplot() +
  # Non-failed baseline (horizontal line)
  geom_hline(yintercept = nonfailed_baseline$mean_growth,
             linetype = "dashed", color = color_success, linewidth = 1) +
  annotate("text", x = -4.5, y = nonfailed_baseline$mean_growth + 1,
           label = "Non-Failed Bank Avg", color = color_success, size = 3, hjust = 0) +
  # Individual period trajectories (thin lines)
  geom_line(data = trajectory_summary,
            aes(x = time_to_fail, y = mean_growth, color = period, group = period),
            alpha = 0.4, linewidth = 0.8) +
  # Overall trajectory (thick line)
  geom_line(data = trajectory_overall,
            aes(x = time_to_fail, y = mean_growth),
            color = color_failure, linewidth = 2, alpha = 0.9) +
  geom_ribbon(data = trajectory_overall,
              aes(x = time_to_fail, ymin = ci_lower, ymax = ci_upper),
              fill = color_failure, alpha = 0.2) +
  geom_point(data = trajectory_overall,
             aes(x = time_to_fail, y = mean_growth),
             color = color_failure, size = 3) +
  # Zero growth line
  geom_hline(yintercept = 0, linetype = "dotted", color = color_neutral, linewidth = 0.6) +
  scale_x_continuous(
    name = "Years Before Failure",
    breaks = -5:0,
    labels = c("-5", "-4", "-3", "-2", "-1", "Failure")
  ) +
  scale_y_continuous(
    name = "Mean Asset Growth (%)",
    labels = function(x) paste0(x, "%")
  ) +
  scale_color_manual(
    name = "Period",
    values = period_colors
  ) +
  labs(
    title = "Failed Banks Show Canonical 'Boom-Bust' Pattern: Rapid Growth Then Collapse",
    subtitle = "Mean asset growth trajectory from 5 years before failure to failure. Bold line = all periods combined. Thin lines = by era.",
    caption = "Source: Combined panel dataset (1863-2024). Failed banks aligned by time-to-failure. Dashed green line = non-failed baseline. Ribbon = 95% CI."
  ) +
  theme_failing_banks()

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "46_asset_growth_trajectory.png"),
  plot = p,
  width = 12,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== ASSET GROWTH TRAJECTORY: FAILED BANKS ===\n\n")
cat("Overall trajectory (all periods):\n")
print(trajectory_overall %>% select(time_to_fail, mean_growth, n_obs), n = Inf)

cat("\n\nNon-failed baseline:", round(nonfailed_baseline$mean_growth, 2), "%\n")

cat("\n✓ Saved: 46_asset_growth_trajectory.png (12\" × 8\", 300 DPI)\n")
