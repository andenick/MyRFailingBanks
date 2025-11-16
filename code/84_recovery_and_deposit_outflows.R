# ==============================================================================
# Recovery and Deposit Outflows
# ==============================================================================
# Translation from: 84_recovery_and_deposit_outflows.py
# ==============================================================================

library(tidyverse)
library(haven)
library(ggplot2)

source(here::here("code", "00_setup.R"))

cat("================================================================================\n")
cat("RECOVERY AND DEPOSIT OUTFLOWS\n")
cat("================================================================================\n")

# Load data
df <- readRDS(here::here("tempfiles", "receivership_dataset_tmp.rds"))

# Create assets column if missing
if (!("assets" %in% names(df))) {
  if ("assets.x" %in% names(df)) df$assets <- df$assets.x
  else if ("assets_at_suspension" %in% names(df)) df$assets <- df$assets_at_suspension
}

# Calculate recovery rates if columns exist
if ("dividends" %in% names(df) && "deposits_at_suspension" %in% names(df)) {
  df <- df %>% mutate(
    recovery_rate = ifelse(!is.na(dividends) & !is.na(deposits_at_suspension) & deposits_at_suspension > 0,
                           (dividends / deposits_at_suspension) * 100, NA)
  )
}

if ("collected_from_assets" %in% names(df) && "assets_at_suspension" %in% names(df)) {
  df <- df %>% mutate(
    asset_recovery_rate = ifelse(!is.na(collected_from_assets) & !is.na(assets_at_suspension) & assets_at_suspension > 0,
                                  (collected_from_assets / assets_at_suspension) * 100, NA)
  )
}

cat(sprintf("Loaded %s observations\n", format(nrow(df), big.mark = ",")))

# Calculate deposit_outflow from available columns
if ("deposits_call" %in% names(df) && "deposits_at_suspension" %in% names(df)) {
  df <- df %>% mutate(
    deposit_outflow = ifelse(!is.na(deposits_call) & !is.na(deposits_at_suspension) & deposits_call > 0,
                             (deposits_call - deposits_at_suspension) / deposits_call, NA)
  )
  cat(sprintf("Created deposit_outflow: %d non-NA values\n", sum(!is.na(df$deposit_outflow))))
} else if ("deposits_growth" %in% names(df)) {
  df$deposit_outflow <- -df$deposits_growth
  cat(sprintf("Using deposits_growth as deposit_outflow: %d non-NA values\n", sum(!is.na(df$deposit_outflow))))
} else {
  cat("WARNING: No deposit outflow data available. Skipping analysis.\n")
  cat("\n================================================================================\n")
  cat("RECOVERY AND DEPOSIT OUTFLOWS - SKIPPED\n")
  cat("================================================================================\n")
  quit(save = "no", status = 0)
}

# Analysis of recovery rates and deposit outflows
df_analysis <- df %>%
  filter(!is.na(recovery_rate) & !is.na(deposit_outflow)) %>%
  mutate(
    has_run = ifelse(deposit_outflow > 0.1, 1, 0)
  )

cat(sprintf("Analysis dataset: %d observations with both recovery_rate and deposit_outflow\n", nrow(df_analysis)))

if (nrow(df_analysis) > 0) {
  # Summary by run status
  summary_by_run <- df_analysis %>%
    group_by(has_run) %>%
    summarise(
      n = n(),
      mean_recovery = mean(recovery_rate, na.rm = TRUE),
      sd_recovery = sd(recovery_rate, na.rm = TRUE),
      .groups = "drop"
    )

  cat("\n--- Recovery Rates by Bank Run Status ---\n")
  print(summary_by_run)

  # Create visualization
  p <- ggplot(df_analysis, aes(x = factor(has_run), y = recovery_rate)) +
    geom_boxplot(fill = "lightblue", alpha = 0.7) +
    theme_minimal() +
    labs(
      title = "Recovery Rates: Bank Runs vs No Runs",
      x = "Bank Run (0=No, 1=Yes)",
      y = "Recovery Rate (%)"
    )

  ggsave(
    here::here("output", "figures", "99_recovery_by_run_status.pdf"),
    plot = p,
    width = 10,
    height = 8
  )
  cat("\n✓ Figure saved: 99_recovery_by_run_status.pdf\n")
} else {
  cat("\nWARNING: No observations with both recovery_rate and deposit_outflow\n")
}

cat("\n================================================================================\n")
cat("RECOVERY AND DEPOSIT OUTFLOWS - COMPLETE\n")
cat("================================================================================\n")
