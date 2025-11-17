# ==============================================================================
# Script 13: Liquidity-Loans Trade-off
# ==============================================================================
# Purpose: Scatter plot by decade showing trade-off between safety (liquidity)
#          and profitability (loans), colored by failure outcome
# Output:  13_liquidity_loans_tradeoff.png (300 DPI)
# ==============================================================================

library(tidyverse)
library(here)
library(scales)

# Set paths
dataclean_dir <- here::here("dataclean")
output_dir <- here::here("code_expansion", "presentation_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Load panel data
panel_data <- readRDS(file.path(dataclean_dir, "combined-data.rds"))

# Prepare data: sample by decade
plot_data <- panel_data %>%
  filter(!is.na(liquid_ratio), !is.na(loan_ratio), !is.na(year), !is.na(failed)) %>%
  filter(liquid_ratio >= 0, liquid_ratio <= 1, loan_ratio >= 0, loan_ratio <= 1) %>%
  mutate(
    decade = case_when(
      year >= 1860 & year < 1900 ~ "1860-1899",
      year >= 1900 & year < 1930 ~ "1900-1929",
      year >= 1930 & year < 1950 ~ "1930-1949",
      year >= 1960 & year < 1990 ~ "1960-1989",
      year >= 1990 & year < 2010 ~ "1990-2009",
      year >= 2010 ~ "2010-2024",
      TRUE ~ "Other"
    ),
    failure_status = ifelse(failed == 1, "Failed", "Non-Failed")
  ) %>%
  filter(decade != "Other") %>%
  # Sample for visualization performance
  group_by(decade, failure_status) %>%
  sample_n(min(n(), 500)) %>%
  ungroup()

# Create visualization
p <- ggplot(plot_data, aes(x = liquid_ratio * 100, y = loan_ratio * 100, color = failure_status)) +
  geom_point(alpha = 0.3, size = 1.5) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 1.2, alpha = 0.8) +
  facet_wrap(~ decade, ncol = 3) +
  scale_x_continuous(
    name = "Liquidity Ratio: Liquid Assets / Total Assets (%)",
    breaks = seq(0, 100, 25)
  ) +
  scale_y_continuous(
    name = "Loan Ratio: Loans / Total Assets (%)",
    breaks = seq(0, 100, 25)
  ) +
  scale_color_manual(
    name = "Bank Status",
    values = c("Failed" = "#d62728", "Non-Failed" = "#2ca02c")
  ) +
  labs(
    title = "Failed Banks Hold More Loans, Less Liquidity Across All Eras",
    subtitle = "Negative relationship between liquidity and loans. Failed banks consistently choose riskier asset mix.",
    caption = "Source: Combined call reports. Each point represents one bank-year observation. Sample limited to 500 per decade-status."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 10),
    strip.text = element_text(face = "bold", size = 10),
    strip.background = element_rect(fill = "gray90", color = NA),
    panel.grid.minor = element_blank(),
    panel.spacing = unit(0.8, "lines")
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "13_liquidity_loans_tradeoff.png"),
  plot = p,
  width = 14,
  height = 10,
  dpi = 300,
  bg = "white"
)

cat("\n=== LIQUIDITY-LOANS TRADE-OFF ===\n")
cat(sprintf("Total observations plotted: %d\n", nrow(plot_data)))
cat(sprintf("Decades covered: %d\n", n_distinct(plot_data$decade)))

cat("\n✓ Saved: 13_liquidity_loans_tradeoff.png (14\" × 10\", 300 DPI)\n")
