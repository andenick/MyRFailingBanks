# ==============================================================================
# Script 18: Great Depression Asset Composition at Failure
# ==============================================================================
# Purpose: Stacked bar chart showing asset quality classification
#          (good/doubtful/worthless) for Depression-era vs other eras
# Output:  18_great_depression_asset_composition.png (300 DPI)
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
asset_composition <- recv_data %>%
  filter(!is.na(share_good), !is.na(share_doubtful), !is.na(share_worthless), !is.na(era)) %>%
  mutate(
    era_group = case_when(
      era %in% c(3, 4) ~ "Great Depression\n(1929-1935)",
      era %in% c(1, 2) ~ "Pre-Depression\n(1863-1928)",
      era %in% c(5, 6) ~ "Modern Era\n(1984-2023)",
      TRUE ~ "Other"
    )
  ) %>%
  filter(era_group != "Other") %>%
  group_by(era_group) %>%
  summarize(
    n_banks = n(),
    Good = mean(share_good, na.rm = TRUE) * 100,
    Doubtful = mean(share_doubtful, na.rm = TRUE) * 100,
    Worthless = mean(share_worthless, na.rm = TRUE) * 100,
    .groups = "drop"
  ) %>%
  pivot_longer(
    cols = c(Good, Doubtful, Worthless),
    names_to = "Asset_Quality",
    values_to = "Share"
  ) %>%
  mutate(
    Asset_Quality = factor(Asset_Quality, levels = c("Good", "Doubtful", "Worthless"))
  )

# Create visualization
p <- ggplot(asset_composition, aes(x = era_group, y = Share, fill = Asset_Quality)) +
  geom_col(width = 0.7, color = "white", linewidth = 0.5) +
  geom_text(
    aes(label = sprintf("%.1f%%", Share)),
    position = position_stack(vjust = 0.5),
    size = 4,
    fontface = "bold",
    color = "white"
  ) +
  scale_y_continuous(
    name = "Average Asset Composition at Suspension (%)",
    breaks = seq(0, 100, 20),
    limits = c(0, 100)
  ) +
  scale_x_discrete(name = "") +
  scale_fill_manual(
    name = "Asset Classification",
    values = c("Good" = "#2ca02c", "Doubtful" = "#ff7f0e", "Worthless" = "#d62728")
  ) +
  labs(
    title = "Great Depression Banks Had Dramatically Worse Asset Quality",
    subtitle = "Asset classification at failure: Depression-era banks held far more 'worthless' and 'doubtful' assets",
    caption = "Source: OCC receivership records. Asset quality classifications assigned by bank examiners at time of failure."
  ) +
  theme_failing_banks() +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 10),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(size = 11, face = "bold")
  ) +
  guides(fill = guide_legend(nrow = 1))

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "18_great_depression_asset_composition.png"),
  plot = p,
  width = 12,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Print summary
cat("\n=== ASSET COMPOSITION BY ERA ===\n\n")
asset_summary <- recv_data %>%
  filter(!is.na(share_good), !is.na(era)) %>%
  mutate(
    era_group = case_when(
      era %in% c(3, 4) ~ "Great Depression",
      era %in% c(1, 2) ~ "Pre-Depression",
      era %in% c(5, 6) ~ "Modern Era",
      TRUE ~ "Other"
    )
  ) %>%
  filter(era_group != "Other") %>%
  group_by(era_group) %>%
  summarize(
    n = n(),
    avg_good = mean(share_good, na.rm = TRUE) * 100,
    avg_doubtful = mean(share_doubtful, na.rm = TRUE) * 100,
    avg_worthless = mean(share_worthless, na.rm = TRUE) * 100,
    .groups = "drop"
  )
print(asset_summary, n = Inf)

cat("\n✓ Saved: 18_great_depression_asset_composition.png (12\" × 8\", 300 DPI)\n")
