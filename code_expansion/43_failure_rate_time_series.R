# ==============================================================================
# Script 43: Failure Rate Time Series - Pre vs Post FDIC
# ==============================================================================
# Purpose: Show annual bank failure rate (% of all banks) from 1863-2024
#          Dramatic reduction post-1934, but NOT zero
# Output:  43_failure_rate_time_series.png (300 DPI)
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

# Calculate annual failure rates
failure_rates <- panel_data %>%
  group_by(year) %>%
  summarize(
    total_banks = n_distinct(bank_id),
    failed_banks = sum(failed_bank == 1, na.rm = TRUE),
    failure_rate = (failed_banks / total_banks) * 100,
    .groups = "drop"
  ) %>%
  mutate(
    fdic_era = ifelse(year < 1934, "Pre-FDIC (1863-1933)", "Post-FDIC (1934-2024)"),
    fdic_era = factor(fdic_era, levels = c("Pre-FDIC (1863-1933)", "Post-FDIC (1934-2024)"))
  )

# Calculate era-specific summary statistics
era_summary <- failure_rates %>%
  group_by(fdic_era) %>%
  summarize(
    mean_rate = mean(failure_rate, na.rm = TRUE),
    median_rate = median(failure_rate, na.rm = TRUE),
    max_rate = max(failure_rate, na.rm = TRUE),
    years = n(),
    .groups = "drop"
  )

# Create visualization
p <- ggplot(failure_rates, aes(x = year, y = failure_rate)) +
  # Era shading
  annotate("rect", xmin = 1863, xmax = 1933, ymin = 0, ymax = Inf,
           fill = color_historical, alpha = 0.1) +
  annotate("rect", xmin = 1934, xmax = 2024, ymin = 0, ymax = Inf,
           fill = color_modern, alpha = 0.1) +
  # Failure rate line
  geom_line(aes(color = fdic_era), linewidth = 1) +
  geom_point(aes(color = fdic_era), size = 1.5, alpha = 0.6) +
  # FDIC marker
  geom_vline(xintercept = 1934, linetype = "dashed", color = color_neutral, linewidth = 1) +
  annotate("text", x = 1934, y = max(failure_rates$failure_rate) * 0.95,
           label = "FDIC Established\n(1934)", hjust = -0.1, size = 3.5, color = color_neutral) +
  scale_x_continuous(
    name = "Year",
    breaks = seq(1860, 2020, 20)
  ) +
  scale_y_continuous(
    name = "Annual Failure Rate (%)",
    labels = function(x) paste0(x, "%"),
    trans = "log10"
  ) +
  scale_color_manual(
    name = "Era",
    values = fdic_colors
  ) +
  labs(
    title = "Bank Failures Plummet After FDIC: 90%+ Reduction in Failure Rates",
    subtitle = "Annual bank failure rate (% of all banks) 1863-2024. Log scale. FDIC reduced but didn't eliminate failures.",
    caption = "Source: Combined panel dataset. Failure rate = (failed banks / total banks) × 100. Note S&L Crisis (1980s) and GFC (2008) spikes."
  ) +
  theme_failing_banks() +
  theme(legend.position = "bottom")

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "43_failure_rate_time_series.png"),
  plot = p,
  width = 14,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== FAILURE RATE TIME SERIES: PRE VS POST FDIC ===\n\n")
print(era_summary, n = Inf)

cat("\n✓ Saved: 43_failure_rate_time_series.png (14\" × 8\", 300 DPI)\n")
