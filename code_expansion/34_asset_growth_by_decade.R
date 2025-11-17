# ==============================================================================
# Script 34: Asset Growth by Decade (Last Call to Failure)
# ==============================================================================
# Purpose: Show asset growth from last call report to failure by decade
# Output:  34_asset_growth_by_decade.png (300 DPI)
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

# Focus on failed banks and calculate decade
failed_banks <- panel_data %>%
  filter(failed_bank == 1, !is.na(growth), !is.na(year)) %>%
  mutate(
    decade = (year %/% 10) * 10,
    decade_label = paste0(decade, "s")
  ) %>%
  filter(decade >= 1860, decade <= 2020)

# Calculate asset growth statistics by decade
growth_by_decade <- failed_banks %>%
  group_by(decade, decade_label) %>%
  summarize(
    n = n(),
    mean_growth = mean(growth, na.rm = TRUE),
    median_growth = median(growth, na.rm = TRUE),
    sd_growth = sd(growth, na.rm = TRUE),
    q25 = quantile(growth, 0.25, na.rm = TRUE),
    q75 = quantile(growth, 0.75, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(decade)

# Create decade-specific colors using Tableau palette
decade_colors <- rep(tableau_colors, length.out = nrow(growth_by_decade))
names(decade_colors) <- growth_by_decade$decade_label

# Create visualization (box plot by decade)
p <- ggplot(failed_banks, aes(x = factor(decade), y = growth, fill = decade_label)) +
  geom_boxplot(alpha = 0.7, outlier.size = 0.8, outlier.alpha = 0.4) +
  geom_hline(yintercept = 0, linetype = "dashed", color = color_neutral, linewidth = 0.8) +
  scale_x_discrete(
    name = "Decade",
    labels = function(x) paste0(x, "s")
  ) +
  scale_y_continuous(
    name = "Asset Growth (%)",
    breaks = seq(-100, 200, 50),
    labels = function(x) paste0(x, "%")
  ) +
  scale_fill_manual(
    name = "Decade",
    values = decade_colors,
    guide = "none"
  ) +
  labs(
    title = "Failed Banks Show Boom-Bust Pattern Across All Decades",
    subtitle = "Distribution of asset growth for failed banks by decade (1860s-2020s). Box plots show quartiles.",
    caption = "Source: Combined panel dataset. Asset growth calculated year-over-year. Dashed line = zero growth."
  ) +
  theme_failing_banks() +
  theme(
    axis.text.x = element_text(size = 9, angle = 45, hjust = 1)
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "34_asset_growth_by_decade.png"),
  plot = p,
  width = 14,
  height = 9,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== ASSET GROWTH BY DECADE (FAILED BANKS) ===\n\n")
print(growth_by_decade, n = Inf)

cat("\n✓ Saved: 34_asset_growth_by_decade.png (14\" × 9\", 300 DPI)\n")
