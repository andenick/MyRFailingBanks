# ==============================================================================
# Script 35: Asset Growth by Crisis Period
# ==============================================================================
# Purpose: Compare asset growth dynamics across major financial crises
# Output:  35_asset_growth_by_crisis.png (300 DPI)
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

# Define crisis periods
crisis_data <- panel_data %>%
  filter(failed_bank == 1, !is.na(growth), !is.na(year)) %>%
  mutate(
    crisis_period = case_when(
      year >= 1890 & year <= 1896 ~ "Panic of 1893\n(1890-1896)",
      year >= 1904 & year <= 1910 ~ "Panic of 1907\n(1904-1910)",
      year >= 1926 & year <= 1934 ~ "Great Depression\n(1926-1934)",
      year >= 1986 & year <= 1992 ~ "S&L Crisis\n(1986-1992)",
      year >= 2004 & year <= 2012 ~ "Financial Crisis\n(2004-2012)",
      TRUE ~ "Other"
    ),
    crisis_period = factor(crisis_period, levels = c(
      "Panic of 1893\n(1890-1896)",
      "Panic of 1907\n(1904-1910)",
      "Great Depression\n(1926-1934)",
      "S&L Crisis\n(1986-1992)",
      "Financial Crisis\n(2004-2012)"
    ))
  ) %>%
  filter(crisis_period != "Other")

# Calculate asset growth statistics by crisis
growth_by_crisis <- crisis_data %>%
  group_by(crisis_period) %>%
  summarize(
    n = n(),
    mean_growth = mean(growth, na.rm = TRUE),
    median_growth = median(growth, na.rm = TRUE),
    sd_growth = sd(growth, na.rm = TRUE),
    .groups = "drop"
  )

# Define crisis-specific colors
crisis_colors <- c(
  "Panic of 1893\n(1890-1896)" = color_national,
  "Panic of 1907\n(1904-1910)" = color_earlyfed,
  "Great Depression\n(1926-1934)" = color_depression,
  "S&L Crisis\n(1986-1992)" = color_modern,
  "Financial Crisis\n(2004-2012)" = color_crisis
)

# Create faceted time series for each crisis
crisis_timeseries <- crisis_data %>%
  mutate(
    # Create relative year (years from crisis midpoint)
    relative_year = case_when(
      crisis_period == "Panic of 1893\n(1890-1896)" ~ year - 1893,
      crisis_period == "Panic of 1907\n(1904-1910)" ~ year - 1907,
      crisis_period == "Great Depression\n(1926-1934)" ~ year - 1930,
      crisis_period == "S&L Crisis\n(1986-1992)" ~ year - 1989,
      crisis_period == "Financial Crisis\n(2004-2012)" ~ year - 2008,
      TRUE ~ 0
    )
  ) %>%
  group_by(crisis_period, relative_year) %>%
  summarize(
    mean_growth = mean(growth, na.rm = TRUE),
    se_growth = sd(growth, na.rm = TRUE) / sqrt(n()),
    n_obs = n(),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = mean_growth - 1.96 * se_growth,
    ci_upper = mean_growth + 1.96 * se_growth
  )

# Create visualization
p <- ggplot(crisis_timeseries, aes(x = relative_year, y = mean_growth, color = crisis_period, fill = crisis_period)) +
  geom_ribbon(aes(ymin = ci_lower, ymax = ci_upper), alpha = 0.2, color = NA) +
  geom_line(linewidth = 1.5, alpha = 0.9) +
  geom_point(size = 2.5, alpha = 0.9) +
  geom_hline(yintercept = 0, linetype = "dashed", color = color_neutral, linewidth = 0.8) +
  geom_vline(xintercept = 0, linetype = "dotted", color = color_failure, linewidth = 0.8) +
  facet_wrap(~ crisis_period, ncol = 2, scales = "free_x") +
  scale_x_continuous(
    name = "Years Relative to Crisis Peak",
    breaks = seq(-6, 6, 2)
  ) +
  scale_y_continuous(
    name = "Mean Asset Growth (%)",
    labels = function(x) paste0(x, "%")
  ) +
  scale_color_manual(
    name = "Crisis",
    values = crisis_colors,
    guide = "none"
  ) +
  scale_fill_manual(
    name = "Crisis",
    values = crisis_colors,
    guide = "none"
  ) +
  labs(
    title = "Consistent Boom-Bust Pattern Across All Major Financial Crises",
    subtitle = "Mean asset growth for failed banks in 3-year windows around each crisis. Ribbons = 95% CI. Dotted line = crisis peak.",
    caption = "Source: Combined panel dataset. Asset growth calculated year-over-year for failed banks. Pattern consistent across 120 years."
  ) +
  theme_failing_banks() +
  theme(
    strip.text = element_text(face = "bold", size = 9),
    strip.background = element_rect(fill = "gray90", color = NA),
    panel.spacing = unit(1, "lines")
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "35_asset_growth_by_crisis.png"),
  plot = p,
  width = 14,
  height = 10,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== ASSET GROWTH BY CRISIS PERIOD (FAILED BANKS) ===\n\n")
print(growth_by_crisis, n = Inf)

cat("\n✓ Saved: 35_asset_growth_by_crisis.png (14\" × 10\", 300 DPI)\n")
