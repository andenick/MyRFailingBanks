# ==============================================================================
# Script 25: Total Assets Evolution by Risk Quintile
# ==============================================================================
# Purpose: Show asset levels and volatility by predicted failure risk
# Output:  25_total_assets_risk_quintile.png (300 DPI)
# ==============================================================================

library(tidyverse)
library(here)
library(scales)

# Load Tableau color palette
source(here::here("code_expansion", "00_tableau_colors.R"))

# Set paths
tempfiles_dir <- here::here("tempfiles")
output_dir <- here::here("code_expansion", "presentation_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Load regression data with predicted probabilities
reg_data <- readRDS(file.path(tempfiles_dir, "temp_reg_data.rds"))

# Create risk quintiles based on predicted probability
risk_data <- reg_data %>%
  filter(!is.na(pred_prob_F1), !is.na(assets), !is.na(year)) %>%
  mutate(
    risk_quintile = ntile(pred_prob_F1, 5),
    risk_label = case_when(
      risk_quintile == 1 ~ "Q1 (Lowest Risk)",
      risk_quintile == 2 ~ "Q2 (Low Risk)",
      risk_quintile == 3 ~ "Q3 (Medium Risk)",
      risk_quintile == 4 ~ "Q4 (High Risk)",
      risk_quintile == 5 ~ "Q5 (Highest Risk)",
      TRUE ~ "Other"
    ),
    risk_label = factor(risk_label, levels = c(
      "Q1 (Lowest Risk)",
      "Q2 (Low Risk)",
      "Q3 (Medium Risk)",
      "Q4 (High Risk)",
      "Q5 (Highest Risk)"
    ))
  ) %>%
  filter(!is.na(risk_label))

# Calculate mean assets by year and risk quintile
assets_summary <- risk_data %>%
  group_by(year, risk_label) %>%
  summarize(
    mean_assets = mean(assets, na.rm = TRUE),
    median_assets = median(assets, na.rm = TRUE),
    n_banks = n(),
    .groups = "drop"
  )

# Define risk quintile colors (gradient from green to red)
risk_colors <- c(
  "Q1 (Lowest Risk)" = color_success,     # Green
  "Q2 (Low Risk)" = color_modern,         # Blue
  "Q3 (Medium Risk)" = color_neutral,     # Gray
  "Q4 (High Risk)" = color_historical,    # Orange
  "Q5 (Highest Risk)" = color_failure     # Red
)

# Create visualization
p <- ggplot(assets_summary, aes(x = year, y = mean_assets / 1e6, color = risk_label)) +
  geom_line(linewidth = 1.2, alpha = 0.8) +
  scale_x_continuous(
    name = "Year",
    breaks = c(1860, 1880, 1900, 1920, 1940, 1960, 1980, 2000, 2020)
  ) +
  scale_y_log10(
    name = "Mean Total Assets ($ millions, log scale)",
    labels = scales::dollar_format(prefix = "$", suffix = "M")
  ) +
  scale_color_manual(
    name = "Risk Quintile",
    values = risk_colors
  ) +
  labs(
    title = "High-Risk Banks Are Smaller and More Volatile",
    subtitle = "Mean total assets by predicted failure probability quintile (1863-2024). Log scale.",
    caption = "Source: Regression dataset with predicted failure probabilities. Risk quintiles based on model-predicted F1 failure probability."
  ) +
  theme_failing_banks()

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "25_total_assets_risk_quintile.png"),
  plot = p,
  width = 12,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
summary_stats <- risk_data %>%
  group_by(risk_label) %>%
  summarize(
    n_banks = n(),
    mean_assets = mean(assets, na.rm = TRUE),
    median_assets = median(assets, na.rm = TRUE),
    mean_pred_prob = mean(pred_prob_F1, na.rm = TRUE),
    .groups = "drop"
  )

cat("\n=== TOTAL ASSETS BY RISK QUINTILE ===\n\n")
print(summary_stats, n = Inf)

cat("\n✓ Saved: 25_total_assets_risk_quintile.png (12\" × 8\", 300 DPI)\n")
