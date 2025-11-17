# ==============================================================================
# Script 28: Leverage Dynamics by Period
# ==============================================================================
# Purpose: Show failed banks are more leveraged (lower equity ratios)
# Output:  28_leverage_dynamics_by_period.png (300 DPI)
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
panel_data <- readRDS(here::here("dataclean", "combined-data.rds"))

# Define periods and prepare data
plot_data <- panel_data %>%
  mutate(
    period_num = case_when(
      year >= 1863 & year <= 1904 ~ 1,
      year >= 1914 & year <= 1928 ~ 2,
      year >= 1929 & year <= 1934 ~ 3,
      year >= 1959 & year <= 2006 ~ 4,
      year >= 2007 & year <= 2023 ~ 5,
      TRUE ~ NA_real_
    ),
    period = case_when(
      period_num == 1 ~ "National Banking\n(1863-1904)",
      period_num == 2 ~ "Early Fed/WWI\n(1914-1928)",
      period_num == 3 ~ "Great Depression\n(1929-1934)",
      period_num == 4 ~ "Modern Pre-Crisis\n(1959-2006)",
      period_num == 5 ~ "Financial Crisis\n(2007-2023)",
      TRUE ~ "Other"
    ),
    bank_status = ifelse(failed_bank == 1, "Failed", "Non-Failed")
  ) %>%
  filter(!is.na(leverage), !is.na(period_num), !is.na(bank_status))

# Calculate mean leverage by period and status
leverage_summary <- plot_data %>%
  group_by(period_num, period, bank_status) %>%
  summarize(
    mean_leverage = mean(leverage, na.rm = TRUE) * 100,
    se_leverage = sd(leverage, na.rm = TRUE) / sqrt(n()) * 100,
    n_obs = n(),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = mean_leverage - 1.96 * se_leverage,
    ci_upper = mean_leverage + 1.96 * se_leverage
  )

# Create visualization
p <- ggplot(leverage_summary, aes(x = period_num, y = mean_leverage, color = bank_status, fill = bank_status)) +
  geom_line(linewidth = 1.5, alpha = 0.8) +
  geom_point(size = 3, alpha = 0.9) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.2, color = NA) +
  scale_x_continuous(
    name = "",
    breaks = 1:5,
    labels = c(
      "National\nBanking\n(1863-1904)",
      "Early Fed/\nWWI\n(1914-1928)",
      "Great\nDepression\n(1929-1934)",
      "Modern\nPre-Crisis\n(1959-2006)",
      "Financial\nCrisis\n(2007-2023)"
    )
  ) +
  scale_y_continuous(
    name = "Leverage (Equity / Assets, %)",
    labels = function(x) paste0(x, "%")
  ) +
  scale_color_manual(
    name = "Bank Status",
    values = comparison_colors
  ) +
  scale_fill_manual(
    name = "Bank Status",
    values = comparison_colors
  ) +
  labs(
    title = "Failed Banks Are More Leveraged: Lower Equity Ratios Across All Eras",
    subtitle = "Mean equity-to-assets ratio by period. Ribbons show 95% confidence intervals. Lower leverage = higher risk.",
    caption = "Source: Combined panel dataset (1863-2023). Leverage = equity/total assets. Failed banks consistently undercapitalized."
  ) +
  theme_failing_banks() +
  theme(
    axis.text.x = element_text(size = 8, angle = 0, hjust = 0.5)
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "28_leverage_dynamics_by_period.png"),
  plot = p,
  width = 12,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== LEVERAGE DYNAMICS: FAILED VS NON-FAILED ===\n\n")
print(leverage_summary, n = Inf)

cat("\n✓ Saved: 28_leverage_dynamics_by_period.png (12\" × 8\", 300 DPI)\n")
