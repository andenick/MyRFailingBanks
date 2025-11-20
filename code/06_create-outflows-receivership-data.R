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
  # Rename bank_charter_num to charter (matching Stata script line 59)
  rename(charter = bank_charter_num) %>%
  # Generate the numeric key variable (date_closed is a character string like "Jan. 2, 1867")
  # Parse it using lubridate's mdy function - some dates may fail to parse
  mutate(raw_date = suppressWarnings(lubridate::mdy(date_closed)))
