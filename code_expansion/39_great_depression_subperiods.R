# ==============================================================================
# Script 39: Great Depression Sub-periods (1929-1935)
# ==============================================================================
# Purpose: Break Depression into 4 sub-periods and show fundamentals deterioration
#          by quarter where possible
# Output:  39_great_depression_subperiods.png (300 DPI)
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

# Filter to Depression period and create sub-periods
depression_data <- panel_data %>%
  filter(year >= 1929 & year <= 1935) %>%
  mutate(
    subperiod = case_when(
      year == 1929 | year == 1930 ~ "1. Stock Crash\n(1929-1930)",
      year == 1931 | year == 1932 ~ "2. Banking Panics\n(1931-1932)",
      year == 1933 & quarter <= 1 ~ "3. Bank Holiday\n(Q1 1933)",
      year >= 1933 ~ "4. FDIC Recovery\n(1933-1935)",
      TRUE ~ "Other"
    ),
    subperiod = factor(subperiod, levels = c(
      "1. Stock Crash\n(1929-1930)",
      "2. Banking Panics\n(1931-1932)",
      "3. Bank Holiday\n(Q1 1933)",
      "4. FDIC Recovery\n(1933-1935)"
    ))
  ) %>%
  filter(subperiod != "Other")

# Calculate key metrics by subperiod
metrics_summary <- depression_data %>%
  group_by(subperiod) %>%
  summarize(
    n_banks = n_distinct(bank_id),
    failures = sum(failed_bank == 1, na.rm = TRUE),
    failure_rate = (failures / n_banks) * 100,
    mean_leverage = mean(leverage, na.rm = TRUE) * 100,
    mean_liquidity = mean(liquid_ratio, na.rm = TRUE) * 100,
    mean_deposits = mean(deposits, na.rm = TRUE) / 1e6,
    .groups = "drop"
  )

# Reshape for visualization
metrics_long <- metrics_summary %>%
  select(subperiod, failure_rate, mean_leverage, mean_liquidity) %>%
  pivot_longer(cols = -subperiod, names_to = "metric", values_to = "value") %>%
  mutate(
    metric_label = case_when(
      metric == "failure_rate" ~ "Failure Rate (%)",
      metric == "mean_leverage" ~ "Leverage (%)",
      metric == "mean_liquidity" ~ "Liquidity (%)",
      TRUE ~ metric
    ),
    metric_label = factor(metric_label, levels = c(
      "Failure Rate (%)",
      "Leverage (%)",
      "Liquidity (%)"
    ))
  )

# Define subperiod colors
subperiod_colors <- c(
  "1. Stock Crash\n(1929-1930)" = tableau_colors[9],
  "2. Banking Panics\n(1931-1932)" = color_depression,
  "3. Bank Holiday\n(Q1 1933)" = color_failure,
  "4. FDIC Recovery\n(1933-1935)" = color_success
)

# Create visualization
p <- ggplot(metrics_long, aes(x = subperiod, y = value, fill = subperiod)) +
  geom_col(alpha = 0.8, width = 0.7) +
  facet_wrap(~ metric_label, ncol = 1, scales = "free_y") +
  scale_x_discrete(name = "") +
  scale_y_continuous(name = "Value") +
  scale_fill_manual(
    name = "Sub-Period",
    values = subperiod_colors,
    guide = "none"
  ) +
  labs(
    title = "Great Depression in 4 Acts: From Stock Crash to FDIC Recovery",
    subtitle = "Key metrics by Depression sub-period. Failure rate peaks during bank holiday, then drops with FDIC.",
    caption = "Source: Combined panel dataset (1929-1935). FDIC established 1934. Bank holiday = March 1933."
  ) +
  theme_failing_banks() +
  theme(
    strip.text = element_text(face = "bold", size = 11),
    strip.background = element_rect(fill = "gray90", color = NA),
    panel.spacing = unit(1.5, "lines"),
    axis.text.x = element_text(size = 9, angle = 0, hjust = 0.5)
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "39_great_depression_subperiods.png"),
  plot = p,
  width = 12,
  height = 12,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== GREAT DEPRESSION SUB-PERIODS ===\n\n")
print(metrics_summary, n = Inf)

cat("\n✓ Saved: 39_great_depression_subperiods.png (12\" × 12\", 300 DPI)\n")
