# ===========================================================================
# Combine datasets (both OCC and FFIE Call Report) + prepare data for analysis
# Replicates: 07_combine_and_prep.do
#
# This script combines the historical and modern datasets created in scripts
# 04-06 into a single panel dataset for analysis.
# ===========================================================================

library(haven)
library(dplyr)
library(tidyr)
library(here)

# Source the setup script for directory paths
source(here::here("code", "00_setup.R"))

cat("===========================================================================\n")
cat("SCRIPT 07: COMBINING HISTORICAL AND MODERN DATASETS\n")
cat("===========================================================================\n\n")

# --------------------------------------------------------------------------
# 1. Load historical dataset
# --------------------------------------------------------------------------
cat("Part 1: Loading historical dataset...\n")

historical_file <- file.path(tempfiles_dir, "call-reports-historical-edited.dta")
if (!file.exists(historical_file)) {
  # Try alternative location
  historical_file <- file.path(tempfiles_dir, "call-reports-historical.dta")
}

if (!file.exists(historical_file)) {
  stop("Historical dataset not found. Please run scripts 04-06 first.")
}

historical_data <- haven::read_dta(historical_file)
cat(sprintf("  Loaded historical data: %d observations\n", nrow(historical_data)))

# --------------------------------------------------------------------------
# 2. Load modern dataset
# --------------------------------------------------------------------------
cat("\nPart 2: Loading modern dataset...\n")

modern_file <- file.path(tempfiles_dir, "call-reports-modern.dta")
if (!file.exists(modern_file)) {
  stop("Modern dataset not found. Please run scripts 04-06 first.")
}

modern_data <- haven::read_dta(modern_file)
cat(sprintf("  Loaded modern data: %d observations\n", nrow(modern_data)))

# --------------------------------------------------------------------------
# 3. Ensure compatible column types and get all columns
# --------------------------------------------------------------------------
cat("\nPart 3: Harmonizing column types...\n")

# Convert haven_labelled to numeric if needed
historical_data <- historical_data %>%
  mutate(across(where(haven::is.labelled), as.numeric))

modern_data <- modern_data %>%
  mutate(across(where(haven::is.labelled), as.numeric))

# Get all unique column names from both datasets
all_cols <- unique(c(names(historical_data), names(modern_data)))
common_cols <- intersect(names(historical_data), names(modern_data))
historical_only <- setdiff(names(historical_data), names(modern_data))
modern_only <- setdiff(names(modern_data), names(historical_data))

cat(sprintf("  Total unique columns: %d\n", length(all_cols)))
cat(sprintf("  Common columns: %d\n", length(common_cols)))
cat(sprintf("  Historical-only columns: %d\n", length(historical_only)))
cat(sprintf("  Modern-only columns: %d\n", length(modern_only)))

# --------------------------------------------------------------------------
# 4. Combine datasets with all columns
# --------------------------------------------------------------------------
cat("\nPart 4: Combining datasets...\n")

# Add missing columns to each dataset (filled with NA)
# This ensures bind_rows works correctly with different column sets
# Preserve column types when adding missing columns
for (col in historical_only) {
  if (!col %in% names(modern_data)) {
    # Get the type from historical data
    col_type <- class(historical_data[[col]])[1]
    if (col_type %in% c("numeric", "integer")) {
      modern_data[[col]] <- NA_real_
    } else if (col_type == "character") {
      modern_data[[col]] <- NA_character_
    } else if (col_type == "logical") {
      modern_data[[col]] <- NA
    } else {
      modern_data[[col]] <- NA
    }
  }
}

for (col in modern_only) {
  if (!col %in% names(historical_data)) {
    # Get the type from modern data
    col_type <- class(modern_data[[col]])[1]
    if (col_type %in% c("numeric", "integer")) {
      historical_data[[col]] <- NA_real_
    } else if (col_type == "character") {
      historical_data[[col]] <- NA_character_
    } else if (col_type == "logical") {
      historical_data[[col]] <- NA
    } else {
      historical_data[[col]] <- NA
    }
  }
}

# Ensure both datasets have columns in the same order
all_cols_ordered <- all_cols[order(all_cols)]
historical_data <- historical_data %>% select(any_of(all_cols_ordered))
modern_data <- modern_data %>% select(any_of(all_cols_ordered))

# Combine using bind_rows (now both have same columns)
combined_data <- bind_rows(
  historical_data,
  modern_data
)

