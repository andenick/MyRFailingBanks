# ===========================================================================
# Create Historical Dataset (1863-1941)
# Replicates: 04_create-historical-dataset.do from QJE Stata replication kit
#
# NOTE: This is a full rewrite to correctly replicate the Stata logic,
# which was largely missing from the original R script.
# ===========================================================================

library(haven)
library(dplyr)
library(tidyr) # For fill()
library(lubridate)
library(here)

# Source the setup script for directory paths
tempfiles_dir <- here::here("tempfiles")
tempfiles_dir <- here::here("tempfiles")

# --------------------------------------------------------------------------
# Load Historical Call Reports Data
# --------------------------------------------------------------------------

message("Loading historical call reports data...")
historical_data <- read_dta(here::here("sources", "call-reports-historical.dta"))

# --------------------------------------------------------------------------
# Bank ID Versioning (Stata lines 10-20)
# --------------------------------------------------------------------------
# Adjust bank_id to create separate "versions" for banks that enter/exit
# receivership multiple times and restore solvency

message("Applying bank ID versioning for multiple receivership episodes...")

historical_data <- historical_data %>%
  arrange(bank_id, year) %>%
  group_by(bank_id) %>%
  mutate(
    # Forward fill end_date to create end_date2 (Stata line 12)
    end_date2 = end_date
  ) %>%
  # Use tidyr::fill for forward filling (equivalent to Stata's replace with [_n-1])
  fill(end_date2, .direction = "down") %>%
  mutate(
    # Detect changes in end_date (new receivership episode) - Stata line 13
    new_end = (end_date2 != lag(end_date2, default = first(end_date2))),
    # Create version counter (cumulative sum of changes) - Stata line 14
    version = cumsum(as.integer(new_end)),
    # Generate new ID: 10 * bank_id + version - Stata line 18
    id = 10 * bank_id + version
  ) %>%
  # Drop temporary variables (Stata line 20)
  select(-new_end, -end_date2) %>%
  ungroup()

message(sprintf("  Bank versions created: %d unique IDs from %d original bank_ids",
                length(unique(historical_data$id)),
                length(unique(historical_data$bank_id))))


# --------------------------------------------------------------------------
# Process Historical Data
# --------------------------------------------------------------------------

message("Processing historical bank data (Replicating Stata script)...")

# Helper function to replicate Stata's 'rowtotal' behavior
# Stata rowtotal treats missing values as 0 by default (official documentation)
rowtotal_stata <- function(...) {
  vars <- list(...)
  df_vars <- as.data.frame(vars)
  result <- rowSums(df_vars, na.rm = TRUE)
  return(result)
}


