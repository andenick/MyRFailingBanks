# ==============================================================================
# Script 26: Loan Ratio & Liquidity - Failed vs Non-Failed
# ==============================================================================
# Purpose: Show failed banks have lower liquidity, higher loan concentration
# Output:  26_loan_liquidity_failed_vs_nonfailed.png (300 DPI)
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

# Define periods and prepare data
plot_data <- panel_data %>%
  mutate(
    period = case_when(
      year >= 1863 & year <= 1904 ~ "National Banking\n(1863-1904)",
      year >= 1914 & year <= 1928 ~ "Early Fed/WWI\n(1914-1928)",
      year >= 1929 & year <= 1934 ~ "Great Depression\n(1929-1934)",
      year >= 1959 & year <= 2006 ~ "Modern Pre-Crisis\n(1959-2006)",
      year >= 2007 & year <= 2023 ~ "Financial Crisis\n(2007-2023)",
      TRUE ~ "Other"
    ),
    period = factor(period, levels = c(
      "National Banking\n(1863-1904)",
      "Early Fed/WWI\n(1914-1928)",
      "Great Depression\n(1929-1934)",
      "Modern Pre-Crisis\n(1959-2006)",
      "Financial Crisis\n(2007-2023)"
    )),
    bank_status = ifelse(failed_bank == 1, "Failed", "Non-Failed")
  ) %>%
  filter(!is.na(period), period != "Other", !is.na(bank_status))

# Calculate mean loan ratio by period and status
loan_summary <- plot_data %>%
  filter(!is.na(loan_ratio)) %>%
  group_by(period, bank_status) %>%
  summarize(
    mean_loan_ratio = mean(loan_ratio, na.rm = TRUE) * 100,
    se_loan_ratio = sd(loan_ratio, na.rm = TRUE) / sqrt(n()) * 100,
    n_obs = n(),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = mean_loan_ratio - 1.96 * se_loan_ratio,
    ci_upper = mean_loan_ratio + 1.96 * se_loan_ratio,
    metric = "Loan Ratio"
  )

# Calculate mean liquid ratio by period and status
liquid_summary <- plot_data %>%
  filter(!is.na(liquid_ratio)) %>%
  group_by(period, bank_status) %>%
  summarize(
    mean_liquid_ratio = mean(liquid_ratio, na.rm = TRUE) * 100,
    se_liquid_ratio = sd(liquid_ratio, na.rm = TRUE) / sqrt(n()) * 100,
    n_obs = n(),
    .groups = "drop"
  ) %>%
  mutate(
    ci_lower = mean_liquid_ratio - 1.96 * se_liquid_ratio,
    ci_upper = mean_liquid_ratio + 1.96 * se_liquid_ratio,
    metric = "Liquidity Ratio"
  )

# Combine for faceted plot
combined_summary <- bind_rows(
  loan_summary %>% rename(mean_value = mean_loan_ratio),
  liquid_summary %>% rename(mean_value = mean_liquid_ratio)
) %>%
  mutate(
    metric = factor(metric, levels = c("Loan Ratio", "Liquidity Ratio"))
  )

# Create visualization
p <- ggplot(combined_summary, aes(x = period, y = mean_value, fill = bank_status)) +
  geom_col(position = position_dodge(width = 0.8), alpha = 0.8, width = 0.7) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper),
                position = position_dodge(width = 0.8), width = 0.25, linewidth = 0.7) +
  facet_wrap(~ metric, ncol = 1, scales = "free_y") +
  scale_y_continuous(
    name = "Ratio (%)",
    labels = function(x) paste0(x, "%")
  ) +
  scale_x_discrete(name = "") +
  scale_fill_manual(
    name = "Bank Status",
    values = comparison_colors
  ) +
  labs(
    title = "Failed Banks: Lower Liquidity, Higher Loan Concentration",
    subtitle = "Mean loan-to-assets and liquid-assets-to-assets ratios by period. Error bars show 95% CI.",
    caption = "Source: Combined panel dataset (1863-2023). Loan ratio = loans/assets. Liquidity ratio = liquid assets/total assets."
  ) +
  theme_failing_banks() +
  theme(
    axis.text.x = element_text(size = 8, angle = 0, hjust = 0.5),
    strip.text = element_text(face = "bold", size = 11),
    strip.background = element_rect(fill = "gray90", color = NA)
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "26_loan_liquidity_failed_vs_nonfailed.png"),
  plot = p,
  width = 12,
  height = 10,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== LOAN RATIO: FAILED VS NON-FAILED ===\n\n")
print(loan_summary, n = Inf)

cat("\n\n=== LIQUIDITY RATIO: FAILED VS NON-FAILED ===\n\n")
print(liquid_summary, n = Inf)

cat("\n✓ Saved: 26_loan_liquidity_failed_vs_nonfailed.png (12\" × 10\", 300 DPI)\n")
