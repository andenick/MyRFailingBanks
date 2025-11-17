# ==============================================================================
# Script 14: Funding Structure Evolution
# ==============================================================================
# Purpose: Stacked area chart showing evolution of funding sources
#          (deposits, noncore funding, equity) over 160 years
# Output:  14_funding_structure_evolution.png (300 DPI)
# ==============================================================================

library(tidyverse)
library(here)
library(scales)

# Load Tableau color palette
source(here::here("code_expansion", "00_tableau_colors.R"))

# Set paths
dataclean_dir <- here::here("dataclean")
output_dir <- here::here("code_expansion", "presentation_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Load panel data
panel_data <- readRDS(file.path(dataclean_dir, "combined-data.rds"))

# Prepare data: calculate funding composition
funding_data <- panel_data %>%
  filter(!is.na(deposit_ratio), !is.na(leverage), !is.na(year)) %>%
  mutate(
    equity_ratio = leverage,
    deposit_share = pmin(deposit_ratio, 1) * 100,
    noncore_share = pmin(ifelse(is.na(noncore_ratio), 0, noncore_ratio), 1) * 100,
    equity_share = pmin(equity_ratio, 1) * 100,
    other_share = pmax(0, 100 - deposit_share - noncore_share - equity_share)
  ) %>%
  group_by(year) %>%
  summarize(
    Deposits = mean(deposit_share, na.rm = TRUE),
    `Noncore Funding` = mean(noncore_share, na.rm = TRUE),
    Equity = mean(equity_share, na.rm = TRUE),
    `Other Liabilities` = mean(other_share, na.rm = TRUE),
    n_banks = n(),
    .groups = "drop"
  ) %>%
  filter(n_banks >= 50) %>%
  pivot_longer(
    cols = c(Deposits, `Noncore Funding`, Equity, `Other Liabilities`),
    names_to = "Funding_Source",
    values_to = "Share"
  ) %>%
  mutate(
    Funding_Source = factor(Funding_Source,
                           levels = c("Deposits", "Noncore Funding", "Other Liabilities", "Equity"))
  )

# Create visualization
p <- ggplot(funding_data, aes(x = year, y = Share, fill = Funding_Source)) +
  geom_area(alpha = 0.8, color = "white", linewidth = 0.3) +
  annotate("rect", xmin = 1929, xmax = 1933, ymin = 0, ymax = 100, fill = "gray30", alpha = 0.1) +
  annotate("text", x = 1931, y = 95, label = "Great Depression", size = 3, color = "gray30") +
  annotate("rect", xmin = 2007, xmax = 2009, ymin = 0, ymax = 100, fill = "gray30", alpha = 0.1) +
  annotate("text", x = 2008, y = 95, label = "Financial Crisis", size = 3, color = "gray30") +
  scale_x_continuous(
    name = "Year",
    breaks = seq(1860, 2020, 20),
    limits = c(1863, 2024)
  ) +
  scale_y_continuous(
    name = "Share of Total Funding (%)",
    breaks = seq(0, 100, 20),
    limits = c(0, 100)
  ) +
  scale_fill_manual(
    name = "Funding Source",
    values = c(
      "Deposits" = "#2ca02c",
      "Noncore Funding" = "#ff7f0e",
      "Other Liabilities" = "#d62728",
      "Equity" = "#1f77b4"
    )
  ) +
  labs(
    title = "Evolution of Bank Funding Structure (1863-2024)",
    subtitle = "Deposits remain dominant funding source. Noncore funding grows in modern era, equity declines.",
    caption = "Source: Combined call reports. Stacked area shows average funding composition across all banks each year."
  ) +
  theme_failing_banks() +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 10),
    panel.grid.minor = element_blank()
  ) +
  guides(fill = guide_legend(nrow = 1))

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "14_funding_structure_evolution.png"),
  plot = p,
  width = 14,
  height = 8,
  dpi = 300,
  bg = "white"
)

cat("\n=== FUNDING STRUCTURE EVOLUTION ===\n")
cat(sprintf("Years covered: %d to %d\n", min(funding_data$year), max(funding_data$year)))

cat("\n✓ Saved: 14_funding_structure_evolution.png (14\" × 8\", 300 DPI)\n")