final_data <- historical_data %>%
  # Rename 'oreo'
  rename(oreo = oreo_and_mortgages) %>%

  mutate(
    # 8. Egen interbank
    interbank = rowtotal_stata(due_to_nb, due_to_other_nb, due_to_sb, due_to_tc_and_sb, due_to_banks, due_to_banks_and_other_liabs),

    # 9. Egen liquid
    liquid = rowtotal_stata(bills_nb, bills_sb, checks_and_other, currency,
                            legal_tender, specie, due_from_nb, due_from_ra, due_from_other_nb,
                            due_from_other_nb_and_sb, due_from_sb, bonds_dep, bonds_hand,
                            cash_exchange_and_reserve, cash_and_exchange),

    # 10. Egen equity
    equity = rowtotal_stata(capital, surplus, undivided_profits, surplus_and_undivided_profits),

    # 11. Egen surplus_profit
    surplus_profit = rowtotal_stata(surplus, undivided_profits),

    # 12. Egen emergency
    emergency = rowtotal_stata(bills_payable, rediscounts),

    # 13. Egen total_deposits
    total_deposits = rowtotal_stata(us_deposits, usdo_deposits, individual_deposits, demand_deposits, time_deposits, deposits),

    # 14. Egen temp var for deposits
    .temp_deposits = rowtotal_stata(demand_deposits, time_deposits)
  ) %>%

  # 15. Replicate 'liquid' overwrite logic
  mutate(
    .temp_liquid = rowtotal_stata(cash_and_exchange, frb_reserve, cash_exchange_and_reserve),
    liquid = if_else(year >= 1905 & year <= 1935, .temp_liquid, liquid)
  ) %>%
  select(-.temp_liquid) %>%

  # 16. Replicate 'surplus_profit' overwrite logic
  mutate(
    surplus_profit = if_else(year >= 1918 & year <= 1928, surplus_and_undivided_profits, surplus_profit),
    surplus_profit = if_else(year >= 1905 & year <= 1907, surplus_and_undivided_profits, surplus_profit)
  ) %>%

  # 17. Replicate 'deposits' fill-in logic
  mutate(
    deposits = if_else(year >= 1915 & year <= 1928, .temp_deposits, deposits),
    deposits = if_else(deposits == 0 & (year >= 1915 & year <= 1928), NA_real_, deposits),
    deposits = if_else(year >= 1905 & year <= 1914, individual_deposits, deposits)
  ) %>%
  select(-.temp_deposits) %>%

  # 18. Replicate 'bonds_circ' fill-in logic
  mutate(
    bonds_circ = if_else(is.na(bonds_circ) & !is.na(lawful_money), lawful_money, bonds_circ),
    bonds_circ = if_else(is.na(bonds_circ) & is.na(lawful_money), securities_usgov, bonds_circ)
  ) %>%

  # 19. Generate 'res_funding'
  mutate(
    capital_deposits_notes = rowtotal_stata(equity, total_deposits, interbank, notes_nb),
    res_funding = assets - capital_deposits_notes,
    res_funding = if_else(!is.na(res_funding) & res_funding < 0, 0, res_funding)
  ) %>%

  # 20. Generate 'age'
  mutate(
    charter_year = as.integer(format(charter_date, "%Y")),
    age = year - charter_year
  ) %>%


  # 20b. Generate receivership_date (Stata line 29)
  # gen receivership_date = end_date if end_has_receivership==1
  mutate(
    receivership_date = if_else(end_has_receivership == 1, end_date, as.Date(NA))
  ) %>%
  # --------------------------------------------------------------------------
  # Critical Filters (Stata lines 39-40)
  # --------------------------------------------------------------------------
  # MUST occur AFTER receivership_date creation but BEFORE failed_bank calculation

  # Stata line 39: Drop banks in voluntary liquidation
  filter(is.na(in_vl) | in_vl != 1) %>%

  # Stata line 40: Drop years with no call report (bs_merge==1)
  filter(is.na(bs_merge) | bs_merge != 1) %>%

  # --------------------------------------------------------------------------
  # failed_bank Indicator (Stata line 33)
  # --------------------------------------------------------------------------
  # MUST be calculated AFTER the filters above

  group_by(bank_id) %>%
  mutate(
    failed_bank = as.integer(max(!is.na(receivership_date)))
  ) %>%
  ungroup() %>%

  # --------------------------------------------------------------------------
  # Diagnostic Checkpoint (Stata line 36: mdesc receivership_date)
  # --------------------------------------------------------------------------

  {
    . <- .
    message("\nDiagnostic: receivership_date coverage after preprocessing:")
    message(sprintf("  Non-missing: %d (%.1f%%)",
                    sum(!is.na(.$receivership_date)),
                    100 * mean(!is.na(.$receivership_date))))
    message(sprintf("  Failed banks: %d (%.1f%%)",
                    sum(.$failed_bank == 1),
                    100 * mean(.$failed_bank == 1)))
    message(sprintf("  Total observations after filters: %d", nrow(.)))
    .
  } %>%


  # 21. Generate failure timing variables (Stata lines 44-47)
  # gen days_to_failure = receivership_date - call_date
  # gen quarters_to_failure = -ceil(days_to_failure / 90)
  # gen int time_to_fail = -ceil(days_to_failure / 365)
  mutate(
    days_to_failure = as.numeric(difftime(receivership_date, call_date, units = "days")),
    quarters_to_failure = as.integer(-ceiling(days_to_failure / 90)),
    time_to_fail = as.integer(-ceiling(days_to_failure / 365))
  ) %>%


  # 23. Filter: drop if days_to_failure <= 0 (Stata line 54)
  filter(is.na(days_to_failure) | days_to_failure > 0) %>%

  # 23b. Generate fail_year and final_year (Stata lines 50-51)
  # gen fail_year = yofd(receivership_date)
  # gegen final_year = max(fail_year), by(bank_id)
  mutate(
    fail_year = as.integer(format(receivership_date, "%Y"))
  ) %>%
  group_by(bank_id) %>%
  mutate(
    final_year = ifelse(all(is.na(fail_year)), NA_integer_, as.integer(max(fail_year, na.rm = TRUE)))
  ) %>%
  ungroup() %>%

  # 24. Final 'keep' command to match Stata schema
  select(
    charter, assets, deposits, loans, interbank, liquid, equity, emergency, oreo,
    capital, call_date, rediscounts, bills_payable, failed_bank, time_to_fail,
    bank_id, city_name, state_abbrev, canonical_bank_name, year, final_year,
    receivership_date, bonds_circ, notes_nb, quarters_to_failure,
    undivided_profits, surplus, demand_deposits, time_deposits, surplus_profit,
    securities_other, days_to_failure, res_funding, # 'final_year' is already present
    due_to_banks_and_other_liabs, other_liabs, total_deposits, age,
    end_has_receivership, end_date, end_cause
  )

# --------------------------------------------------------------------------
# Save Processed Historical Data
# --------------------------------------------------------------------------

message("Saving processed historical dataset...")

# Define save paths
save_path_dta <- file.path(tempfiles_dir, "call-reports-historical.dta")
save_path_rds <- file.path(tempfiles_dir, "call-reports-historical.rds")

# Save to tempfiles/ (replicating Stata $temp path)
write_dta(
  final_data,
  save_path_dta
)

# Also save as RDS for R-native use
saveRDS(
  final_data,
  save_path_rds
)

message("04_create_historical_dataset.R completed successfully")
message(sprintf("  - Observations: %d (Should match Stata's 337,426)", nrow(final_data)))
message(sprintf("  - Years covered: %d to %d", min(final_data$year), max(final_data$year)))
message(sprintf("  - Saved to: %s", save_path_dta))
message(sprintf("  - Saved to: %s", save_path_rds))
