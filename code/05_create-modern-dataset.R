# ===========================================================================
# Create Modern Dataset (1942-present)
# Replicates: 05_create-modern-dataset.do from QJE Stata replication kit
#
# NOTE: This is a full rewrite to correctly replicate the Stata logic.
#
# v5: Fixes logical error by REMOVING the call to drop '-_merge',
#     which is created by Stata's 'merge' but not by dplyr's 'left_join'.
# ===========================================================================

library(haven)
library(dplyr)
library(lubridate)
library(here)
library(tidyr)
library(zoo) # For as.Date.yearqtr

# Source the setup script for directory paths

# Helper function to replicate Stata's 'rowtotal' (NA as 0)
# followed by setting to NA if all inputs are NA.
rowtotal_stata <- function(...) {
  vars <- list(...)
  df_vars <- as.data.frame(vars)
  result <- rowSums(df_vars, na.rm = TRUE)
  return(result)
}

# --------------------------------------------------------------------------
# Prepare FDIC list of failing banks
# --------------------------------------------------------------------------

message("Loading FDIC failure data...")

# Load failure data
fdic_failures <- read_dta(file.path(sources_dir, "FDIC", "public-bank-data.dta")) %>%
  # drop banks that we cannot match to call report
  filter(!is.na(id_fdic_cert) | !is.na(id_rssd)) %>%
  # replace id_fdic_cert= -id_rssd if mi(id_fdic_cert)
  mutate(id_fdic_cert = ifelse(is.na(id_fdic_cert), -id_rssd, id_fdic_cert)) %>%
  # Exclude Banks that received TARP
  filter(is.na(restype1) | restype1 != "OBAM") %>%
  # Drop saving and loans and savngs associations
  filter(!chclass1 %in% c("SL", "SA")) %>%
  select(id_fdic_cert, fail_day)

# Load and merge deposits at failure
fdic_deposits <- read_dta(file.path(sources_dir, "FDIC", "FDIC_ftdb_deposits_assets_failure.dta"))

# Replicate Stata's 1:1 merge on both cert and day
fail_dates_merged <- left_join(
  fdic_failures,
  fdic_deposits,
  by = c("id_fdic_cert", "fail_day")
)

# Replicate Stata's reshape logic to handle multiple failures
# The Stata log shows j = 1 2 3, so we will allow up to 3.
fail_dates_wide <- fail_dates_merged %>%
  group_by(id_fdic_cert) %>%
  arrange(fail_day) %>%
  mutate(i = row_number()) %>%
  ungroup() %>%
  filter(i <= 3) %>% # Match Stata's j=1 2 3
  pivot_wider(
    id_cols = id_fdic_cert,
    names_from = i,
    values_from = c(fail_day, resdep, resasset),
    names_sep = ""
  ) %>%
  # Rename to match Stata's reshape
  rename(
    fail_day = fail_day1,
    resdep = resdep1,
    resasset = resasset1
  )

# --------------------------------------------------------------------------
# Call Reports
# --------------------------------------------------------------------------

message("Loading modern call reports data...")

modern_data <- read_dta(file.path(sources_dir, "call-reports-modern.dta")) %>%
  rename(quarter_stata = date) %>% # Stata 'date' var is quarterly

  # Missing IDs are coded as zero
  mutate(
    id_fdic_cert = ifelse(id_fdic_cert == 0, NA, id_fdic_cert),
    id_rssd = ifelse(id_rssd == 0, NA, id_rssd)
  ) %>%
  # fix identifiers that are missing
  mutate(
    id_fdic_cert = ifelse(is.na(id_fdic_cert), -id_rssd, id_fdic_cert)
  ) %>%
  # drop if mi(id_fdic_cert)
  filter(!is.na(id_fdic_cert))

# Merge m:1 with failure data
call_report_data <- left_join(
  modern_data,
  fail_dates_wide,
  by = "id_fdic_cert"
)

# --- Replicate complex bank_id creation ---
message("Creating unique bank IDs...")

