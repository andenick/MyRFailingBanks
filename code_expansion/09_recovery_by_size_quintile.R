# ==============================================================================
# Script 09: Recovery Rates by Bank Size Quintile
# ==============================================================================
# Purpose: Bar chart with error bars showing recovery rates by asset size
#          quintile, overall and by era
# Output:  09_recovery_by_size_quintile.png (300 DPI)
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
# Create size quintiles and era labels
plot_data <- recv_data %>%
  filter(!is.na(dividends), !is.na(assets_at_suspension), !is.na(era)) %>%
  mutate(
    size_quintile = ntile(assets_at_suspension, 5),
    size_label = paste0("Q", size_quintile, "\n",
                       case_when(
                         size_quintile == 1 ~ "Smallest",
                         size_quintile == 5 ~ "Largest",
                         TRUE ~ ""
                       )),
    era_label = case_when(
      era %in% c(1, 2) ~ "Pre-Depression\n(1863-1928)",
      era %in% c(3, 4) ~ "Great Depression\n(1929-1935)",
      era %in% c(5, 6) ~ "Modern Era\n(1984-2023)",
      TRUE ~ "Other"
    )
  ) %>%
  filter(era_label != "Other")

# Calculate summary statistics
summary_stats <- plot_data %>%
  group_by(era_label, size_label, size_quintile) %>%
  summarize(
    n = n(),
    mean_recovery = mean(dividends, na.rm = TRUE),
    se_recovery = sd(dividends, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  ) %>%
  arrange(era_label, size_quintile)

# Create visualization
p <- ggplot(summary_stats, aes(x = size_label, y = mean_recovery, fill = era_label)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_errorbar(
    aes(ymin = mean_recovery - 1.96 * se_recovery,
        ymax = mean_recovery + 1.96 * se_recovery),
    position = position_dodge(width = 0.8),
    width = 0.3,
    linewidth = 0.6
  ) +
  scale_y_continuous(
    name = "Average Depositor Recovery Rate (%)",
    breaks = seq(0, 100, 20),
    limits = c(0, 100)
  ) +
  scale_x_discrete(name = "Bank Size Quintile") +
  scale_fill_manual(
    name = "Era",
    values = c("#1f77b4", "#ff7f0e", "#2ca02c")
  ) +
  labs(
    title = "Larger Banks Achieve Higher Recovery Rates in Receivership",
    subtitle = "Average depositor recovery (%) by bank size quintile. Error bars show 95% confidence intervals.",
    caption = "Source: OCC receivership records. Banks grouped into quintiles based on assets at suspension."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 10),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(size = 9)
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "09_recovery_by_size_quintile.png"),
  plot = p,
  width = 12,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== RECOVERY RATES BY SIZE QUINTILE ===\n\n")
print(summary_stats, n = Inf)

cat("\n✓ Saved: 09_recovery_by_size_quintile.png (12\" × 8\", 300 DPI)\n")
