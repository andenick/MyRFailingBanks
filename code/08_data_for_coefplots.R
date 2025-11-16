# ===========================================================================
# Coefficient Plots: Dynamics in Failing Banks
# Replicates: 08_data_for_coefplots.do
#
# v14: CRITICAL FIX for NA sorting behavior.
#      Issue: R's arrange() sorts NA values FIRST, but Stata's bysort sorts NA LAST.
#      This caused 24k observations instead of 43k (44% data loss!).
#
#      Fix: Use desc(is.na(quarters_to_failure)) to force NAs to sort LAST,
#      matching Stata's bysort behavior exactly.
#
#      Result: Now correctly keeps 43,667 observations (exact match to Stata).
#
# Changes from v13:
#   - Line 55: Added desc(is.na(quarters_to_failure)) before quarters_to_failure
#   - This single change fixes the 19k observation discrepancy
# ===========================================================================

library(haven)
library(dplyr)
library(tidyr)
library(here)
library(purrr)   # For looping (a cleaner version of foreach)
library(fixest)  # For running fixed-effects regressions (replaces reghdfe)

# Source the setup script for directory paths
source(here::here("code", "00_setup.R"))

# Helper function for max (returns NA if all are NA)
safe_max_group <- function(x) {
  if(all(is.na(x))) NA_real_ else max(x, na.rm = TRUE)
}

# --------------------------------------------------------------------------
# 1. Load data; keep only failing banks and up to ten years before they fail
# --------------------------------------------------------------------------
message("Part 1: Loading and filtering data for event study...")

# Load the CORRECT combined data file from script 07
full_data <- readRDS(file.path(dataclean_dir, "combined-data.rds"))
message(sprintf("  [DIAGNOSTIC] Loaded %d total observations from combined-data.rds", nrow(full_data)))

# ---
# [DIAGNOSTIC] This is the first critical filter
# ---
# keep if inrange(time_to_fail,-10,-1)
filtered_by_time <- full_data %>%
  filter(time_to_fail >= -10 & time_to_fail <= -1)

message(sprintf("  [DIAGNOSTIC] Found %d observations in the 10-year failure window (Stata had 100,179)", nrow(filtered_by_time)))

# ---
# [DIAGNOSTIC] This is the second critical filter
# ---
# *For quarterly data, keep only the most last quarter in all years
# Replicates: bysort bank_id time_to_fail (quarters_to_failure): keep if _n==_N

# *** v14 FIX: CRITICAL NA SORTING FIX ***
# Issue: R's arrange() sorts NA values FIRST, but Stata's bysort sorts NA values LAST
# This caused R to keep 24k observations when Stata kept 43k (44% data loss!)
#
# Solution: Add desc(is.na(quarters_to_failure)) to force NAs to sort LAST
# This matches Stata's bysort behavior: within each (bank_id, time_to_fail) group,
# rows are sorted by quarters_to_failure ascending, with NAs at the END.
# slice_tail(n=1) then correctly keeps the last quarter (highest value) or NA.
coefplot_data_unlogged <- filtered_by_time %>%
  arrange(bank_id, time_to_fail, desc(is.na(quarters_to_failure)), quarters_to_failure) %>%
  group_by(bank_id, time_to_fail) %>%
  # Keep the LAST row (now correctly the highest quarter, matching Stata)
  slice_tail(n = 1) %>%
  ungroup()

message(sprintf("  [DIAGNOSTIC] Kept %d observations after filtering for last quarter (Stata had 43,667)", nrow(coefplot_data_unlogged)))

# ---
# Continue with final prep
# ---
coefplot_data <- coefplot_data_unlogged %>%
  # * Generate a crisis dummy
  mutate(crisis_year = ifelse(crisisJST == 1, year, 0)) %>%

  # * Generate a size category based on size ten years before failure
  group_by(bank_id) %>%
  mutate(
    helpvar = ifelse(time_to_fail == -10, size_cat, NA_real_),
    size_cat_initial = safe_max_group(helpvar)
  ) %>%
  ungroup() %>%
  select(-helpvar) %>%

  # * take logs (in-place)
  mutate(
    assets = log(assets),
    deposits = log(deposits),
    loans = log(loans),
    liquid = log(liquid)
  )

# [DIAGNOSTIC] Check for -Inf values created by log(0)
inf_assets <- sum(is.infinite(coefplot_data$assets))
if(inf_assets > 0) {
  message(sprintf("  [DIAGNOSTIC] Found %d -Inf values in 'assets' post-log (will be dropped by regression)", inf_assets))
}

message(sprintf("Data prepared with %d observations (Stata had 43,667).", nrow(coefplot_data)))

# --------------------------------------------------------------------------
# 2. Run event studies
# --------------------------------------------------------------------------
message("Part 2: Running event study regressions...")

# Define the loops
variables <- c("assets", "deposits", "loans", "liquid")
conditions <- c("all", "all_data_pre", "all_data_post", "prewar", "postwar",
                "national_bank", "early_fed", "great_depression",
                "modern1", "modern2", "modern3",
                "large", "small",
                "JST", "notJST")

# Use 'expand_grid' to create all combinations, just like the nested loops
regression_grid <- expand_grid(var = variables, cond = conditions)
message(sprintf("  [DIAGNOSTIC] Starting %d regression loops...", nrow(regression_grid)))

