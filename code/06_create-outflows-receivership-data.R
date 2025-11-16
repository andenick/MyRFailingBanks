# ===========================================================================
# Create Outflows and Receivership Data
# Replicates: 06_create-outflows-receivership-data.do from QJE Stata replication kit
#
# NOTE: This is a full rewrite to correctly replicate the Stata logic.
#
# v8: Fixes "Unable to read from file" I/O error.
#     The script now reads the stable .rds files (created by 04 and 05)
#     instead of the corrupt/unreadable .dta files.
# ===========================================================================

library(haven)
library(dplyr)
library(lubridate)
library(here)
library(tidyr)

# Source the setup script for directory paths
source(here::here("code", "00_setup.R"))

# Helper function to replicate Stata's max(var) by group
# This correctly returns NA if all values in the group are NA.
safe_max <- function(x) {
  valid_x <- x[!is.na(x)]
  if (length(valid_x) == 0) {
    return(NA_real_)
  } else {
    return(max(valid_x, na.rm = TRUE))
  }
}

# --------------------------------------------------------------------------
# PART 1: Load historical data and prepare for merge
# --------------------------------------------------------------------------

message("Part 1: Loading processed historical call reports...")

#
# *** FIX 1 ***
# Load the stable .rds file created by script 04, not the corrupt .dta
#
historical_calls <- readRDS(file.path(tempfiles_dir, "call-reports-historical.rds"))

calls_temp <- historical_calls %>%
  arrange(bank_id, year) %>%
  group_by(bank_id) %>%
  mutate(
    growth_boom = (lag(loans, n = 3) / lag(loans, n = 10)) - 1,
    growth_bust = (loans / lag(loans, n = 3)) - 1
  ) %>%
  ungroup() %>%
  # Replicate xtile(var), by(year) - this correctly handles NAs
  group_by(year) %>%
  mutate(
    growth_boom_cat = ntile(growth_boom, 5),
    growth_bust_cat = ntile(growth_bust, 5)
  ) %>%
  ungroup() %>%
  # Replicate egen no_of_banks = count(...)
  group_by(city_name, state_abbrev, year) %>%
  mutate(no_of_banks = n()) %>%
  ungroup() %>%

  # Keep last obs. before receivership
  filter(end_has_receivership == 1) %>%

  # generate indicator for cases with multiple failures
  arrange(bank_id, year) %>%
  group_by(bank_id) %>%
  mutate(
    failure_event = (end_date != lag(end_date)) &
      (end_cause %in% c("receivership", "voluntary_liquidation")),
    # Coalesce NA to FALSE (0) for cumsum
    i = cumsum(coalesce(failure_event, FALSE))
  ) %>%

  # keep last call before event (replicates bys bank_id i (year): keep if _n==_N)
  group_by(bank_id, i) %>%
  slice_tail(n = 1) %>%
  ungroup() %>%
  select(-failure_event)

# --------------------------------------------------------------------------
# PART 2: Load receivership data and calculate historical runs
# --------------------------------------------------------------------------

message("Part 2: Loading and cleaning receivership data...")

# --- FIX VARIABLE TYPE MISMATCH AND DUPLICATES BEFORE MERGING ---
# First, load the 'using' dataset to correct it.
fixed_dates_corrected <- read_dta(file.path(sources_dir, "occ-receiverships", "fixed_dates.dta")) %>%
  # Convert the string 'raw_date' to a numeric R date.
  mutate(raw_date_numeric = as.Date(raw_date, format = "%m/%d/%Y")) %>%
  # Replace the old string variable
  select(-raw_date) %>%
  rename(raw_date = raw_date_numeric) %>%
  # Remove duplicate dates to allow for a m:1 merge.
  distinct(raw_date, .keep_all = TRUE)

# --- RESUME ORIGINAL SCRIPT WITH THE MASTER DATA ---
receiverships_all <- read_dta(file.path(sources_dir, "occ-receiverships", "receiverships_all.dta")) %>%
  # Generate the numeric key variable (date_closed is a Stata %td date)
  mutate(raw_date = as.Date(date_closed, origin = "1960-01-01"))

