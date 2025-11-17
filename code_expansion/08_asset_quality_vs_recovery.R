# ==============================================================================
# Script 08: Asset Quality vs Recovery Outcomes
# ==============================================================================
# Purpose: Scatter plot showing relationship between initial asset quality
#          (share classified as "good") and final collection rates
# Output:  08_asset_quality_vs_recovery.png (300 DPI)
# ==============================================================================

library(tidyverse)
library(here)
library(scales)

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
    full_recov = ifelse(!is.na(dividends) & dividends >= 99.9, 1, 0),
    total_assets_assessed = ifelse(!is.na(assets_suspension_good) & !is.na(assets_suspension_doubtful) & !is.na(assets_suspension_worthless),
                                  assets_suspension_good + assets_suspension_doubtful + assets_suspension_worthless, NA),
    share_good = ifelse(!is.na(total_assets_assessed) & total_assets_assessed > 0,
                       assets_suspension_good / total_assets_assessed, NA),
    share_doubtful = ifelse(!is.na(total_assets_assessed) & total_assets_assessed > 0,
                           assets_suspension_doubtful / total_assets_assessed, NA),
    share_worthless = ifelse(!is.na(total_assets_assessed) & total_assets_assessed > 0,
                            assets_suspension_worthless / total_assets_assessed, NA),
    total_assets_base = ifelse(!is.na(assets_at_suspension),
                              assets_at_suspension + ifelse(is.na(assets_suspension_additional), 0, assets_suspension_additional),
                              NA),
    share_collected = ifelse(!is.na(total_assets_base) & total_assets_base > 0 & !is.na(collected_from_assets),
                            collected_from_assets / total_assets_base, NA),
    total_claims = ifelse(!is.na(amt_claims_proved), amt_claims_proved,
                         ifelse(!is.na(total_liab_established), total_liab_established, NA)),
    solvency_ratio = ifelse(!is.na(total_claims) & total_claims > 0 & !is.na(total_coll_all_sources_incl_off),
                           total_coll_all_sources_incl_off / total_claims, NA)
  )
# Prepare data
plot_data <- recv_data %>%
  filter(!is.na(share_good), !is.na(share_collected), !is.na(era)) %>%
  mutate(
    era_label = case_when(
      era == 1 ~ "National Banking (1863-1913)",
      era == 2 ~ "Early Fed/WWI (1914-1928)",
      era == 3 ~ "Depression Pre-Holiday (1929-1933)",
      era == 4 ~ "Depression Post-Holiday (1933-1935)",
      era == 5 ~ "Modern Pre-Crisis (1984-2006)",
      era == 6 ~ "Financial Crisis (2007-2023)",
      TRUE ~ "Other"
    ),
    era_label = factor(era_label, levels = c(
      "National Banking (1863-1913)",
      "Early Fed/WWI (1914-1928)",
      "Depression Pre-Holiday (1929-1933)",
      "Depression Post-Holiday (1933-1935)",
      "Modern Pre-Crisis (1984-2006)",
      "Financial Crisis (2007-2023)"
    ))
  ) %>%
  filter(era_label != "Other")

# Calculate correlation by era
correlations <- plot_data %>%
  group_by(era_label) %>%
  summarize(
    cor = cor(share_good, share_collected, use = "complete.obs"),
    n = n(),
    .groups = "drop"
  )

# Create visualization
p <- ggplot(plot_data, aes(x = share_good * 100, y = share_collected * 100, color = era_label)) +
  geom_point(alpha = 0.4, size = 2) +
  geom_smooth(method = "lm", se = TRUE, linewidth = 1.2, alpha = 0.15) +
  scale_x_continuous(
    name = "Share of Assets Classified as 'Good' at Suspension (%)",
    breaks = seq(0, 100, 20),
    limits = c(0, 100)
  ) +
  scale_y_continuous(
    name = "Share of Assets Collected from Liquidation (%)",
    breaks = seq(0, 100, 20),
    limits = c(0, 100)
  ) +
  scale_color_brewer(
    name = "Era",
    palette = "Set1"
  ) +
  labs(
    title = "Asset Quality at Failure Predicts Final Recovery Rates",
    subtitle = "Banks with higher-quality assets ('good') achieve better collection rates in receivership",
    caption = "Source: OCC receivership records. Each point represents one failed bank. Lines show linear fit by era."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 10),
    panel.grid.minor = element_blank(),
    panel.border = element_rect(color = "gray80", fill = NA, linewidth = 0.5)
  ) +
  guides(color = guide_legend(nrow = 2, override.aes = list(alpha = 1, size = 3)))

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "08_asset_quality_vs_recovery.png"),
  plot = p,
  width = 12,
  height = 9,
  dpi = 300,
  bg = "white"
)

# Print correlations
cat("\n=== ASSET QUALITY VS RECOVERY CORRELATIONS ===\n\n")
print(correlations, n = Inf)

cat("\n✓ Saved: 08_asset_quality_vs_recovery.png (12\" × 9\", 300 DPI)\n")
