# ==============================================================================
# Depositor Recovery Rates Dynamics
# ==============================================================================
# Translation from: 87_depositor_recovery_rates_dynamics.py
# ==============================================================================

library(tidyverse)
library(haven)
library(ggplot2)

source(here::here("code", "00_setup.R"))

cat("================================================================================\n")
cat("DEPOSITOR RECOVERY RATES DYNAMICS\n")
cat("================================================================================\n")

# Load data
# Extract year from receivership_date
df <- readRDS(here::here("tempfiles", "receivership_dataset_tmp.rds"))
df <- df %>% mutate(year = year(receivership_date))
# Calculate recovery rates if columns exist
# Create assets column if missing
if (!("assets" %in% names(df))) {
  if ("assets.x" %in% names(df)) df$assets <- df$assets.x
  else if ("assets_at_suspension" %in% names(df)) df$assets <- df$assets_at_suspension
}
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
df <- df %>% mutate(year = year(receivership_date))
cat(sprintf("Loaded %s observations\n", format(nrow(df), big.mark = ",")))

# Time series of recovery dynamics
df_ts <- df %>%
  group_by(year) %>%
  summarise(
    mean_recovery = mean(recovery_rate, na.rm = TRUE),
    median_recovery = median(recovery_rate, na.rm = TRUE),
    p25_recovery = quantile(recovery_rate, 0.25, na.rm = TRUE),
    p75_recovery = quantile(recovery_rate, 0.75, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  )

# Create figure with confidence bands
p <- ggplot(df_ts, aes(x = year)) +
  geom_ribbon(aes(ymin = p25_recovery, ymax = p75_recovery), alpha = 0.3, fill = "blue") +
  geom_line(aes(y = median_recovery), color = "darkblue", size = 1) +
  geom_point(aes(y = mean_recovery, size = n), color = "red", alpha = 0.6) +
  theme_minimal() +
  labs(
    title = "Depositor Recovery Rates Over Time",
    subtitle = "Blue band: 25th-75th percentile; Line: Median; Points: Mean (sized by N)",
    x = "Year",
    y = "Recovery Rate (%)",
    size = "N Failures"
  )

ggsave(
  here::here("output", "figures", "99_recovery_dynamics.pdf"),
  plot = p,
  width = 14,
  height = 8
)

cat("   Saved: 99_recovery_dynamics.pdf\n")

cat("\n================================================================================\n")
cat("DEPOSITOR RECOVERY RATES DYNAMICS - COMPLETE\n")
cat("================================================================================\n")

