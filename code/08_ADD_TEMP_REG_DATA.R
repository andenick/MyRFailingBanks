# ===========================================================================
# Add-on to Script 08: Create temp_reg_data for Scripts 35, 51-54
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
  # Drop banks that already failed
  filter(!(failed_bank == 1 & quarters_to_failure > 0)) %>%

  # Create run_is_missing indicator
  mutate(
    run_is_missing = (year < 1880) | (year >= 1959 & year <= 1992) | (is.na(run) & failed_bank == 1),

    # Generate failure dummies for LHS variables
    F1_failure = ifelse(days_to_failure >= 1 & days_to_failure <= 365, 1, 0),
    F3_failure = ifelse(quarters_to_failure >= -12 & quarters_to_failure <= -1, 1, 0),
    F5_failure = ifelse(quarters_to_failure >= -20 & quarters_to_failure <= -1, 1, 0),

    F1_failure_run = ifelse(!is.na(F1_failure) & run_is_missing == 0,
                           ifelse(F1_failure == 1 & run == 1, 1, 0), NA),
    F3_failure_run = ifelse(!is.na(F3_failure) & run_is_missing == 0,
                           ifelse(F3_failure == 1 & run == 1, 1, 0), NA)
  ) %>%
  select(-run_is_missing) %>%

  # Make sure to use only annual data (Q4) for post-1959
  filter(!(is.na(income_ratio) & year > 1941)) %>%

  # Generate 3-year growth
  arrange(bank_id, year, quarter) %>%
  group_by(bank_id) %>%
  mutate(
    L3_assets = lag(assets, 3),
    growth = log(assets) - log(L3_assets)
  ) %>%
  ungroup() %>%

  # Generate growth quintile by year
  group_by(year) %>%
  mutate(growth_cat = ntile(growth, 5)) %>%
  ungroup() %>%
  select(-L3_assets) %>%

  # Drop De Novo banks (age < 3)
  # CRITICAL: In Stata, "drop if age < 3" keeps NA values!
  # In R, filter(age >= 3) removes NA values, so we must keep them explicitly
  filter(is.na(age) | age >= 3)

# Save temp_reg_data
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
  cat("\nSee STATA_CHECKPOINTS.md for debugging steps.\n")
} else {
  cat("\n✓ Perfect replication achieved!\n")
}

message("08_ADD_TEMP_REG_DATA.R completed successfully")