cat(sprintf("  Combined dataset: %d observations\n", nrow(combined_data)))
cat(sprintf("  Historical: %d observations\n", nrow(historical_data)))
cat(sprintf("  Modern: %d observations\n", nrow(modern_data)))

# --------------------------------------------------------------------------
# 4.5. Merge macro datasets (Replicates Stata lines 16-18)
# --------------------------------------------------------------------------
cat("\nPart 4.5: Merging macro datasets...\n")

# Load JST dataset (GDP, crisis indicators, loan aggregates)
jst_file <- file.path(sources_dir, "JST", "jst_cpi_crisis.dta")
if (file.exists(jst_file)) {
  jst_data <- haven::read_dta(jst_file) %>%
    mutate(across(where(haven::is.labelled), as.numeric)) %>%
    select(year, cpi, crisisJST, stir, ltrate, gdp, unemp,
           gdp_growth_3years, tloans_growth_3years, tloans_gdp)

  combined_data <- combined_data %>%
    left_join(jst_data, by = "year")

  cat(sprintf("  ✓ Merged JST dataset (%d rows)\n", nrow(jst_data)))
} else {
  cat("  ⚠ JST dataset not found, skipping\n")
}

# Load GFD CPI dataset
cpi_file <- file.path(sources_dir, "GFD", "US_CPI_GFD_annual.dta")
if (file.exists(cpi_file)) {
  cpi_data <- haven::read_dta(cpi_file) %>%
    mutate(across(where(haven::is.labelled), as.numeric)) %>%
    select(year, cpi_gfd, inf_cpi_1years, inf_cpi_2years,
           inf_cpi_3years, inf_cpi_5years)

  combined_data <- combined_data %>%
    left_join(cpi_data, by = "year")

  cat(sprintf("  ✓ Merged CPI dataset (%d rows)\n", nrow(cpi_data)))
} else {
  cat("  ⚠ CPI dataset not found, skipping\n")
}

# Load GFD Yields dataset
yields_file <- file.path(sources_dir, "GFD", "GFD_US_Yields.dta")
if (file.exists(yields_file)) {
  yields_data <- haven::read_dta(yields_file) %>%
    mutate(across(where(haven::is.labelled), as.numeric)) %>%
    select(year, yield_IGUSA10D, spr_baa_10ytreas, spr_aaa_10ytreas,
           spr_HYrail_10ytreas_aug, spr_10_2)

  combined_data <- combined_data %>%
    left_join(yields_data, by = "year")

  cat(sprintf("  ✓ Merged Yields dataset (%d rows)\n", nrow(yields_data)))
} else {
  cat("  ⚠ Yields dataset not found, skipping\n")
}

# --------------------------------------------------------------------------
# 4.6. Deflate monetary variables by CPI (Replicates Stata lines 25-34)
# --------------------------------------------------------------------------
cat("\nPart 4.6: Deflating monetary variables by CPI...\n")

if ("cpi_gfd" %in% names(combined_data)) {
  deflate_vars <- c("assets", "deposits", "loans", "interbank", "liquid",
                    "oreo", "equity", "emergency", "capital",
                    "deposits_time", "deposits_demand", "otherbor_liab",
                    "brokered_dep", "insured_deposits",
                    "ln_cons", "ln_cc", "ln_ci", "ln_oth", "ln_fi", "ln_re",
                    "npl_tot", "ytdllprov", "ytdnetinc", "ytdint_exp_dep",
                    "ytdint_inc_ln", "bonds_circ", "rediscounts", "bills_payable",
                    "undivided_profits", "surplus", "securities_other",
                    "demand_deposits", "time_deposits", "notes_nb",
                    "surplus_profit", "res_funding", "total_deposits")

  deflated_count <- 0
  for (var in deflate_vars) {
    if (var %in% names(combined_data)) {
      combined_data[[var]] <- combined_data[[var]] / combined_data$cpi_gfd
      deflated_count <- deflated_count + 1
    }
  }

  cat(sprintf("  ✓ Deflated %d monetary variables by cpi_gfd\n", deflated_count))
} else {
  cat("  ⚠ cpi_gfd not found, skipping deflation\n")
}

# --------------------------------------------------------------------------
# 5. Prepare data & create variables (Replicates Stata lines 13-148)
# --------------------------------------------------------------------------
cat("\nPart 5: Variable creation and data preparation...\n")

# Replace time_to_fail with missing if not a failed bank (Stata line 13)
combined_data <- combined_data %>%
  mutate(
    time_to_fail = if_else(!is.na(failed_bank) & failed_bank == 0, NA_real_, time_to_fail)
  )

