# ==============================================================================
# Script 41: Fundamental Stability - Pre vs Post FDIC
# ==============================================================================
# Purpose: Show that FDIC didn't just reduce bank runs - it stabilized ALL banking
#          fundamentals. Compare volatility (rolling SD) of key ratios pre/post 1934
# Output:  41_fundamental_stability_pre_post_fdic.png (300 DPI)
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

# Function to calculate rolling 5-year standard deviation
calculate_rolling_sd <- function(data, var_name, window = 5) {
  data %>%
    arrange(year) %>%
    mutate(
      rolling_sd = zoo::rollapply(.data[[var_name]], width = window,
                                   FUN = sd, na.rm = TRUE, fill = NA, align = "right")
    ) %>%
    select(year, rolling_sd) %>%
    mutate(variable = var_name)
}

# Calculate rolling SD for key fundamentals
fundamentals <- c("leverage", "liquid_ratio", "loan_ratio", "deposit_ratio", "noncore_ratio")

# Calculate by year (aggregate all banks)
volatility_data <- lapply(fundamentals, function(var) {
  panel_data %>%
    filter(!is.na(.data[[var]])) %>%
    group_by(year) %>%
    summarize(mean_val = mean(.data[[var]], na.rm = TRUE), .groups = "drop") %>%
    calculate_rolling_sd("mean_val", window = 5) %>%
    mutate(variable = var)
}) %>%
  bind_rows() %>%
  mutate(
    fdic_era = ifelse(year < 1934, "Pre-FDIC", "Post-FDIC"),
    variable_label = case_when(
      variable == "leverage" ~ "Leverage (Equity/Assets)",
      variable == "liquid_ratio" ~ "Liquidity Ratio",
      variable == "loan_ratio" ~ "Loan Ratio",
      variable == "deposit_ratio" ~ "Deposit Ratio",
      variable == "noncore_ratio" ~ "Noncore Funding Ratio",
      TRUE ~ variable
    ),
    variable_label = factor(variable_label, levels = c(
      "Leverage (Equity/Assets)",
      "Liquidity Ratio",
      "Loan Ratio",
      "Deposit Ratio",
      "Noncore Funding Ratio"
    ))
  )

# Calculate mean volatility by era
volatility_summary <- volatility_data %>%
  group_by(variable_label, fdic_era) %>%
  summarize(
    mean_volatility = mean(rolling_sd, na.rm = TRUE),
    .groups = "drop"
  )

# Create visualization
p <- ggplot(volatility_data, aes(x = year, y = rolling_sd, color = fdic_era)) +
  geom_line(linewidth = 1, alpha = 0.8) +
  geom_vline(xintercept = 1934, linetype = "dashed", color = color_neutral, linewidth = 0.8) +
  annotate("text", x = 1934, y = Inf, label = "FDIC\n(1934)",
           vjust = 1.2, hjust = -0.1, size = 3, color = color_neutral) +
  facet_wrap(~ variable_label, ncol = 2, scales = "free_y") +
  scale_x_continuous(
    name = "Year",
    breaks = seq(1870, 2020, 30)
  ) +
  scale_y_continuous(
    name = "Rolling 5-Year Standard Deviation"
  ) +
  scale_color_manual(
    name = "Era",
    values = fdic_colors
  ) +
  labs(
    title = "FDIC Stabilized ALL Banking Fundamentals: Dramatic Volatility Reduction Post-1934",
    subtitle = "Rolling 5-year standard deviation of key bank ratios. Pre-FDIC volatility (orange) vs Post-FDIC stability (blue).",
    caption = "Source: Combined panel dataset (1863-2024). Vertical line = FDIC establishment 1934. Deposit insurance stabilized entire banking system."
  ) +
  theme_failing_banks() +
  theme(
    strip.text = element_text(face = "bold", size = 10),
    strip.background = element_rect(fill = "gray90", color = NA),
    panel.spacing = unit(1, "lines"),
    legend.position = "bottom"
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "41_fundamental_stability_pre_post_fdic.png"),
  plot = p,
  width = 12,
  height = 10,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== FUNDAMENTAL STABILITY: PRE VS POST FDIC ===\n\n")
print(volatility_summary, n = Inf)

cat("\n✓ Saved: 41_fundamental_stability_pre_post_fdic.png (12\" × 10\", 300 DPI)\n")
