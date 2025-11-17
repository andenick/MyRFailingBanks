# ==============================================================================
# Script 32: Recovery Rates Pre-FDIC vs Post-FDIC
# ==============================================================================
# Purpose: Compare depositor recovery distributions before and after FDIC (1934)
# Output:  32_recovery_pre_post_fdic.png (300 DPI)
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

# Parse receivership_date and create FDIC era variable
recv_data <- recv_data %>%
  mutate(
    receivership_date = as.Date(date_receiver_appt, format = "%b. %d,%Y"),
    fdic_era = case_when(
      receivership_date < as.Date("1934-01-01") ~ "Pre-FDIC (1863-1933)",
      receivership_date >= as.Date("1934-01-01") ~ "Post-FDIC (1934-2023)",
      final_year < 1934 ~ "Pre-FDIC (1863-1933)",
      final_year >= 1934 ~ "Post-FDIC (1934-2023)",
      TRUE ~ "Unknown"
    ),
    fdic_era = factor(fdic_era, levels = c("Pre-FDIC (1863-1933)", "Post-FDIC (1934-2023)"))
  ) %>%
  filter(!is.na(dividends), !is.na(fdic_era), fdic_era != "Unknown")

# Calculate summary statistics
recovery_stats <- recv_data %>%
  group_by(fdic_era) %>%
  summarize(
    n = n(),
    mean_recovery = mean(dividends, na.rm = TRUE),
    median_recovery = median(dividends, na.rm = TRUE),
    sd_recovery = sd(dividends, na.rm = TRUE),
    pct_full_recovery = sum(dividends >= 99.9, na.rm = TRUE) / n() * 100,
    pct_zero_recovery = sum(dividends < 1, na.rm = TRUE) / n() * 100,
    .groups = "drop"
  )

# Create density plot with box plots
p_density <- ggplot(recv_data, aes(x = dividends, fill = fdic_era)) +
  geom_density(alpha = 0.5, linewidth = 1) +
  scale_x_continuous(
    name = "Depositor Recovery Rate (%)",
    breaks = seq(0, 100, 25),
    limits = c(0, 100)
  ) +
  scale_y_continuous(name = "Density") +
  scale_fill_manual(
    name = "Era",
    values = fdic_colors
  ) +
  labs(
    title = "Modern FDIC Era Shows Better Recovery Outcomes",
    subtitle = "Distribution of depositor recovery rates: density plots show full distribution",
    caption = "Source: OCC receivership records (1863-2023). FDIC deposit insurance established 1934."
  ) +
  theme_failing_banks()

# Create combined density + box plot
p_combined <- ggplot(recv_data, aes(x = fdic_era, y = dividends, fill = fdic_era)) +
  geom_violin(alpha = 0.6, draw_quantiles = c(0.25, 0.5, 0.75), scale = "width") +
  geom_boxplot(width = 0.15, alpha = 0.8, outlier.size = 1) +
  stat_summary(fun = mean, geom = "point", shape = 23, size = 3, fill = "white", color = "black") +
  scale_y_continuous(
    name = "Depositor Recovery Rate (%)",
    breaks = seq(0, 100, 25),
    limits = c(0, 100)
  ) +
  scale_x_discrete(name = "") +
  scale_fill_manual(
    name = "Era",
    values = fdic_colors,
    guide = "none"
  ) +
  labs(
    title = "Modern FDIC Era Shows Better Recovery Outcomes",
    subtitle = "Violin plots show distribution. Box plots show quartiles. Diamond = mean. Post-FDIC recoveries are higher.",
    caption = "Source: OCC receivership records (1863-2023). FDIC deposit insurance established 1934."
  ) +
  theme_failing_banks()

# Save high-resolution outputs
ggsave(
  filename = file.path(output_dir, "32_recovery_pre_post_fdic.png"),
  plot = p_combined,
  width = 12,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== RECOVERY RATES: PRE VS POST FDIC ===\n\n")
print(recovery_stats, n = Inf)

# Statistical test
cat("\n=== STATISTICAL TEST ===\n")
pre_fdic <- recv_data %>% filter(fdic_era == "Pre-FDIC (1863-1933)") %>% pull(dividends)
post_fdic <- recv_data %>% filter(fdic_era == "Post-FDIC (1934-2023)") %>% pull(dividends)

if (length(pre_fdic) > 0 && length(post_fdic) > 0) {
  test_result <- t.test(post_fdic, pre_fdic)
  cat("Two-sample t-test: Post-FDIC vs Pre-FDIC\n")
  cat("Mean difference:", round(test_result$estimate[1] - test_result$estimate[2], 2), "%\n")
  cat("p-value:", format.pval(test_result$p.value, digits = 4), "\n")
}

cat("\n✓ Saved: 32_recovery_pre_post_fdic.png (12\" × 8\", 300 DPI)\n")