cat("  Creating basic transformations...\n")
combined_data <- combined_data %>%
  mutate(
    # Log age (Stata line 44)
    log_age = log(age),

    # Size (Stata line 47)
    size = log(assets)
  )

# Size categories by year (Stata line 49)
combined_data <- combined_data %>%
  group_by(year) %>%
  mutate(
    size_cat = ntile(assets, 4)
  ) %>%
  ungroup()

# Crisis indicator (Stata lines 52-55)
combined_data <- combined_data %>%
  mutate(
    crisisBVX = as.integer(year %in% c(1873, 1884, 1890, 1893, 1907, 1930, 1984, 1990, 2007))
  )

cat("  Creating ratio variables...\n")

# Helper function to replace 0 with NA (Stata pattern: replace X = . if X==0)
safe_ratio <- function(numerator, denominator) {
  result <- numerator / denominator
  result[numerator == 0] <- NA_real_
  result
}

combined_data <- combined_data %>%
  mutate(
    # Liquid assets ratio (Stata lines 61-62)
    liquid_ratio = safe_ratio(liquid, assets),

    # Equity/leverage ratios (Stata lines 66, 68)
    leverage = equity / assets,          # This is equity_ratio
    equity_ratio = equity / assets,      # Explicit name for clarity
    leverage_capital = capital / assets,

    # Surplus/profitability measures (Stata lines 71, 73-75)
    surplus_ratio = surplus_profit / equity,
    equity_shortfall = as.integer(!is.na(surplus_ratio) & surplus_ratio <= 0.25),
    profits_ratio = undivided_profits / equity,
    profit_shortfall = as.integer(!is.na(profits_ratio) & profits_ratio < 0.01),

    # OREO/NPL proxy (Stata lines 79-80)
    oreo_ratio = oreo / (loans + oreo),
    oreo_dummy = as.integer(!is.na(oreo) & oreo > 0),

    # Loan ratio (Stata line 82)
    loan_ratio = loans / assets,
    loans_ratio = loans / assets,        # Explicit name for clarity

    # Deposit ratios (Stata lines 83-84)
    deposit_ratio = deposits / assets,
    deposit_ratio_alt = total_deposits / assets,

    # Noncore funding ratio (Stata lines 88, 91-92)
    noncore_ratio = res_funding / assets
  )

# Modern era noncore funding adjustment (Stata lines 91-92)
combined_data <- combined_data %>%
  mutate(
    noncore_funding_temp = if_else(!is.na(deposits_time) | !is.na(otherbor_liab),
                                   coalesce(deposits_time, 0) + coalesce(otherbor_liab, 0),
                                   NA_real_),
    noncore_ratio = if_else(year > 1941 & !is.na(noncore_funding_temp),
                           noncore_funding_temp / assets,
                           noncore_ratio)
  ) %>%
  select(-noncore_funding_temp)

combined_data <- combined_data %>%
  mutate(
    # Emergency borrowing (Stata lines 96-98)
    emergency_borrowing = emergency / assets,
    emergency_borrowing = if_else(year >= 1905 & year <= 1928, NA_real_, emergency_borrowing),
    emerg_dummy = as.integer(!is.na(emergency_borrowing) & emergency_borrowing > 0),

    # Interbank ratio (Stata line 100)
    interbank_ratio = interbank / assets,

    # Time deposits ratio (Stata lines 102-105)
    time_ratio = if_else(time_deposits == 0, NA_real_, time_deposits / assets),
    time_ratio = if_else(year > 1945 & !is.na(deposits_time),
                        deposits_time / assets,
                        time_ratio),

    # Demand deposits ratio (Stata lines 107-109)
    demand_ratio = if_else(demand_deposits == 0, NA_real_, demand_deposits / assets),

    # Income statement ratios (Stata lines 113-118)
    income_ratio = ytdnetinc / assets,
    npl_ratio = npl_tot / loans,
    prov_ratio = ytdllprov / loans,
    int_exp_ratio = ytdint_exp_dep / assets,
    int_inc_ratio = ytdint_inc_ln / assets,
    nim = (ytdint_inc_ln - ytdint_exp_dep) / assets
  )