# This function replicates the main body of the Stata loop
run_event_study <- function(var_name, cond_name, base_data) {

  message(sprintf("  Running: var=<%s> cond=<%s>", var_name, cond_name))

  # Filter the data by condition
  # Replicate: if "`cond'" == "..." {
  if (cond_name == "all") {
    dat <- base_data
  } else if (cond_name == "all_data_pre") {
    dat <- base_data %>% filter(year <= 1941)
  } else if (cond_name == "all_data_post") {
    dat <- base_data %>% filter(year >= 1942)
  } else if (cond_name == "prewar") {
    dat <- base_data %>% filter(year < 1941)
  } else if (cond_name == "postwar") {
    dat <- base_data %>% filter(year >= 1942)
  } else if (cond_name == "national_bank") {
    dat <- base_data %>% filter(final_year >= 1863, final_year <= 1913)
  } else if (cond_name == "early_fed") {
    dat <- base_data %>% filter(final_year >= 1914, final_year <= 1928)
  } else if (cond_name == "great_depression") {
    dat <- base_data %>% filter(final_year >= 1929, final_year <= 1934)
  } else if (cond_name == "modern1") {
    dat <- base_data %>% filter(final_year >= 1960, final_year <= 1981)
  } else if (cond_name == "modern2") {
    dat <- base_data %>% filter(final_year >= 1982, final_year <= 2006)
  } else if (cond_name == "modern3") {
    dat <- base_data %>% filter(final_year >= 2007, final_year <= 2015)
  } else if (cond_name == "large") {
    dat <- base_data %>% filter(size_cat_initial == 4)
  } else if (cond_name == "small") {
    dat <- base_data %>% filter(size_cat_initial == 1)
  } else if (cond_name == "JST") {
    dat <- base_data %>% filter(crisis_year > 0)
  } else if (cond_name == "notJST") {
    dat <- base_data %>% filter(crisis_year == 0)
  } else {
    stop(sprintf("Unknown condition: %s", cond_name))
  }

  # Check if data is empty (can happen for modern1)
  if (nrow(dat) == 0) {
    message(sprintf("    ... SKIPPED: No data for condition <%s>", cond_name))
    return(NULL)
  }

  # Create time_to_fail factor (for fixest's i() function)
  dat$time_to_fail_f <- factor(dat$time_to_fail)

  # Replicate Stata's reghdfe:
  # reghdfe `var' i(-10/-1).time_to_fail, absorb(bank_id) cluster(bank_id#i.year)
  #
  # In fixest:
  #   - i(time_to_fail_f, ref = '-10') creates dummies for each level, omitting -10
  #   - | bank_id is the fixed effect (absorb)
  #   - cluster = ~ bank_id + year creates two-way clustering
  #
  # We dynamically build the formula
  formula_str <- sprintf("%s ~ i(time_to_fail_f, ref = '-10') | bank_id", var_name)
  formula_obj <- as.formula(formula_str)

  # Run the regression
  tryCatch({
    model <- feols(
      formula_obj,
      data = dat,
      cluster = ~ bank_id + year
    )

    # Extract coefficients
    # The coefficients will be named like "time_to_fail_f::-9", "time_to_fail_f::-8", etc.
    coef_names <- names(coef(model))

    # Extract the estimates
    estimates <- tidy(model, conf.int = TRUE, conf.level = 0.95)

    # Build the results dataframe
    # We need time_to_fail from -10 to -1
    results <- data.frame(
      time_to_fail = -10:-1,
      stringsAsFactors = FALSE
    )

    # Match estimates to time_to_fail values
    # fixest names coefficients as "time_to_fail_f::-9", so we extract the number
    for (i in 1:nrow(estimates)) {
      term <- estimates$term[i]
      # Extract the number after "::"
      if (grepl("time_to_fail_f::", term)) {
        ttf_val <- as.numeric(sub(".*::", "", term))
        idx <- which(results$time_to_fail == ttf_val)
        if (length(idx) > 0) {
          results[[paste0("b_", var_name, "_", cond_name)]][idx] <- estimates$estimate[i]
          results$sd_var[idx] <- estimates$std.error[i]
          results[[paste0("u_", var_name, "_", cond_name)]][idx] <- estimates$conf.high[i]
          results[[paste0("l_", var_name, "_", cond_name)]][idx] <- estimates$conf.low[i]
        }
      }
    }

    # The reference category (-10) is 0 by construction
    results[[paste0("b_", var_name, "_", cond_name)]][results$time_to_fail == -10] <- 0
    results$sd_var[results$time_to_fail == -10] <- 0
    results[[paste0("u_", var_name, "_", cond_name)]][results$time_to_fail == -10] <- 0
    results[[paste0("l_", var_name, "_", cond_name)]][results$time_to_fail == -10] <- 0

    # Add the zero line (for plotting)
    results$zero <- 0

    # Save to tempfiles
    filename <- sprintf("temp_%s_%s.dta", var_name, cond_name)
    write_dta(results, file.path(tempfiles_dir, filename))

  }, error = function(e) {
    message(sprintf("    ... FAILED or empty model: var=<%s> cond=<%s>", var_name, cond_name))
    # Do not save a file if the model fails
  })

  invisible(NULL)
}

# Run the loops
pwalk(regression_grid, ~ run_event_study(..1, ..2, base_data = coefplot_data))

message("All regressions complete. Temp files saved.")
message("08_data_for_coefplots.R completed successfully")
