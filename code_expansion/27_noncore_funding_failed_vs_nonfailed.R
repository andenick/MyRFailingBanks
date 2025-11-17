# ==============================================================================
# Script 27: Noncore Funding Ratio - Failed vs Non-Failed
# ==============================================================================
# Purpose: Show failed banks rely more on volatile noncore funding
# Output:  27_noncore_funding_failed_vs_nonfailed.png (300 DPI)
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
plot_data <- panel_data %>%
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
  filter(!is.na(noncore_ratio), !is.na(period), period != "Other", !is.na(bank_status))

# Calculate mean noncore funding ratio by period and status
noncore_summary <- plot_data %>%
  group_by(period, bank_status) %>%
  summarize(
    mean_noncore = mean(noncore_ratio, na.rm = TRUE) * 100,
    se_noncore = sd(noncore_ratio, na.rm = TRUE) / sqrt(n()) * 100,
    n_obs = n(),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = mean_noncore - 1.96 * se_noncore,
    ci_upper = mean_noncore + 1.96 * se_noncore
  )

# Create visualization
p <- ggplot(noncore_summary, aes(x = period, y = mean_noncore, fill = bank_status)) +
  geom_col(position = position_dodge(width = 0.8), alpha = 0.8, width = 0.7) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper),
                position = position_dodge(width = 0.8), width = 0.25, linewidth = 0.7) +
  scale_y_continuous(
    name = "Noncore Funding Ratio (%)",
    labels = function(x) paste0(x, "%")
  ) +
  scale_x_discrete(name = "") +
  scale_fill_manual(
    name = "Bank Status",
    values = comparison_colors
  ) +
  labs(
    title = "Failed Banks Rely More on Volatile Noncore Funding",
    subtitle = "Mean noncore funding as % of assets by period. Error bars show 95% confidence intervals.",
    caption = "Source: Combined panel dataset (1863-2023). Noncore funding = residual funding (pre-1941) or time deposits + other borrowing (post-1941)."
  ) +
  theme_failing_banks() +
  theme(
    axis.text.x = element_text(size = 9, angle = 0, hjust = 0.5)
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "27_noncore_funding_failed_vs_nonfailed.png"),
  plot = p,
  width = 12,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== NONCORE FUNDING RATIO: FAILED VS NON-FAILED ===\n\n")
print(noncore_summary, n = Inf)

cat("\n✓ Saved: 27_noncore_funding_failed_vs_nonfailed.png (12\" × 8\", 300 DPI)\n")