# Set income ratios to missing for non-Q4 quarters (Stata lines 120-122)
combined_data <- combined_data %>%
  mutate(
    income_ratio = if_else(!is.na(quarter_number) & quarter_number != 4, NA_real_, income_ratio),
    prov_ratio = if_else(!is.na(quarter_number) & quarter_number != 4, NA_real_, prov_ratio),
    int_inc_ratio = if_else(!is.na(quarter_number) & quarter_number != 4, NA_real_, int_inc_ratio),
    int_exp_ratio = if_else(!is.na(quarter_number) & quarter_number != 4, NA_real_, int_exp_ratio)
  )

# Modern loan composition ratios (Stata lines 125-127)
if ("ln_cons" %in% names(combined_data)) {
  combined_data <- combined_data %>%
    mutate(
      ln_cons_ratio = ln_cons / loans,
      ln_cc_ratio = ln_cc / loans,
      ln_ci_ratio = ln_ci / loans,
      ln_oth_ratio = ln_oth / loans,
      ln_fi_ratio = ln_fi / loans,
      ln_re_ratio = ln_re / loans
    )
}

# Modern funding composition ratios (Stata lines 130-132)
if ("deposits_time" %in% names(combined_data)) {
  combined_data <- combined_data %>%
    mutate(
      deposits_time_ratio = deposits_time / assets,
      deposits_demand_ratio = deposits_demand / assets,
      otherbor_liab_ratio = otherbor_liab / assets,
      brokered_dep_ratio = brokered_dep / assets,
      insured_deposits_ratio = insured_deposits / assets
    )
}

cat("  Applying outlier management...\n")

# Clip extreme income ratios (Stata lines 138-141)
clip_values <- function(x, lower, upper) {
  x[!is.na(x) & x < lower] <- lower
  x[!is.na(x) & x > upper] <- upper
  x
}

combined_data <- combined_data %>%
  mutate(
    income_ratio = clip_values(income_ratio, -0.5, 0.5),
    nim = clip_values(nim, -0.5, 0.5),
    int_exp_ratio = clip_values(int_exp_ratio, 0, 1),
    int_inc_ratio = clip_values(int_inc_ratio, 0, 1)
  )

# Replace invalid ratios with NA (Stata lines 143-147)
ratio_vars <- c("leverage", "surplus_profit", "liquid_ratio", "oreo_ratio",
                "deposit_ratio", "noncore_ratio", "time_ratio", "profits_ratio",
                "profit_shortfall", "demand_ratio")

for (var in ratio_vars) {
  if (var %in% names(combined_data)) {
    combined_data[[var]][!is.na(combined_data[[var]]) & combined_data[[var]] > 1] <- NA_real_
    combined_data[[var]][!is.na(combined_data[[var]]) & combined_data[[var]] < 0] <- NA_real_
  }
}

cat(sprintf("  ✓ Created comprehensive variable set matching Stata\n"))
cat(sprintf("  ✓ Critical ratios: liquid_ratio, equity_ratio, loans_ratio, oreo_ratio\n"))
cat(sprintf("  ✓ Total derived variables: ~40+\n"))

# --------------------------------------------------------------------------
# 6. Save combined dataset
# --------------------------------------------------------------------------
cat("\nPart 6: Saving combined dataset...\n")

# Save as RDS
combined_rds_file <- file.path(dataclean_dir, "combined-data.rds")
saveRDS(combined_data, combined_rds_file)
cat(sprintf("  ✓ Saved RDS: %s\n", basename(combined_rds_file)))

# Save as Stata format (optional, for compatibility)
combined_dta_file <- file.path(dataclean_dir, "combined-data.dta")
haven::write_dta(combined_data, combined_dta_file)
cat(sprintf("  ✓ Saved DTA: %s\n", basename(combined_dta_file)))

# --------------------------------------------------------------------------
# 7. Summary statistics
# --------------------------------------------------------------------------
cat("\nPart 7: Summary statistics...\n")

if ("year" %in% names(combined_data)) {
  cat(sprintf("  Year range: %d to %d\n", 
              min(combined_data$year, na.rm = TRUE),
              max(combined_data$year, na.rm = TRUE)))
}

if ("bank_id" %in% names(combined_data)) {
  n_banks <- n_distinct(combined_data$bank_id, na.rm = TRUE)
  cat(sprintf("  Unique banks: %d\n", n_banks))
}

cat("\n===========================================================================\n")
cat("SCRIPT 07 COMPLETED SUCCESSFULLY\n")
cat("===========================================================================\n")
cat(sprintf("  Combined dataset: %d observations\n", nrow(combined_data)))
cat(sprintf("  Saved to: %s\n", combined_rds_file))
cat("===========================================================================\n\n")
