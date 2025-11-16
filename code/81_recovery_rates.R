# ===========================================================================
# Script 81: Recovery Rates Analysis
# ===========================================================================
# This script analyzes recovery rates for depositors and asset recovery
# in failed banks. Creates summary tables by era.
#
# Key outputs:
# - Deposit recovery rates (dividends paid to depositors)
# - Asset quality at suspension (good/doubtful/worthless)
# - Asset collection rates
# - Summary tables by era
#
# v2.5 enhancements:
# - Verbose console diagnostics throughout
# - Detailed progress tracking
# ===========================================================================

cat("===========================================================================\n")
cat("SCRIPT 81: RECOVERY RATES ANALYSIS\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
script_start_time <- Sys.time()

# --- Load Required Libraries ---
cat("\n[Loading Libraries]\n")
suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(haven)
  library(ggplot2)
})
cat("  ✓ All libraries loaded successfully\n")

# --- Define Paths ---
tempfiles_dir <- here::here("tempfiles")
output_dir <- here::here("output")

# ===========================================================================
# PART 1: LOAD DATA
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 1: DATA LOADING\n")
cat("===========================================================================\n")

cat("\nLoading receivership_dataset_tmp.rds...\n")
data_recv <- readRDS(file.path(tempfiles_dir, "receivership_dataset_tmp.rds"))

cat(sprintf("  Loaded: %d observations\n", nrow(data_recv)))

# Filter to banks with charter info
data_recv <- data_recv %>%
  filter(!is.na(charter))

cat(sprintf("  After filtering: %d observations\n", nrow(data_recv)))

# ===========================================================================
# PART 2: CREATE ERA INDICATORS
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 2: CREATING ERA INDICATORS\n")
cat("===========================================================================\n")

data_recv <- data_recv %>%
  mutate(
    era = case_when(
      receivership_date >= as.Date("1863-01-01") & receivership_date < as.Date("1914-01-01") ~ 1,
      receivership_date >= as.Date("1914-01-01") & receivership_date <= as.Date("1928-12-31") ~ 2,
      receivership_date >= as.Date("1929-01-01") & receivership_date <= as.Date("1933-03-06") ~ 3,
      receivership_date >= as.Date("1933-02-01") & receivership_date <= as.Date("1935-01-01") ~ 4,
      final_year >= 1984 & final_year <= 2006 ~ 5,
      final_year >= 2007 & final_year <= 2015 ~ 6,
      TRUE ~ NA_real_
    ),
    era_label = factor(era,
      levels = 1:6,
      labels = c("1863-1913 (NB Era)", "1914-1918 (Early Fed)",
                 "1929-1933 (Depr., pre-Holiday)", "1933-1934 (Depr., post-Holiday)",
                 "1993-2006", "2007-2023")
    )
  )

cat("  ✓ Era indicators created\n")

# ===========================================================================
# PART 3: DEPOSIT RECOVERY RATES
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 3: DEPOSIT RECOVERY RATES\n")
cat("===========================================================================\n")

# Force dividends to be between 0 and 100%
data_recv <- data_recv %>%
  mutate(
    dividends = pmin(pmax(dividends, 0), 100),
    full_recov = dividends > 99.9,
    div_if_loss = ifelse(full_recov != 1, dividends, NA)
  )

cat(sprintf("  Full recovery rate: %.1f%%\n",
            mean(data_recv$full_recov, na.rm = TRUE) * 100))

# ===========================================================================
# PART 4: ASSET RECOVERY RATES
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 4: ASSET RECOVERY RATES\n")
cat("===========================================================================\n")

data_recv <- data_recv %>%
  mutate(
    share_good = assets_suspension_good / assets_at_suspension,
    share_doubtful = assets_suspension_doubtful / assets_at_suspension,
    share_worthless = assets_suspension_worthless / assets_at_suspension,
    share_additional = assets_suspension_additional /
      (assets_at_suspension + assets_suspension_additional),
    share_collected = collected_from_assets /
      (assets_at_suspension + assets_suspension_additional)
  )

