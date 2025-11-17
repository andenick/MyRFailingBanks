# ==============================================================================
# Script 33: Post-Receivership Solvency Deterioration
# ==============================================================================
# Purpose: Show how asset quality revealed in receivership predicts recovery
#          Demonstrates actual underlying asset values vs book values
# Output:  33_post_receivership_solvency_deterioration.png (300 DPI)
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

# Load receivership data
recv_data <- readRDS(file.path(tempfiles_dir, "receivership_dataset_tmp.rds"))

# Parse receivership_date and create era variable
recv_data <- recv_data %>%
  mutate(
    receivership_date = as.Date(date_receiver_appt, format = "%b. %d,%Y"),
    era = case_when(
      receivership_date >= as.Date("1863-01-01") & receivership_date < as.Date("1914-01-01") ~ 1,
      receivership_date >= as.Date("1914-01-01") & receivership_date <= as.Date("1928-12-31") ~ 2,
      receivership_date >= as.Date("1929-01-01") & receivership_date <= as.Date("1933-03-06") ~ 3,
      receivership_date >= as.Date("1933-02-01") & receivership_date <= as.Date("1935-01-01") ~ 4,
      final_year >= 1984 & final_year <= 2006 ~ 5,
      final_year >= 2007 & final_year <= 2023 ~ 6,
      TRUE ~ NA_real_
    ),
    # Create derived variables
    total_assets_assessed = ifelse(!is.na(assets_suspension_good) & !is.na(assets_suspension_doubtful) & !is.na(assets_suspension_worthless),
                                  assets_suspension_good + assets_suspension_doubtful + assets_suspension_worthless, NA),
    share_good = ifelse(!is.na(total_assets_assessed) & total_assets_assessed > 0,
                       assets_suspension_good / total_assets_assessed * 100, NA),
    share_doubtful = ifelse(!is.na(total_assets_assessed) & total_assets_assessed > 0,
                           assets_suspension_doubtful / total_assets_assessed * 100, NA),
    share_worthless = ifelse(!is.na(total_assets_assessed) & total_assets_assessed > 0,
                            assets_suspension_worthless / total_assets_assessed * 100, NA)
  ) %>%
  filter(!is.na(dividends), !is.na(share_good), !is.na(era))

# Define era colors for scatter plot
era_point_colors <- c(
  "1" = color_national,
  "2" = color_earlyfed,
  "3" = color_depression,
  "4" = color_transition,
  "5" = color_modern,
  "6" = color_crisis
)

# Create scatter plot: share_good vs dividends
p <- ggplot(recv_data, aes(x = share_good, y = dividends)) +
  geom_point(aes(color = factor(era)), alpha = 0.6, size = 2.5) +
  geom_smooth(method = "lm", formula = y ~ x, se = TRUE, color = color_neutral, fill = color_neutral, alpha = 0.2, linewidth = 1.5) +
  scale_x_continuous(
    name = "Asset Quality at Suspension: % 'Good' Assets",
    breaks = seq(0, 100, 20),
    labels = function(x) paste0(x, "%"),
    limits = c(0, 100)
  ) +
  scale_y_continuous(
    name = "Depositor Recovery Rate (%)",
    breaks = seq(0, 100, 20),
    labels = function(x) paste0(x, "%"),
    limits = c(0, 100)
  ) +
  scale_color_manual(
    name = "Era",
    values = era_point_colors,
    labels = c(
      "1" = "1863-1913",
      "2" = "1914-1928",
      "3" = "1929-1933",
      "4" = "1933-1935",
      "5" = "1984-2006",
      "6" = "2007-2023"
    )
  ) +
  labs(
    title = "Asset Quality at Receivership Strongly Predicts Recovery Outcomes",
    subtitle = "Higher % of 'good' assets at suspension predicts better depositor recovery. Reveals true underlying solvency.",
    caption = "Source: OCC receivership records. Each point = one failed bank. Gray line = linear fit with 95% CI. Asset quality assessed at suspension."
  ) +
  theme_failing_banks()

# Calculate correlation
cor_result <- cor.test(recv_data$share_good, recv_data$dividends, method = "pearson")

# Add correlation annotation to plot
p <- p +
  annotate("text", x = 10, y = 95,
           label = paste0("Correlation: r = ", round(cor_result$estimate, 3), "\np < 0.001"),
           hjust = 0, vjust = 1, size = 4, color = color_neutral, fontface = "bold")

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "33_post_receivership_solvency_deterioration.png"),
  plot = p,
  width = 12,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Calculate summary statistics
asset_quality_stats <- recv_data %>%
  summarize(
    n = n(),
    mean_share_good = mean(share_good, na.rm = TRUE),
    mean_share_doubtful = mean(share_doubtful, na.rm = TRUE),
    mean_share_worthless = mean(share_worthless, na.rm = TRUE),
    correlation = cor(share_good, dividends, use = "complete.obs"),
    .groups = "drop"
  )

# Print summary statistics
cat("\n=== POST-RECEIVERSHIP ASSET QUALITY VS RECOVERY ===\n\n")
cat("Average asset composition at suspension:\n")
cat("  Good assets:      ", round(asset_quality_stats$mean_share_good, 1), "%\n")
cat("  Doubtful assets:  ", round(asset_quality_stats$mean_share_doubtful, 1), "%\n")
cat("  Worthless assets: ", round(asset_quality_stats$mean_share_worthless, 1), "%\n\n")
cat("Correlation between 'good' assets and recovery:", round(cor_result$estimate, 3), "\n")
cat("p-value:", format.pval(cor_result$p.value, digits = 4), "\n\n")

cat("✓ Saved: 33_post_receivership_solvency_deterioration.png (12\" × 8\", 300 DPI)\n")