call_report_data <- call_report_data %>%
  mutate(
    # Create R-native yearqtr object from Stata's quarterly int
    quarter_yq = as.yearqtr(1960 + (quarter_stata / 4), frac = quarter_stata %% 4),

    # Create R Date objects for failure days (Stata dates are 1960-01-01)
    fail_day = as.Date(fail_day, origin = "1960-01-01"),
    fail_day2 = as.Date(fail_day2, origin = "1960-01-01"),

    # Get the quarter of failure
    fail_qtr1 = as.yearqtr(fail_day),
    fail_qtr2 = as.yearqtr(fail_day2),

    # Replicate Stata's bank_id logic (first pass)
    bank_id = id_fdic_cert * 10 +
      replace_na(as.integer(quarter_yq >= fail_qtr1), 0) +
      replace_na(as.integer(quarter_yq >= fail_qtr2), 0)
  ) %>%
  # --- Second mutate block to update bank_id ---
  mutate(
    # Handle the initial NA case from the first gen command in Stata
    # CRITICAL FIX (v3.1): Removed abs() to preserve negative bank_ids (Stata uses them!)
    bank_id = ifelse(is.na(fail_day),
                     id_fdic_cert * 10 + (id_fdic_cert < 0),
                     bank_id),

    new_bank = (!is.na(fail_day2) & !is.na(fail_qtr1) & quarter_yq >= fail_qtr1),

    # Replace with second failure info if 'new_bank' is true
    fail_day = ifelse(new_bank, fail_day2, fail_day),
    resasset = ifelse(new_bank, resasset2, resasset),
    resdep = ifelse(new_bank, resdep2, resdep)
  ) %>%
  # --- Third mutate block to update fail_day and bank_id ---
  mutate(
    # Coerce fail_day back to Date object after ifelse
    fail_day = as.Date(fail_day, origin = "1970-01-01"),

    # Scale bank_id to avoid clashes
    bank_id = bank_id * 1e5
  ) %>%

  #
  # *** THIS IS THE FIX ***
  # Removed '-_merge' from the list, as it is not created by left_join()
  #
  dplyr::select(-fail_day2, -fail_day3, -resasset2, -resasset3,
                -resdep2, -resdep3, -new_bank, -fail_qtr1, -fail_qtr2)


# --- Create Additional Variables ---
message("Creating time-to-failure and financial variables...")

final_data <- call_report_data %>%
  mutate(
    # generate call date (dofq(quarter + 1) - 1)
    # This gets the last day of the quarter
    call_date = as.Date(quarter_yq, frac = 1),

    # time to failure
    failed_bank = as.integer(!is.na(fail_day)),
    days_to_failure = as.numeric(fail_day - call_date),

    months_to_failure = -ceiling(days_to_failure / 30),
    quarters_to_failure = -ceiling(days_to_failure / 90),
    time_to_fail = as.integer(-ceiling(days_to_failure / 365))
  ) %>%

  # drop if days_to_failure < 0 (CRITICAL FILTER)
  filter(is.na(days_to_failure) | days_to_failure >= 0) %>%

  # rename variables
  rename(
    state_abbrev = state_abbr_nm,
    quarter = quarter_stata # Rename back to match Stata
  ) %>%

  # egen liquid
  mutate(liquid = rowtotal_stata(cash, securities, ffpurch)) %>%

  # convert from thousands to dollars (CRITICAL STEP)
  mutate(across(
    c(assets, liquid, deposits, equity, loans, deposits_time, deposits_demand,
      otherbor_liab, brokered_dep, ln_cons, ln_cc, ln_ci, ln_oth, ln_fi, ln_re,
      npl_tot, ytdllprov, ytdnetinc, ytdint_exp_dep, ytdint_inc_ln,
      insured_deposits),
    ~ . * 1000
  )) %>%

  # final year
  mutate(
    final_year = as.integer(format(fail_day, "%Y")),

    # Age (replicating Stata's tostring -> date -> year)
    charter_date = as.Date(as.character(dt_open), format = "%Y%m%d"),
    charter_year = as.integer(format(charter_date, "%Y")),
    age = year - charter_year
  ) %>%

  # Keep only the variables from the Stata script
  select(
    bank_id, id_fdic_cert, year, quarter, quarter_number, dt_open,
    assets, liquid, failed_bank, equity, deposits, loans, state_abbrev,
    bank_name, final_year, time_to_fail, deposits_time, deposits_demand,
    otherbor_liab, brokered_dep, ln_cons, ln_cc, ln_ci, ln_oth, ln_fi,
    ln_re, npl_tot, ytdllprov, ytdnetinc, ytdint_exp_dep, ytdint_inc_ln,
    days_to_failure, quarters_to_failure, fail_day, call_date,
    insured_deposits, num_employees, resdep, resasset,
    charter_date, charter_year, age
  ) %>%

  # Drop id_fdic_cert (as in Stata)
  select(-id_fdic_cert) %>%

  # Order columns (optional, but good for comparison)
  arrange(bank_id, quarter)

# --------------------------------------------------------------------------
# Save Processed Modern Data
# --------------------------------------------------------------------------

message("Saving processed modern dataset...")

# Define save path (to $temp, matching Stata)
save_path_dta <- file.path(tempfiles_dir, "call-reports-modern.dta")

write_dta(
  final_data,
  save_path_dta
)

# Also save an RDS version to $temp
saveRDS(
  final_data,
  file.path(tempfiles_dir, "call-reports-modern.rds")
)

message("05_create_modern_dataset.R completed successfully")
message(sprintf("  - Observations: %d (Stata had 2,528,198)", nrow(final_data)))
message(sprintf("  - Banks (unique bank_id): %d", n_distinct(final_data$bank_id)))
message(sprintf("  - Saved to: %s", save_path_dta))
