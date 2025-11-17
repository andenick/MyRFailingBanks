# ==============================================================================
# Script 29: Deposit Structure Evolution
# ==============================================================================
# Purpose: Show deposit mix differences between failed and non-failed banks
# Output:  29_deposit_structure_evolution.png (300 DPI)
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

# Prepare data - focus on modern era where deposit breakdown is available
plot_data <- panel_data %>%
  filter(year >= 1959, !is.na(deposits), !is.na(deposits_time)) %>%
  mutate(
    bank_status = ifelse(failed_bank == 1, "Failed Banks", "Non-Failed Banks"),
    # Calculate deposit shares
    total_deposits = deposits,
    time_deposits = deposits_time,
    demand_deposits = deposits - deposits_time,
    # Convert to percentages of total deposits
    pct_time = (time_deposits / total_deposits) * 100,
    pct_demand = (demand_deposits / total_deposits) * 100
  ) %>%
  filter(!is.na(bank_status), !is.na(pct_time), !is.na(pct_demand))

# Calculate mean deposit shares by year and status
deposit_summary <- plot_data %>%
  group_by(year, bank_status) %>%
  summarize(
    mean_pct_demand = mean(pct_demand, na.rm = TRUE),
    mean_pct_time = mean(pct_time, na.rm = TRUE),
    n_obs = n(),
    .groups = "drop"
  ) %>%
  # Reshape for stacked area chart
  pivot_longer(
    cols = c(mean_pct_demand, mean_pct_time),
    names_to = "deposit_type",
    values_to = "percentage"
  ) %>%
  mutate(
    deposit_type = case_when(
      deposit_type == "mean_pct_demand" ~ "Demand Deposits",
      deposit_type == "mean_pct_time" ~ "Time Deposits",
      TRUE ~ "Other"
    ),
    deposit_type = factor(deposit_type, levels = c("Demand Deposits", "Time Deposits"))
  )

# Define deposit type colors
deposit_colors <- c(
  "Demand Deposits" = color_modern,      # Blue
  "Time Deposits" = color_historical     # Orange
)

# Create visualization
p <- ggplot(deposit_summary, aes(x = year, y = percentage, fill = deposit_type)) +
  geom_area(alpha = 0.7, position = "stack") +
  facet_wrap(~ bank_status, ncol = 1) +
  scale_x_continuous(
    name = "Year",
    breaks = seq(1960, 2020, 10)
  ) +
  scale_y_continuous(
    name = "% of Total Deposits",
    breaks = seq(0, 100, 25),
    labels = function(x) paste0(x, "%"),
    limits = c(0, 100)
  ) +
  scale_fill_manual(
    name = "Deposit Type",
    values = deposit_colors
  ) +
  labs(
    title = "Failed Banks Show Different Deposit Mix: More Volatile Time Deposits",
    subtitle = "Composition of deposits by type (1959-2024). Stacked area shows % of total deposits.",
    caption = "Source: Combined panel dataset. Demand deposits = checking/transaction accounts. Time deposits = CDs, savings."
  ) +
  theme_failing_banks() +
  theme(
    strip.text = element_text(face = "bold", size = 11),
    strip.background = element_rect(fill = "gray90", color = NA),
    panel.spacing = unit(1.5, "lines")
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "29_deposit_structure_evolution.png"),
  plot = p,
  width = 12,
  height = 10,
  dpi = 300,
  bg = "white"
)

# Calculate overall summary statistics
overall_summary <- plot_data %>%
  group_by(bank_status) %>%
  summarize(
    mean_pct_demand = mean(pct_demand, na.rm = TRUE),
    mean_pct_time = mean(pct_time, na.rm = TRUE),
    n_obs = n(),
    .groups = "drop"
  )

cat("\n=== DEPOSIT STRUCTURE: FAILED VS NON-FAILED ===\n\n")
print(overall_summary, n = Inf)

cat("\n✓ Saved: 29_deposit_structure_evolution.png (12\" × 10\", 300 DPI)\n")
