# ==============================================================================
# Script 48: Noncore Funding Trajectory - Failed Bank Lifecycle
# ==============================================================================
# Purpose: Show rising reliance on volatile noncore funding as failure approaches
#          "Funding stress" signature - traditional depositors flee, banks turn to
#          non-deposit funding sources
# Output:  48_noncore_funding_trajectory.png (300 DPI)
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
  filter(failed_bank == 1, !is.na(noncore_ratio), !is.na(time_to_fail)) %>%
  filter(time_to_fail >= -5 & time_to_fail <= 0) %>%
  mutate(
    # Convert to percentage
    noncore_ratio_pct = noncore_ratio * 100,
    # Define eras
    era = case_when(
      year < 1941 ~ "Pre-1941 (Residual Funding)",
      year >= 1941 ~ "Post-1941 (Time Deposits + Borrowing)",
      TRUE ~ "Other"
    ),
    period = case_when(
      year >= 1863 & year <= 1904 ~ "National Banking (1863-1904)",
      year >= 1914 & year <= 1928 ~ "Early Fed/WWI (1914-1928)",
      year >= 1929 & year <= 1934 ~ "Great Depression (1929-1934)",
      year >= 1959 & year <= 2006 ~ "Modern Pre-Crisis (1959-2006)",
      year >= 2007 & year <= 2023 ~ "Financial Crisis (2007-2023)",
      TRUE ~ "Other"
    )
  ) %>%
  filter(era != "Other", period != "Other")

# Calculate mean noncore funding by time-to-failure (overall)
trajectory_overall <- failed_trajectory %>%
  group_by(time_to_fail) %>%
  summarize(
    mean_noncore = mean(noncore_ratio_pct, na.rm = TRUE),
    se_noncore = sd(noncore_ratio_pct, na.rm = TRUE) / sqrt(n()),
    median_noncore = median(noncore_ratio_pct, na.rm = TRUE),
    n_obs = n(),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = mean_noncore - 1.96 * se_noncore,
    ci_upper = mean_noncore + 1.96 * se_noncore
  )

# Calculate by era (pre/post 1941 definition change)
trajectory_by_era <- failed_trajectory %>%
  group_by(time_to_fail, era) %>%
  summarize(
    mean_noncore = mean(noncore_ratio_pct, na.rm = TRUE),
    se_noncore = sd(noncore_ratio_pct, na.rm = TRUE) / sqrt(n()),
    n_obs = n(),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = mean_noncore - 1.96 * se_noncore,
    ci_upper = mean_noncore + 1.96 * se_noncore
  )

# Get baseline for non-failed banks (by era)
nonfailed_baseline <- panel_data %>%
  filter(failed_bank == 0, !is.na(noncore_ratio)) %>%
  mutate(
    era = case_when(
      year < 1941 ~ "Pre-1941 (Residual Funding)",
      year >= 1941 ~ "Post-1941 (Time Deposits + Borrowing)",
      TRUE ~ "Other"
    )
  ) %>%
  filter(era != "Other") %>%
  group_by(era) %>%
  summarize(
    mean_noncore = mean(noncore_ratio * 100, na.rm = TRUE),
    se_noncore = sd(noncore_ratio * 100, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )

# Define era colors
era_colors <- c(
  "Pre-1941 (Residual Funding)" = color_historical,
  "Post-1941 (Time Deposits + Borrowing)" = color_modern
)

# Create visualization
p <- ggplot() +
  # Non-failed baselines (horizontal lines by era)
  geom_hline(data = nonfailed_baseline,
             aes(yintercept = mean_noncore, color = era),
             linetype = "dashed", linewidth = 1, alpha = 0.7) +
  # Era-specific trajectories
  geom_ribbon(data = trajectory_by_era,
              aes(x = time_to_fail, ymin = ci_lower, ymax = ci_upper, fill = era),
              alpha = 0.2) +
  geom_line(data = trajectory_by_era,
            aes(x = time_to_fail, y = mean_noncore, color = era, group = era),
            linewidth = 1.5, alpha = 0.9) +
  geom_point(data = trajectory_by_era,
             aes(x = time_to_fail, y = mean_noncore, color = era),
             size = 2.5) +
  scale_x_continuous(
    name = "Years Before Failure",
    breaks = -5:0,
    labels = c("-5", "-4", "-3", "-2", "-1", "Failure")
  ) +
  scale_y_continuous(
    name = "Mean Noncore Funding Ratio (%)",
    labels = function(x) paste0(x, "%")
  ) +
  scale_color_manual(
    name = "Era (Noncore Definition)",
    values = era_colors
  ) +
  scale_fill_manual(
    name = "Era (Noncore Definition)",
    values = era_colors
  ) +
  labs(
    title = "Funding Stress Intensifies as Failure Nears: Rising Reliance on Volatile Noncore Funding",
    subtitle = "Mean noncore funding ratio from 5 years before failure. Pre-1941 = residual funding. Post-1941 = time deposits + borrowing.",
    caption = "Source: Combined panel dataset. Noncore definition changes in 1941. Dashed lines = non-failed baselines. Ribbons = 95% CI."
  ) +
  theme_failing_banks() +
  theme(
    legend.position = "bottom"
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "48_noncore_funding_trajectory.png"),
  plot = p,
  width = 12,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== NONCORE FUNDING TRAJECTORY: FAILED BANKS ===\n\n")
cat("Overall trajectory (all periods):\n")
print(trajectory_overall %>% select(time_to_fail, mean_noncore, median_noncore, n_obs), n = Inf)

cat("\n\nBy era:\n")
print(trajectory_by_era %>% select(time_to_fail, era, mean_noncore, n_obs), n = 20)

cat("\n\nNon-failed baselines:\n")
print(nonfailed_baseline, n = Inf)

cat("\n✓ Saved: 48_noncore_funding_trajectory.png (12\" × 8\", 300 DPI)\n")
