# ==============================================================================
# Script 15: Profitability vs Risk (Modern Era)
# ==============================================================================
# Purpose: Scatter plot showing relationship between income and NPL ratio
#          in modern era (1984-2024), colored by failure outcome
# Output:  15_profitability_vs_risk_modern.png (300 DPI)
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

# Prepare data: modern era only
plot_data <- panel_data %>%
  filter(year >= 1984, year <= 2024) %>%
  filter(!is.na(income_ratio), !is.na(npl_ratio), !is.na(failed)) %>%
  filter(income_ratio >= -0.05, income_ratio <= 0.05) %>% # Reasonable income range
  filter(npl_ratio >= 0, npl_ratio <= 0.50) %>% # Reasonable NPL range
  mutate(
    failure_status = ifelse(failed == 1, "Failed Within 3 Years", "Did Not Fail"),
    period = case_when(
      year >= 1984 & year <= 1995 ~ "1984-1995\nS&L Crisis",
      year >= 1996 & year <= 2006 ~ "1996-2006\nPre-Financial Crisis",
      year >= 2007 & year <= 2015 ~ "2007-2015\nFinancial Crisis",
      year >= 2016 & year <= 2024 ~ "2016-2024\nPost-Crisis",
      TRUE ~ "Other"
    )
  ) %>%
  filter(period != "Other") %>%
  # Sample for performance
  group_by(period, failure_status) %>%
  sample_n(min(n(), 300)) %>%
  ungroup()

# Create visualization
p <- ggplot(plot_data, aes(x = income_ratio * 100, y = npl_ratio * 100, color = failure_status)) +
  geom_point(alpha = 0.4, size = 2) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.5) +
  facet_wrap(~ period, ncol = 2) +
  scale_x_continuous(
    name = "Net Income / Assets (%)",
    breaks = seq(-5, 5, 2),
    limits = c(-5, 5)
  ) +
  scale_y_continuous(
    name = "Non-Performing Loans / Total Loans (%)",
    breaks = seq(0, 50, 10),
    limits = c(0, 50)
  ) +
  scale_color_manual(
    name = "",
    values = c("Failed Within 3 Years" = "#d62728", "Did Not Fail" = "#2ca02c")
  ) +
  labs(
    title = "Failed Banks Show Low Profitability and High Non-Performing Loans",
    subtitle = "Modern era (1984-2024): Failed banks cluster in upper-left quadrant (negative income, high NPLs)",
    caption = "Source: Modern call reports. Sample limited to 300 banks per period-status for visualization clarity."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0),
    legend.position = "bottom",
    legend.text = element_text(size = 11),
    strip.text = element_text(face = "bold", size = 10),
    strip.background = element_rect(fill = "gray90", color = NA),
    panel.grid.minor = element_blank(),
    panel.spacing = unit(0.8, "lines")
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "15_profitability_vs_risk_modern.png"),
  plot = p,
  width = 12,
  height = 10,
  dpi = 300,
  bg = "white"
)

cat("\n=== PROFITABILITY VS RISK (MODERN ERA) ===\n")
cat(sprintf("Total observations plotted: %d\n", nrow(plot_data)))
cat(sprintf("Failed banks: %d\n", sum(plot_data$failure_status == "Failed Within 3 Years")))

cat("\n✓ Saved: 15_profitability_vs_risk_modern.png (12\" × 10\", 300 DPI)\n")
