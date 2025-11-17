# ==============================================================================
# Script 52: Typical Failed Bank Lifecycle - Composite Portrait
# ==============================================================================
# Purpose: Create definitive "what does a failing bank look like" visualization
#          Show median failed bank across 10-12 key metrics from 5 years before failure
# Output:  52_typical_failed_bank_lifecycle.png (300 DPI)
# ==============================================================================

library(tidyverse)
library(here)
library(scales)

# Load Tableau color palette
source(here::here("code_expansion", "00_tableau_colors.R"))

# Set paths
output_dir <- here::here("code_expansion", "presentation_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Load regression data
panel_data <- readRDS(here::here("tempfiles", "temp_reg_data.rds"))

# Prepare failed bank data aligned by time-to-failure
failed_data <- panel_data %>%
  filter(failed_bank == 1, !is.na(time_to_fail)) %>%
  filter(time_to_fail >= -5 & time_to_fail <= 0)

# Calculate median trajectories for key metrics
metrics <- list(
  list(var = "growth", label = "Asset Growth (%)", mult = 1),
  list(var = "income_ratio", label = "Income / Assets (%)", mult = 100),
  list(var = "leverage", label = "Equity / Assets (%)", mult = 100),
  list(var = "liquid_ratio", label = "Liquidity Ratio (%)", mult = 100),
  list(var = "loan_ratio", label = "Loan Ratio (%)", mult = 100),
  list(var = "noncore_ratio", label = "Noncore Funding (%)", mult = 100),
  list(var = "deposit_ratio", label = "Deposit Ratio (%)", mult = 100),
  list(var = "npl_ratio", label = "NPL Ratio (%)", mult = 100)
)

# Calculate trajectories for each metric
trajectory_list <- lapply(metrics, function(m) {
  failed_data %>%
    filter(!is.na(.data[[m$var]])) %>%
    group_by(time_to_fail) %>%
    summarize(
      median_value = median(.data[[m$var]], na.rm = TRUE) * m$mult,
      mean_value = mean(.data[[m$var]], na.rm = TRUE) * m$mult,
      .groups = "drop"
    ) %>%
    mutate(metric = m$label)
})

# Combine all trajectories
combined_trajectory <- bind_rows(trajectory_list)

# Get non-failed baselines
baseline_values <- numeric(length(metrics))
for (i in seq_along(metrics)) {
  m <- metrics[[i]]
  baseline_values[i] <- panel_data %>%
    filter(failed_bank == 0) %>%
    pull(!!sym(m$var)) %>%
    median(na.rm = TRUE) * m$mult
}

nonfailed_baselines <- tibble(
  metric = sapply(metrics, function(m) m$label),
  baseline = baseline_values
)

# Create visualization
p <- ggplot(combined_trajectory, aes(x = time_to_fail, y = median_value)) +
  # Non-failed baselines
  geom_hline(data = nonfailed_baselines,
             aes(yintercept = baseline),
             linetype = "dashed", color = color_success, linewidth = 0.6, alpha = 0.7) +
  # Failed bank trajectories
  geom_line(color = color_failure, linewidth = 1.2, alpha = 0.9) +
  geom_point(color = color_failure, size = 2) +
  # Facet by metric
  facet_wrap(~ metric, ncol = 4, scales = "free_y") +
  scale_x_continuous(
    name = "Years Before Failure",
    breaks = c(-5, -3, -1, 0),
    labels = c("-5", "-3", "-1", "F")
  ) +
  scale_y_continuous(
    name = "Median Value"
  ) +
  labs(
    title = "The Typical Failed Bank: Canonical Trajectory Across 8 Key Metrics",
    subtitle = "Median values for failed banks from 5 years before failure. Red = failed banks. Green dashed = non-failed baseline.",
    caption = "Source: Regression dataset. Failed banks aligned by time-to-failure. Shows consistent deterioration pattern across all metrics."
  ) +
  theme_failing_banks() +
  theme(
    strip.text = element_text(face = "bold", size = 9),
    strip.background = element_rect(fill = "gray90", color = NA),
    panel.spacing = unit(0.8, "lines"),
    axis.text.x = element_text(size = 8)
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "52_typical_failed_bank_lifecycle.png"),
  plot = p,
  width = 16,
  height = 12,
  dpi = 300,
  bg = "white"
)

# Print summary
cat("\n=== TYPICAL FAILED BANK LIFECYCLE ===\n\n")
cat("Showing median values for 8 key metrics\n")
cat("Pattern: Failing banks show deterioration across ALL dimensions\n\n")

for (i in seq_along(metrics)) {
  m <- metrics[[i]]
  traj <- trajectory_list[[i]]
  baseline <- nonfailed_baselines$baseline[i]

  cat(sprintf("\n%s:\n", m$label))
  cat(sprintf("  t-5: %.2f  →  t-1: %.2f  →  Failure: %.2f\n",
              traj$median_value[traj$time_to_fail == -5],
              traj$median_value[traj$time_to_fail == -1],
              traj$median_value[traj$time_to_fail == 0]))
  cat(sprintf("  Non-failed baseline: %.2f\n", baseline))
}

cat("\n✓ Saved: 52_typical_failed_bank_lifecycle.png (16\" × 12\", 300 DPI)\n")
