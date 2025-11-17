# ==============================================================================
# Script 31: Recovery Rates - Failed vs Non-Failed Comparison
# ==============================================================================
# Purpose: Show that failed banks recover less than non-failed banks maintain
# Output:  31_recovery_failed_vs_nonfailed.png (300 DPI)
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
    era_label = case_when(
      era %in% c(1, 2) ~ "Pre-Depression\n(1863-1928)",
      era %in% c(3, 4) ~ "Great Depression\n(1929-1935)",
      era %in% c(5, 6) ~ "Modern Era\n(1984-2023)",
      TRUE ~ "Other"
    ),
    era_label = factor(era_label, levels = c(
      "Pre-Depression\n(1863-1928)",
      "Great Depression\n(1929-1935)",
      "Modern Era\n(1984-2023)"
    ))
  ) %>%
  filter(!is.na(dividends), !is.na(era_label), era_label != "Other")

# Calculate recovery statistics
recovery_stats <- recv_data %>%
  group_by(era_label) %>%
  summarize(
    mean_recovery = mean(dividends, na.rm = TRUE),
    se_recovery = sd(dividends, na.rm = TRUE) / sqrt(n()),
    median_recovery = median(dividends, na.rm = TRUE),
    pct_full_recovery = sum(dividends >= 99.9, na.rm = TRUE) / n() * 100,
    n_banks = n(),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = mean_recovery - 1.96 * se_recovery,
    ci_upper = mean_recovery + 1.96 * se_recovery,
    bank_type = "Failed Banks\n(Depositor Recovery)"
  )

# Create comparison dataset for non-failed banks (assumed 100% value retention)
nonfailed_comparison <- recovery_stats %>%
  select(era_label) %>%
  mutate(
    mean_recovery = 100,
    se_recovery = 0,
    median_recovery = 100,
    ci_lower = 100,
    ci_upper = 100,
    bank_type = "Non-Failed Banks\n(Value Retained)"
  )

# Combine datasets
combined_data <- bind_rows(recovery_stats, nonfailed_comparison) %>%
  mutate(
    bank_type = factor(bank_type, levels = c(
      "Non-Failed Banks\n(Value Retained)",
      "Failed Banks\n(Depositor Recovery)"
    ))
  )

# Create visualization
p <- ggplot(combined_data, aes(x = era_label, y = mean_recovery, fill = bank_type)) +
  geom_col(position = position_dodge(width = 0.8), alpha = 0.8, width = 0.7) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper),
                position = position_dodge(width = 0.8), width = 0.25, linewidth = 0.7) +
  geom_hline(yintercept = 100, linetype = "dashed", color = color_neutral, linewidth = 0.8) +
  scale_y_continuous(
    name = "Recovery / Value Retention (%)",
    breaks = seq(0, 100, 20),
    labels = function(x) paste0(x, "%"),
    limits = c(0, 105)
  ) +
  scale_x_discrete(name = "") +
  scale_fill_manual(
    name = "",
    values = c(
      "Non-Failed Banks\n(Value Retained)" = color_success,
      "Failed Banks\n(Depositor Recovery)" = color_failure
    )
  ) +
  labs(
    title = "Failed Banks Recover Less Than Non-Failed Banks Retain",
    subtitle = "Depositor recovery rates for failed banks vs 100% value retention for non-failed banks. Error bars = 95% CI.",
    caption = "Source: OCC receivership records. Failed banks show significant value destruction. Dashed line = full value retention (100%)."
  ) +
  theme_failing_banks() +
  theme(
    axis.text.x = element_text(size = 10, angle = 0, hjust = 0.5)
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "31_recovery_failed_vs_nonfailed.png"),
  plot = p,
  width = 12,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== RECOVERY RATES: FAILED VS NON-FAILED ===\n\n")
print(recovery_stats %>% select(era_label, mean_recovery, median_recovery, pct_full_recovery, n_banks), n = Inf)

cat("\n✓ Saved: 31_recovery_failed_vs_nonfailed.png (12\" × 8\", 300 DPI)\n")
