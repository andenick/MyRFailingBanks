# ==============================================================================
# Script 23: Deposit Outflow Dynamics by Era
# ==============================================================================
# Purpose: Show distribution of deposit growth for failed banks across eras
# Output:  23_deposit_outflow_dynamics.png (300 DPI)
# ==============================================================================

library(tidyverse)
library(here)
library(haven)
library(scales)

# Load Tableau color palette
source(here::here("code_expansion", "00_tableau_colors.R"))

# Set paths
output_dir <- here::here("code_expansion", "presentation_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Load historical deposit outflow data (1880-1934)
historical_data <- read_dta(here::here("dataclean", "deposits_before_failure_historical.dta")) %>%
  mutate(
    fdic_era = "Pre-FDIC (1880-1933)",
    era_detail = case_when(
      year >= 1880 & year < 1914 ~ "National Banking\n(1880-1913)",
      year >= 1914 & year <= 1928 ~ "Early Fed/WWI\n(1914-1928)",
      year >= 1929 & year <= 1933 ~ "Great Depression\n(1929-1933)",
      TRUE ~ "Other"
    )
  ) %>%
  filter(!is.na(growth_deposits), era_detail != "Other")

# Load modern deposit outflow data (1993-2024)
modern_data <- read_dta(here::here("dataclean", "deposits_before_failure_modern.dta")) %>%
  mutate(
    fdic_era = "Post-FDIC (1993-2024)",
    era_detail = case_when(
      year >= 1993 & year <= 2006 ~ "Modern Pre-Crisis\n(1993-2006)",
      year >= 2007 & year <= 2024 ~ "Financial Crisis\n(2007-2024)",
      TRUE ~ "Other"
    )
  ) %>%
  filter(!is.na(growth_deposits), era_detail != "Other")

# Combine datasets
combined_data <- bind_rows(
  historical_data %>% select(year, growth_deposits, fdic_era, era_detail),
  modern_data %>% select(year, growth_deposits, fdic_era, era_detail)
) %>%
  # Cap outliers at -100% and +100% for visualization
  mutate(
    growth_deposits_capped = pmin(pmax(growth_deposits, -100), 100),
    era_detail = factor(era_detail, levels = c(
      "National Banking\n(1880-1913)",
      "Early Fed/WWI\n(1914-1928)",
      "Great Depression\n(1929-1933)",
      "Modern Pre-Crisis\n(1993-2006)",
      "Financial Crisis\n(2007-2024)"
    ))
  )

# Calculate summary statistics
summary_stats <- combined_data %>%
  group_by(fdic_era, era_detail) %>%
  summarize(
    n = n(),
    mean_growth = mean(growth_deposits, na.rm = TRUE),
    median_growth = median(growth_deposits, na.rm = TRUE),
    sd_growth = sd(growth_deposits, na.rm = TRUE),
    pct_runs = sum(growth_deposits < -7.5, na.rm = TRUE) / n() * 100,
    .groups = "drop"
  )

# Define era colors
era_detail_colors <- c(
  "National Banking\n(1880-1913)" = color_national,
  "Early Fed/WWI\n(1914-1928)" = color_earlyfed,
  "Great Depression\n(1929-1933)" = color_depression,
  "Modern Pre-Crisis\n(1993-2006)" = color_modern,
  "Financial Crisis\n(2007-2024)" = color_crisis
)

# Create visualization
p <- ggplot(combined_data, aes(x = era_detail, y = growth_deposits_capped, fill = era_detail)) +
  geom_violin(alpha = 0.6, draw_quantiles = c(0.25, 0.5, 0.75), scale = "width") +
  geom_boxplot(width = 0.15, alpha = 0.8, outlier.size = 0.5) +
  geom_hline(yintercept = -7.5, linetype = "dashed", color = color_failure, linewidth = 0.8) +
  annotate("text", x = 0.7, y = -7.5, label = "Run Threshold (-7.5%)",
           hjust = 0, vjust = -0.5, size = 3, color = color_failure) +
  scale_y_continuous(
    name = "Deposit Growth (%)",
    breaks = seq(-100, 100, 25),
    labels = function(x) paste0(x, "%")
  ) +
  scale_x_discrete(name = "") +
  scale_fill_manual(
    name = "Era",
    values = era_detail_colors,
    guide = "none"
  ) +
  labs(
    title = "Deposit Dynamics Stabilize After FDIC: Pre-FDIC Volatility vs Post-FDIC Calm",
    subtitle = "Distribution of deposit growth for failed banks. Violin width proportional to frequency. Box plots show quartiles.",
    caption = "Source: OCC receivership records. Deposit growth capped at ±100% for visualization. Run threshold = -7.5% decline."
  ) +
  theme_failing_banks() +
  theme(
    axis.text.x = element_text(size = 9, angle = 0, hjust = 0.5)
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "23_deposit_outflow_dynamics.png"),
  plot = p,
  width = 14,
  height = 9,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== DEPOSIT OUTFLOW DYNAMICS BY ERA ===\n\n")
print(summary_stats, n = Inf)

cat("\n✓ Saved: 23_deposit_outflow_dynamics.png (14\" × 9\", 300 DPI)\n")
