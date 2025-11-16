# ===========================================================================
# Summary Statistics Tables for the appendix
# Replicates: 22_summary_stats.do
#
# NOTE: This is a full rewrite to FAITHFULLY replicate the Stata logic.
#
# v16: Fixes "argument 'data' is missing" error.
#      The `datasummary()` function was being called with an invalid
#      formula `All() ~ ...`. This version removes the `All()`
#      and uses the correct syntax: `~ N + Mean + ...`
# ===========================================================================

library(haven)
library(dplyr)
library(tidyr)
library(here)
library(modelsummary)

# Source the setup script for directory paths
source(here::here("code", "00_setup.R"))

# --------------------------------------------------------------------------
# 1. Load data and create 3-year growth variable
# --------------------------------------------------------------------------
message("Part 1: Loading data and creating growth variable...")

# Load the CORRECT combined data file from script 07
panel_data <- readRDS(file.path(dataclean_dir, "combined-data.rds"))

# Set panel structure and create 3-year (12-quarter) growth rate
panel_data <- panel_data %>%
  arrange(bank_id, year, quarter) %>%
  group_by(bank_id) %>%
  mutate(
    L12_assets = lag(assets, 12),
    growth = log(assets) - log(L12_assets)
  ) %>%
  ungroup() %>%
  select(-L12_assets)

# --------------------------------------------------------------------------
# 2. Historical Sample Table
# --------------------------------------------------------------------------
message("Part 2: Generating historical sample summary table...")

# Define the 9 statistics as global helper functions
N <- function(x) sum(!is.na(x))
Mean <- function(x) mean(x, na.rm = TRUE)
SD <- function(x) sd(x, na.rm = TRUE)
P1 <- function(x) quantile(x, .01, na.rm = TRUE)
P10 <- function(x) quantile(x, .10, na.rm = TRUE)
P25 <- function(x) quantile(x, .25, na.rm = TRUE)
P75 <- function(x) quantile(x, .75, na.rm = TRUE)
P90 <- function(x) quantile(x, .90, na.rm = TRUE)
P99 <- function(x) quantile(x, .99, na.rm = TRUE)

# Define variable labels
labels_hist <- c(
  failed_bank = "Failing bank",
  leverage = "Equity/assets",
  surplus_ratio = "Surplus profit/equity",
  noncore_ratio = "Noncore funding/assets",
  loan_ratio = "Loans/assets",
  deposit_ratio = "Deposits/assets",
  liquid_ratio = "Liquid assets/assets",
  oreo_ratio = "OREO/loans",
  emergency_borrowing = "(Bills payable and rediscounts)/assets",
  growth = "3-year asset growth (real)"
)

# Prepare the historical data
data_hist <- panel_data %>%
  filter(year <= 1941) %>%
  # *replace variables that are missing...
  mutate(
    profit_shortfall = ifelse(year >= 1905 & year <= 1928, NA, profit_shortfall),
    emergency_borrowing = ifelse(year >= 1905 & year <= 1928, NA, emergency_borrowing),
    oreo_ratio = ifelse(!(year >= 1889 & year <= 1904), NA, oreo_ratio)
  ) %>%
  # Select and reorder variables to match Stata
  select(
    failed_bank, surplus_ratio, noncore_ratio, emergency_borrowing,
    leverage, loan_ratio, deposit_ratio, liquid_ratio, oreo_ratio, growth
  )

# Generate and save the table using datasummary()
datasummary(
  # *** THIS IS THE FIX (Part 1) ***
  # The formula just defines the statistics
  ~ N + Mean + SD + P1 + P10 + P25 + P75 + P90 + P99,

  # The data is passed to the 'data' argument
  data = data_hist,

  fmt = "%.2f",
  rename = labels_hist,
  output = file.path(tables_dir, "03_tab_sumstats_prewar.tex"),
  title = "Historical Sample Summary Statistics",
  notes = "Statistics computed for the 1863-1941 period."
)
message("Saved: 03_tab_sumstats_prewar.tex")


# --------------------------------------------------------------------------
# 3. Modern Sample Table
# --------------------------------------------------------------------------
message("Part 3: Generating modern sample summary table...")

# Define variable labels
labels_mod <- c(
  failed_bank = "Failing bank",
  noncore_ratio = "Noncore funding/assets",
  leverage = "Equity/assets",
  loan_ratio = "Loans/assets",
  deposit_ratio = "Deposits/assets",
  liquid_ratio = "Liquid assets/assets",
  income_ratio = "Net income/assets",
  npl_ratio = "NPL/loans",
  deposits_time_ratio = "Time deposits/assets",
  otherbor_liab_ratio = "Other borrowed money/assets",
  brokered_dep_ratio = "Brokered deposits/assets",
  prov_ratio = "LLP/loans",
  nim = "NIM",
  growth = "3-year asset growth (real)"
)

# Prepare the modern data
data_mod <- panel_data %>%
  filter(year >= 1959) %>%
  # Select and reorder variables to match Stata
  select(
    failed_bank, income_ratio, noncore_ratio, otherbor_liab_ratio, deposit_ratio,
    deposits_time_ratio, leverage, loan_ratio, liquid_ratio,
    brokered_dep_ratio, npl_ratio, prov_ratio, nim, growth
  )

# Generate and save the table using datasummary()
datasummary(
  # *** THIS IS THE FIX (Part 2) ***
  # The formula just defines the statistics
  ~ N + Mean + SD + P1 + P10 + P25 + P75 + P90 + P99,

  # The data is passed to the 'data' argument
  data = data_mod,

  fmt = "%.2f",
  rename = labels_mod,
  output = file.path(tables_dir, "03_tab_sumstats_postwar.tex"),
  title = "Modern Sample Summary Statistics",
  notes = "Statistics computed for the 1959-2024 period."
)
message("Saved: 03_tab_sumstats_postwar.tex")

message("Script 22 (summary stats) completed successfully.")
