# ==============================================================================
# Script 10: Time to Full Recovery
# ==============================================================================
# Purpose: Survival-style curve showing time to achieve 100% depositor recovery
# Output:  10_time_to_full_recovery.png (300 DPI)
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
# Prepare data: focus on banks with full recovery
full_recov_data <- recv_data %>%
  filter(full_recov == 1, !is.na(receivership_length), !is.na(era)) %>%
  mutate(
    years_in_receivership = receivership_length / 365.25,
    era_label = case_when(
      era %in% c(1, 2) ~ "Pre-Depression (1863-1928)",
      era %in% c(3, 4) ~ "Great Depression (1929-1935)",
      era %in% c(5, 6) ~ "Modern Era (1984-2023)",
      TRUE ~ "Other"
    )
  ) %>%
  filter(era_label != "Other", years_in_receivership <= 20) # Cap at 20 years for visualization

# Calculate cumulative distribution
cdf_data <- full_recov_data %>%
  group_by(era_label) %>%
  arrange(years_in_receivership) %>%
  mutate(
    cumulative_pct = (row_number() / n()) * 100
  ) %>%
  ungroup()

# Calculate median times
median_times <- full_recov_data %>%
  group_by(era_label) %>%
  summarize(
    median_years = median(years_in_receivership, na.rm = TRUE),
    n_banks = n(),
    .groups = "drop"
  )

# Create visualization
p <- ggplot(cdf_data, aes(x = years_in_receivership, y = cumulative_pct, color = era_label)) +
  geom_step(linewidth = 1.5, alpha = 0.8) +
  geom_vline(data = median_times, aes(xintercept = median_years, color = era_label),
             linetype = "dashed", linewidth = 0.8, alpha = 0.6) +
  scale_x_continuous(
    name = "Years in Receivership",
    breaks = seq(0, 20, 2),
    limits = c(0, 20)
  ) +
  scale_y_continuous(
    name = "Cumulative % of Banks Achieving Full Recovery",
    breaks = seq(0, 100, 20),
    limits = c(0, 100)
  ) +
  scale_color_manual(
    name = "Era",
    values = c("#1f77b4", "#ff7f0e", "#2ca02c")
  ) +
  labs(
    title = "Time Required to Achieve 100% Depositor Recovery",
    subtitle = "Cumulative distribution showing proportion of failed banks reaching full recovery over time. Dashed lines = median.",
    caption = "Source: OCC receivership records. Analysis limited to banks that eventually achieved 100% depositor recovery."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 10),
    panel.grid.minor = element_blank()
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "10_time_to_full_recovery.png"),
  plot = p,
  width = 12,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Print median statistics
cat("\n=== MEDIAN TIME TO FULL RECOVERY ===\n\n")
print(median_times, n = Inf)

cat("\n✓ Saved: 10_time_to_full_recovery.png (12\" × 8\", 300 DPI)\n")
