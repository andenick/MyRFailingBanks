# ==============================================================================
# Script 11: Solvency Ratio vs Depositor Recovery
# ==============================================================================
# Purpose: Scatter plot showing relationship between asset-liability ratios
#          (solvency) and depositor dividend outcomes
# Output:  11_solvency_vs_depositor_recovery.png (300 DPI)
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
  filter(!is.na(solvency_ratio), !is.na(dividends)) %>%
  filter(solvency_ratio > 0, solvency_ratio <= 2) %>% # Focus on reasonable range
  mutate(
    full_recovery = ifelse(full_recov == 1, "Full Recovery (100%)", "Partial Recovery (<100%)"),
    era_group = case_when(
      era %in% c(1, 2) ~ "Pre-Depression",
      era %in% c(3, 4) ~ "Great Depression",
      era %in% c(5, 6) ~ "Modern Era",
      TRUE ~ "Other"
    )
  ) %>%
  filter(era_group != "Other")

# Calculate statistics
cor_overall <- cor(plot_data$solvency_ratio, plot_data$dividends, use = "complete.obs")

# Create visualization
p <- ggplot(plot_data, aes(x = solvency_ratio, y = dividends)) +
  geom_point(aes(color = era_group, shape = full_recovery), alpha = 0.5, size = 2.5) +
  geom_smooth(method = "loess", se = TRUE, color = "black", linewidth = 1.2, alpha = 0.2) +
  geom_vline(xintercept = 1, linetype = "dashed", color = "red", linewidth = 0.8, alpha = 0.6) +
  annotate("text", x = 1.05, y = 10, label = "Solvency Threshold\n(Assets = Liabilities)",
           hjust = 0, size = 3.5, color = "red") +
  scale_x_continuous(
    name = "Solvency Ratio (Total Collections / Total Claims)",
    breaks = seq(0, 2, 0.25),
    limits = c(0, 2)
  ) +
  scale_y_continuous(
    name = "Depositor Recovery Rate (%)",
    breaks = seq(0, 100, 20),
    limits = c(0, 100)
  ) +
  scale_color_manual(
    name = "Era",
    values = c("#1f77b4", "#ff7f0e", "#2ca02c")
  ) +
  scale_shape_manual(
    name = "Outcome",
    values = c(16, 1)
  ) +
  labs(
    title = "Bank Solvency Predicts Depositor Recovery Outcomes",
    subtitle = sprintf("Correlation = %.3f. Banks with solvency ratio > 1.0 typically achieve full depositor recovery.", cor_overall),
    caption = "Source: OCC receivership records. Solvency ratio = total collections from all sources / total claims."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0),
    legend.position = "bottom",
    legend.box = "vertical",
    legend.title = element_text(face = "bold", size = 10),
    panel.grid.minor = element_blank(),
    panel.border = element_rect(color = "gray80", fill = NA, linewidth = 0.5)
  ) +
  guides(
    color = guide_legend(order = 1, nrow = 1),
    shape = guide_legend(order = 2, nrow = 1)
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "11_solvency_vs_depositor_recovery.png"),
  plot = p,
  width = 12,
  height = 9,
  dpi = 300,
  bg = "white"
)

cat("\n=== SOLVENCY VS DEPOSITOR RECOVERY ===\n")
cat(sprintf("Overall correlation: %.3f\n", cor_overall))
cat(sprintf("Banks in sample: %d\n", nrow(plot_data)))

cat("\n✓ Saved: 11_solvency_vs_depositor_recovery.png (12\" × 9\", 300 DPI)\n")
