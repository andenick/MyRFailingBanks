# ==============================================================================
# Script 24: Asset Growth - Failed vs Non-Failed Banks
# ==============================================================================
# Purpose: Show excessive asset growth in failed banks before failure
# Output:  24_asset_growth_failed_vs_nonfailed.png (300 DPI)
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

# Define periods
panel_data <- panel_data %>%
  mutate(
    period = case_when(
      year >= 1863 & year <= 1904 ~ "National Banking\n(1863-1904)",
      year >= 1914 & year <= 1928 ~ "Early Fed/WWI\n(1914-1928)",
      year >= 1929 & year <= 1934 ~ "Great Depression\n(1929-1934)",
      year >= 1959 & year <= 2006 ~ "Modern Pre-Crisis\n(1959-2006)",
      year >= 2007 & year <= 2023 ~ "Financial Crisis\n(2007-2023)",
      TRUE ~ "Other"
    ),
    period = factor(period, levels = c(
      "National Banking\n(1863-1904)",
      "Early Fed/WWI\n(1914-1928)",
      "Great Depression\n(1929-1934)",
      "Modern Pre-Crisis\n(1959-2006)",
      "Financial Crisis\n(2007-2023)"
    )),
    bank_status = ifelse(failed_bank == 1, "Failed", "Non-Failed")
  ) %>%
  filter(!is.na(growth), !is.na(period), period != "Other", !is.na(bank_status))

# Calculate mean asset growth by period and status
growth_summary <- panel_data %>%
  group_by(period, bank_status) %>%
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

# Create visualization
p <- ggplot(growth_summary, aes(x = period, y = mean_growth, fill = bank_status)) +
  geom_col(position = position_dodge(width = 0.8), alpha = 0.8, width = 0.7) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper),
                position = position_dodge(width = 0.8), width = 0.25, linewidth = 0.7) +
  scale_y_continuous(
    name = "Mean Asset Growth (%)",
    labels = function(x) paste0(x, "%")
  ) +
  scale_x_discrete(name = "") +
  scale_fill_manual(
    name = "Bank Status",
    values = comparison_colors
  ) +
  labs(
    title = "Failed Banks Show Excessive Asset Growth Before Failure",
    subtitle = "Mean annual asset growth rate by period. Error bars show 95% confidence intervals.",
    caption = "Source: Combined panel dataset (1863-2023). Asset growth calculated year-over-year."
  ) +
  theme_failing_banks() +
  theme(
    axis.text.x = element_text(size = 9, angle = 0, hjust = 0.5)
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "24_asset_growth_failed_vs_nonfailed.png"),
  plot = p,
  width = 12,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== ASSET GROWTH: FAILED VS NON-FAILED ===\n\n")
print(growth_summary, n = Inf)

cat("\n✓ Saved: 24_asset_growth_failed_vs_nonfailed.png (12\" × 8\", 300 DPI)\n")