cat(sprintf("  Mean share collected: %.1f%%\n",
            mean(data_recv$share_collected, na.rm = TRUE) * 100))

# Create collection rate categories
data_recv <- data_recv %>%
  mutate(
    share_cat1 = share_collected < 0.25,
    share_cat2 = share_collected >= 0.25 & share_collected < 0.5,
    share_cat3 = share_collected >= 0.5 & share_collected < 0.75,
    share_cat4 = share_collected >= 0.75 & share_collected < 0.95,
    share_cat5 = share_collected >= 0.95
  )

# ===========================================================================
# PART 5: SUMMARY TABLES BY ERA
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 5: CREATING SUMMARY TABLES\n")
cat("===========================================================================\n")

# Asset quality at suspension
cat("\n[Table 1: Assets in Failure - Assessed Quality]\n")

assets_assessed <- data_recv %>%
  filter(!is.na(era)) %>%
  group_by(era_label) %>%
  summarise(
    n_banks = n(),
    share_good = mean(share_good, na.rm = TRUE),
    share_doubtful = mean(share_doubtful, na.rm = TRUE),
    share_worthless = mean(share_worthless, na.rm = TRUE),
    .groups = "drop"
  )

print(assets_assessed)

saveRDS(assets_assessed, file.path(tempfiles_dir, "assets_in_failure_assessed.rds"))
write_dta(assets_assessed, file.path(tempfiles_dir, "assets_in_failure_assessed.dta"))

# Asset collection rates
cat("\n[Table 2: Assets in Failure - Collection Rates]\n")

assets_collected <- data_recv %>%
  filter(!is.na(era)) %>%
  group_by(era_label) %>%
  summarise(
    n_banks = n(),
    share_collected = mean(share_collected, na.rm = TRUE),
    share_cat1 = mean(share_cat1, na.rm = TRUE),
    share_cat2 = mean(share_cat2, na.rm = TRUE),
    share_cat3 = mean(share_cat3, na.rm = TRUE),
    share_cat4 = mean(share_cat4, na.rm = TRUE),
    share_cat5 = mean(share_cat5, na.rm = TRUE),
    .groups = "drop"
  )

print(assets_collected)

saveRDS(assets_collected, file.path(tempfiles_dir, "assets_in_failure_collected.rds"))
write_dta(assets_collected, file.path(tempfiles_dir, "assets_in_failure_collected.dta"))

# Depositor losses by era
cat("\n[Table 3: Depositor Losses by Era]\n")

depositor_losses <- data_recv %>%
  filter(!is.na(era)) %>%
  group_by(era_label) %>%
  summarise(
    n_banks = n(),
    loss_dummy = 1 - mean(full_recov, na.rm = TRUE),
    div_if_loss = 1 - mean(div_if_loss, na.rm = TRUE) / 100,
    dividends_uncond = 1 - mean(dividends, na.rm = TRUE) / 100,
    .groups = "drop"
  )

print(depositor_losses)

saveRDS(depositor_losses, file.path(tempfiles_dir, "depositor_losses.rds"))
write_dta(depositor_losses, file.path(tempfiles_dir, "depositor_losses.dta"))

cat("\n  ✓ All summary tables saved\n")

# ===========================================================================
# PART 6: FINAL SUMMARY
# ===========================================================================

cat("\n===========================================================================\n")
cat("FINAL SUMMARY\n")
cat("===========================================================================\n")

script_end_time <- Sys.time()
script_duration <- as.numeric(difftime(script_end_time, script_start_time, units = "mins"))

cat("\n[Key Statistics]\n")
cat(sprintf("  Total failed banks analyzed: %d\n", nrow(data_recv)))
cat(sprintf("  Mean recovery rate: %.1f%%\n", mean(data_recv$dividends, na.rm = TRUE)))
cat(sprintf("  Full recovery rate: %.1f%%\n",
            mean(data_recv$full_recov, na.rm = TRUE) * 100))

cat("\n===========================================================================\n")
cat("SCRIPT 81 COMPLETED SUCCESSFULLY\n")
cat(sprintf("  Runtime: %.1f minutes\n", script_duration))
cat("===========================================================================\n")