# Now, merge using the corrected temporary file. Both keys are numeric.
receiverships_merged <- left_join(receiverships_all, fixed_dates_corrected, by = "raw_date") %>%
  # Drop original date_closed, rename new one
  select(-date_closed) %>%
  rename(date_closed = fixed_date) %>%

  # Keep only needed variables
  select(
    charter, date_receiver_appt, date_closed, deposits_at_suspension, assets_at_suspension,
    failure_id, simplified_cause_of_failure, collected_from_shareholders,
    collected_from_assets, total_collections_all_sources, total_coll_all_sources_incl_off,
    offsets_allowed_and_settled, amt_claims_proved, borrowed_money_at_suspension,
    loans_paid_other_imp, assets_suspension_additional, assets_suspension_good,
    assets_suspension_doubtful, assets_suspension_worthless, dividends,
    total_liab_established
  ) %>%

  # generate indicator for cases with multiple failures
  group_by(charter) %>%
  arrange(failure_id) %>%
  mutate(i = row_number()) %>%
  ungroup()

# --- Merge call data and receivership data ---
message("Merging call data with receivership data...")
cat(sprintf("  receiverships_merged N = %d\n", nrow(receiverships_merged)))
cat(sprintf("  calls_temp N = %d\n", nrow(calls_temp)))

# Replicates `merge 1:1 charter i using "`calls'"`
# The Stata merge keeps _merge==1 (master only) and _merge==3 (both)
# and drops _merge==2 (using only)
# This is equivalent to a left_join in R (keep all master records)
receivership_dataset_tmp <- left_join(receiverships_merged, calls_temp, by = c("charter", "i"))

# Save receivership_dataset_tmp (replicates Stata line 113)
message("Saving receivership_dataset_tmp...")
cat(sprintf("  N = %d observations\n", nrow(receivership_dataset_tmp)))
saveRDS(receivership_dataset_tmp, file.path(tempfiles_dir, "receivership_dataset_tmp.rds"))
write_dta(receivership_dataset_tmp, file.path(tempfiles_dir, "receivership_dataset_tmp.dta"))

# Now calculate growth rates
# Replicates `drop if mi(charter)` (which inner_join does by default)
hist_outflows <- receivership_dataset_tmp %>%

  # Calculate growth rates
  mutate(
    diff = as.numeric(call_date - receivership_date),

    # deposits_growth = deposits_at_suspension/(deposits+interbank)-1 if year<1929
    deposits_growth = ifelse(year < 1929,
                             (deposits_at_suspension / (deposits + interbank)) - 1,
                             (deposits_at_suspension / deposits) - 1),

    # assets_growth = assets_at_suspension/(assets-notes_nb)-1 if assets!=0
    assets_growth = ifelse(assets != 0,
                           (assets_at_suspension / (assets - notes_nb)) - 1,
                           NA_real_),

    # Trim to take care of positive outliers (OCR)
    deposits_growth = pmin(pmax(deposits_growth, -1), 1),
    assets_growth = pmin(pmax(assets_growth, -1), 1),

    # transform to ppt
    growth_deposits = deposits_growth * 100,
    growth_assets = assets_growth * 100,

    # save run indicator for AUC regressions
    run = ifelse(is.na(growth_deposits), NA, growth_deposits < -7.5),
    run_alt1 = ifelse(is.na(growth_deposits), NA, growth_deposits < -10),
    run_alt2 = ifelse(is.na(growth_deposits), NA, growth_deposits < -5),
    run_alt3 = ifelse(is.na(growth_deposits), NA, growth_deposits < -12.5)
  )

# Save the historical deposit outflows dataset
message("Saving historical outflows data to $data...")
write_dta(
  hist_outflows,
  file.path(dataclean_dir, "deposits_before_failure_historical.dta")
)

# --- Create the temp run dummy file ---
temp_bank_run_dummy <- hist_outflows %>%
  select(bank_id, charter, run, run_alt1, run_alt2, run_alt3, i, year) %>%
  filter(!is.na(bank_id))

saveRDS(temp_bank_run_dummy, file.path(tempfiles_dir, "temp_bank_run_dummy.rds"))


# --------------------------------------------------------------------------
# PART 3: Merge historical run dummy back to main historical data
# --------------------------------------------------------------------------

message("Part 3: Merging historical run dummies back into main historical file...")

