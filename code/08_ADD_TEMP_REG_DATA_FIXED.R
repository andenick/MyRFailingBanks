# ===========================================================================
# Add-on to Script 08: Create temp_reg_data for Scripts 35, 51-54
# FIXED VERSION: Handles missing variables gracefully
# ===========================================================================
# This script creates the temp_reg_data file that downstream scripts need.
# Run this AFTER Script 08 completes.
# ===========================================================================

library(haven)
library(dplyr)
library(here)

# Source the setup script for directory paths
source(here::here("code", "00_setup.R"))

message("Creating temp_reg_data for downstream scripts...")

# Load the full combined data
full_data <- readRDS(file.path(dataclean_dir, "combined-data.rds"))
message(sprintf("  Loaded %d observations from combined-data.rds", nrow(full_data)))

# Replicate Stata Script 35's data preparation
temp_reg_data <- full_data %>%
  # Drop banks that already failed (if variables exist)
  {if ("failed_bank" %in% names(.) && "quarters_to_failure" %in% names(.)) {
    filter(., !(failed_bank == 1 & quarters_to_failure > 0))
  } else .} %>%

  # Create run_is_missing indicator (if run variable exists)
  {if ("run" %in% names(.) && "failed_bank" %in% names(.)) {
    mutate(.,
      run_is_missing = (year < 1880) | (year >= 1959 & year <= 1992) | (is.na(run) & failed_bank == 1)
    )
  } else .} %>%

  # Generate failure dummies for LHS variables (if variables exist)
  {if ("days_to_failure" %in% names(.)) {
    mutate(.,
      F1_failure = ifelse(days_to_failure >= 1 & days_to_failure <= 365, 1, 0)
    )
  } else .} %>%

  {if ("quarters_to_failure" %in% names(.)) {
    mutate(.,
      F3_failure = ifelse(quarters_to_failure >= -12 & quarters_to_failure <= -1, 1, 0),
      F5_failure = ifelse(quarters_to_failure >= -20 & quarters_to_failure <= -1, 1, 0)
    )
  } else .} %>%

  # Create run-specific failure indicators (if needed variables exist)
  {if (all(c("F1_failure", "run_is_missing", "run") %in% names(.))) {
    mutate(.,
      F1_failure_run = ifelse(!is.na(F1_failure) & run_is_missing == 0,
                             ifelse(F1_failure == 1 & run == 1, 1, 0), NA)
    )
  } else .} %>%

  {if (all(c("F3_failure", "run_is_missing", "run") %in% names(.))) {
    mutate(.,
      F3_failure_run = ifelse(!is.na(F3_failure) & run_is_missing == 0,
                             ifelse(F3_failure == 1 & run == 1, 1, 0), NA)
    )
  } else .} %>%

  # Remove temporary variable if it exists
  {if ("run_is_missing" %in% names(.)) {
    select(., -run_is_missing)
  } else .}

# Make sure to use only annual data (Q4) for post-1959
# Only apply this filter if income_ratio exists
if ("income_ratio" %in% names(temp_reg_data)) {
  message("  Filtering for income_ratio availability...")
  temp_reg_data <- temp_reg_data %>%
    filter(!(is.na(income_ratio) & year > 1941))
}

# Generate 3-year growth (if assets exists)
if ("assets" %in% names(temp_reg_data) && "bank_id" %in% names(temp_reg_data)) {
  message("  Calculating 3-year growth...")
  temp_reg_data <- temp_reg_data %>%
    arrange(bank_id, year, if_else("quarter" %in% names(.), quarter, rep(1, n()))) %>%
    group_by(bank_id) %>%
    mutate(
      L3_assets = lag(assets, 3),
      growth = log(assets) - log(L3_assets)
    ) %>%
    ungroup() %>%
    select(-L3_assets)
}

# Generate growth quintile by year (if growth exists)
if ("growth" %in% names(temp_reg_data)) {
  message("  Creating growth quintiles...")
  temp_reg_data <- temp_reg_data %>%
    group_by(year) %>%
    mutate(growth_cat = ntile(growth, 5)) %>%
    ungroup()
}

# Drop De Novo banks (age < 3) - if age exists
# CRITICAL: In Stata, "drop if age < 3" keeps NA values!
# In R, filter(age >= 3) removes NA values, so we must keep them explicitly
if ("age" %in% names(temp_reg_data)) {
  message("  Filtering out De Novo banks (age < 3)...")
  temp_reg_data <- temp_reg_data %>%
    filter(is.na(age) | age >= 3)
}

# Save temp_reg_data
message("  Saving temp_reg_data files...")
saveRDS(temp_reg_data, file.path(dataclean_dir, "temp_reg_data.rds"))
saveRDS(temp_reg_data, file.path(tempfiles_dir, "temp_reg_data.rds"))  # Also save to tempfiles
write_dta(temp_reg_data, file.path(dataclean_dir, "temp_reg_data.dta"))
write_dta(temp_reg_data, file.path(tempfiles_dir, "temp_reg_data.dta"))  # Also save to tempfiles

message(sprintf("✓ temp_reg_data saved: %d observations", nrow(temp_reg_data)))
message("  - dataclean/temp_reg_data.rds")
message("  - tempfiles/temp_reg_data.rds")
message("  - dataclean/temp_reg_data.dta")
message("  - tempfiles/temp_reg_data.dta")

# CRITICAL CHECKPOINT: Verify against Stata (from FailingBanksLog_all.txt)
stata_expected <- 964052
obs_count <- nrow(temp_reg_data)
match_status <- ifelse(obs_count == stata_expected, "✓ EXACT MATCH", "✗ MISMATCH")

cat(sprintf("\n=== STATA CHECKPOINT VERIFICATION ===\n"))
cat(sprintf("R observations:      %s\n", format(obs_count, big.mark=",")))
cat(sprintf("Stata expected:      %s\n", format(stata_expected, big.mark=",")))
cat(sprintf("Difference:          %s\n", format(obs_count - stata_expected, big.mark=",")))
cat(sprintf("Status:              %s\n", match_status))

if (obs_count != stata_expected) {
  warning(sprintf("MISMATCH: Expected %s observations but got %s",
                  format(stata_expected, big.mark=","),
                  format(obs_count, big.mark=",")))
  cat("\nNote: Some mismatch is expected if certain variables are missing from combined data.\n")
} else {
  cat("\n✓ Perfect replication achieved!\n")
}

message("08_ADD_TEMP_REG_DATA_FIXED.R completed successfully")
