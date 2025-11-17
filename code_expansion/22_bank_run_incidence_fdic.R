# ==============================================================================
# Script 22: Bank Run Incidence Pre vs Post-FDIC
# ==============================================================================
# Purpose: Show dramatic reduction in bank runs after FDIC establishment (1934)
# Output:  22_bank_run_incidence_fdic.png (300 DPI)
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
    era = "Pre-FDIC",
    run = ifelse(!is.na(run), run, 0)
  ) %>%
  filter(!is.na(year), year >= 1880, year <= 1933)

# Load modern deposit outflow data (1993-2024)
modern_data <- read_dta(here::here("dataclean", "deposits_before_failure_modern.dta")) %>%
  mutate(
    era = "Post-FDIC",
    run = ifelse(!is.na(run), run, 0)
  ) %>%
  filter(!is.na(year))

# Combine datasets
combined_data <- bind_rows(
  historical_data %>% select(year, run, era),
  modern_data %>% select(year, run, era)
)

# Calculate annual run incidence (% of banks experiencing runs)
run_incidence <- combined_data %>%
  group_by(year, era) %>%
  summarize(
    total_banks = n(),
    banks_with_runs = sum(run == 1, na.rm = TRUE),
    run_incidence_pct = (banks_with_runs / total_banks) * 100,
    .groups = "drop"
  )

# Calculate summary statistics
summary_stats <- run_incidence %>%
  group_by(era) %>%
  summarize(
    mean_run_incidence = mean(run_incidence_pct, na.rm = TRUE),
    median_run_incidence = median(run_incidence_pct, na.rm = TRUE),
    max_run_incidence = max(run_incidence_pct, na.rm = TRUE),
    years_observed = n(),
    .groups = "drop"
  )

# Create visualization
p <- ggplot(run_incidence, aes(x = year, y = run_incidence_pct, color = era)) +
  geom_line(linewidth = 1.2, alpha = 0.8) +
  geom_point(size = 1.5, alpha = 0.6) +
  geom_vline(xintercept = 1934, linetype = "dashed", color = color_neutral, linewidth = 0.8) +
  annotate("text", x = 1934, y = max(run_incidence$run_incidence_pct, na.rm = TRUE) * 0.95,
           label = "FDIC Established\n(1934)", hjust = -0.1, vjust = 1, size = 3.5, color = color_neutral) +
  scale_x_continuous(
    name = "Year",
    breaks = c(1880, 1900, 1920, 1934, 1960, 1980, 2000, 2020),
    limits = c(1880, 2024)
  ) +
  scale_y_continuous(
    name = "Bank Run Incidence (%)",
    breaks = seq(0, 100, 10),
    labels = function(x) paste0(x, "%")
  ) +
  scale_color_manual(
    name = "Era",
    values = fdic_colors
  ) +
  labs(
    title = "Bank Runs Virtually Eliminated After FDIC Establishment",
    subtitle = "Annual percentage of failed banks experiencing deposit runs (>7.5% deposit decline)",
    caption = "Source: OCC receivership records. Run = deposit decline >7.5% in period before failure. FDIC deposit insurance established 1934."
  ) +
  theme_failing_banks()

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "22_bank_run_incidence_fdic.png"),
  plot = p,
  width = 12,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== BANK RUN INCIDENCE: PRE VS POST FDIC ===\n\n")
print(summary_stats, n = Inf)

cat("\n✓ Saved: 22_bank_run_incidence_fdic.png (12\" × 8\", 300 DPI)\n")