#
# *** FIX 2 ***
# Load the stable .rds file created by script 04, not the corrupt .dta
#
historical_data_full <- readRDS(file.path(tempfiles_dir, "call-reports-historical.rds")) %>%
  # Prepare merge key 'i'
  arrange(charter, year) %>%
  group_by(charter) %>%
  mutate(
    event = (end_date != lag(end_date)) & (end_cause == "receivership"),
    i = cumsum(coalesce(event, FALSE))
  ) %>%
  ungroup() %>%
  select(-event)

# Load the dummy file we just made
temp_run_dummy <- readRDS(file.path(tempfiles_dir, "temp_bank_run_dummy.rds"))

# Merge m:1 bank_id i
historical_edited <- left_join(
  historical_data_full,
  temp_run_dummy %>% select(bank_id, i, run, run_alt1, run_alt2, run_alt3),
  by = c("bank_id", "i")
) %>%
  # Fix run merge issues (replicate the foreach loop)
  group_by(bank_id) %>%
  mutate(
    run = ifelse(is.na(run), safe_max(run), run),
    run_alt1 = ifelse(is.na(run_alt1), safe_max(run_alt1), run_alt1),
    run_alt2 = ifelse(is.na(run_alt2), safe_max(run_alt2), run_alt2),
    run_alt3 = ifelse(is.na(run_alt3), safe_max(run_alt3), run_alt3)
  ) %>%
  ungroup()

# Save the edited historical file
write_dta(
  historical_edited,
  file.path(tempfiles_dir, "call-reports-historical-edited.dta")
)

# --------------------------------------------------------------------------
# PART 4: Repeat for Modern Data
# --------------------------------------------------------------------------

message("Part 4: Calculating and merging modern run dummies...")

#
# *** FIX 3 *** (This is the one that caused the crash)
# Load the stable .rds file created by script 05, not the corrupt .dta
#
modern_data_original <- readRDS(file.path(tempfiles_dir, "call-reports-modern.rds"))

# Generate modern data deposit outflows
modern_outflows <- modern_data_original %>%
  filter(year >= 1993, quarters_to_failure == -1) %>%

  # Adjust units: resdep/resasset are in thousands, deposits/assets are in dollars.
  # We must divide deposits/assets by 1000 to make them comparable.
  mutate(
    deposits_k = deposits / 1000,
    assets_k = assets / 1000
  ) %>%

  # Generate growth in deposits and assets
  mutate(
    deposits_growth = (resdep / deposits_k) - 1,
    assets_growth = (resasset / assets_k) - 1,

    # 2 extreme outliers
    deposits_growth = pmin(pmax(deposits_growth, -1), 1),

    growth_deposits = deposits_growth * 100,
    growth_assets = assets_growth * 100,

    # save run indicator
    run = ifelse(is.na(growth_deposits), NA, growth_deposits < -7.5)
  )

# Save the modern deposit outflows dataset
write_dta(
  modern_outflows,
  file.path(dataclean_dir, "deposits_before_failure_modern.dta")
)

# --- Create and merge the modern run dummy ---

# Create the dummy file, ensuring it is unique per bank-year
temp_modern_run_dummy <- modern_outflows %>%
  group_by(bank_id, year) %>%
  # Take the max 'run' value (handles case of 0 and 1 in same year)
  summarise(run = max(run, na.rm = TRUE), .groups = "drop") %>%
  # Re-convert -Inf (from max(NA, NA)) back to NA
  mutate(run = ifelse(is.infinite(run), NA, run))

# Merge run dummy to balance sheet data
# We merge onto the "modern_data_original" object, which we know is clean.
modern_data_edited <- left_join(
  modern_data_original,
  temp_modern_run_dummy,
  by = c("bank_id", "year")
)

# Overwrite the main modern data file in $temp
write_dta(
  modern_data_edited,
  file.path(tempfiles_dir, "call-reports-modern.dta")
)

message("06_create_outflows_receivership_data.R completed successfully")
message(sprintf("  - Saved: %s", file.path(dataclean_dir, "deposits_before_failure_historical.dta")))
message(sprintf("  - Saved: %s", file.path(tempfiles_dir, "call-reports-historical-edited.dta")))
message(sprintf("  - Saved: %s", file.path(dataclean_dir, "deposits_before_failure_modern.dta")))
message(sprintf("  - Overwrote: %s", file.path(tempfiles_dir, "call-reports-modern.dta")))
