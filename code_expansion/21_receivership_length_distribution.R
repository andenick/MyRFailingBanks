# ==============================================================================
# Script 21: Receivership Length Distribution by Era and Size
# ==============================================================================
# Purpose: Violin plots showing distribution of receivership workout times
#          by era and bank size quintile
# Output:  21_receivership_length_distribution.png (300 DPI)
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
  filter(!is.na(receivership_length), !is.na(assets_at_suspension), !is.na(era)) %>%
  mutate(
    years_in_receivership = receivership_length / 365.25,
    # Create size groups
    size_group = case_when(
      ntile(assets_at_suspension, 3) == 1 ~ "Small Banks",
      ntile(assets_at_suspension, 3) == 2 ~ "Medium Banks",
      ntile(assets_at_suspension, 3) == 3 ~ "Large Banks"
    ),
    size_group = factor(size_group, levels = c("Small Banks", "Medium Banks", "Large Banks")),
    # Create era labels
    era_label = case_when(
      era == 1 ~ "National Banking\n(1863-1913)",
      era == 2 ~ "Early Fed/WWI\n(1914-1928)",
      era == 3 ~ "Depression\nPre-Holiday\n(1929-1933)",
      era == 4 ~ "Depression\nPost-Holiday\n(1933-1935)",
      era == 5 ~ "Modern\nPre-Crisis\n(1984-2006)",
      era == 6 ~ "Financial\nCrisis\n(2007-2023)",
      TRUE ~ "Other"
    ),
    era_label = factor(era_label, levels = c(
      "National Banking\n(1863-1913)",
      "Early Fed/WWI\n(1914-1928)",
      "Depression\nPre-Holiday\n(1929-1933)",
      "Depression\nPost-Holiday\n(1933-1935)",
      "Modern\nPre-Crisis\n(1984-2006)",
      "Financial\nCrisis\n(2007-2023)"
    ))
  ) %>%
  filter(era_label != "Other", years_in_receivership <= 15) # Cap at 15 years for visualization

# Calculate summary statistics
summary_stats <- plot_data %>%
  group_by(era_label, size_group) %>%
  summarize(
    n = n(),
    median_years = median(years_in_receivership, na.rm = TRUE),
    mean_years = mean(years_in_receivership, na.rm = TRUE),
    .groups = "drop"
  )

# Create violin plot
p <- ggplot(plot_data, aes(x = era_label, y = years_in_receivership, fill = size_group)) +
  geom_violin(alpha = 0.6, draw_quantiles = c(0.5), scale = "width", position = position_dodge(width = 0.8)) +
  geom_boxplot(width = 0.15, alpha = 0.8, outlier.size = 0.5, position = position_dodge(width = 0.8)) +
  scale_y_continuous(
    name = "Years in Receivership",
    breaks = seq(0, 15, 2.5),
    limits = c(0, 15)
  ) +
  scale_x_discrete(name = "") +
  scale_fill_manual(
    name = "Bank Size",
    values = c("Small Banks" = "#1f77b4", "Medium Banks" = "#ff7f0e", "Large Banks" = "#2ca02c")
  ) +
  labs(
    title = "Receivership Duration Varies by Era and Bank Size",
    subtitle = "Violin plots show full distribution. Box plots show median and quartiles. Larger banks resolve faster.",
    caption = "Source: OCC receivership records. Violin width proportional to frequency. Analysis limited to receiverships ≤ 15 years."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 10),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(size = 9, angle = 0, hjust = 0.5)
  ) +
  guides(fill = guide_legend(nrow = 1))

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "21_receivership_length_distribution.png"),
  plot = p,
  width = 14,
  height = 9,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== RECEIVERSHIP LENGTH DISTRIBUTION ===\n\n")
print(summary_stats, n = Inf)

cat("\n✓ Saved: 21_receivership_length_distribution.png (14\" × 9\", 300 DPI)\n")
