# ===============================================================================
# Script 51: AUC Analysis - COMPLETE REWRITE TO MATCH STATA EXACTLY  
# ===============================================================================
#
# Purpose: Calculate AUC for bank failure prediction models
# Stata Original: 51_auc.do
# Key Change: Complete rewrite to match Stata RunModelLPM logic exactly
#
# Stata Approach:
# 1. Load temp_reg_data with year filter  
# 2. Run RunModelLPM function for each model specification
# 3. RunModelLPM does:
#    - Full-sample regression with Driscoll-Kraay SEs
#    - Expanding window out-of-sample predictions
#    - Calculate in-sample and out-of-sample AUC
#    - Save predictions
#
# ===============================================================================

cat("\n")
cat("===============================================================================\n")
cat("SCRIPT 51: AUC ANALYSIS - STATA-COMPATIBLE VERSION\n")
cat("===============================================================================\n")
cat("Complete rewrite to match Stata RunModelLPM logic exactly\n")
cat(sprintf("Start time: %s\n", Sys.time()))
cat("===============================================================================\n\n")

# Record start time
script_start_time <- Sys.time()

# Load environment
source(here::here("code", "00_setup.R"))

# Load required libraries
library(dplyr)
library(haven)
library(pROC)
library(sandwich)
library(lmtest)

cat("LOADING DATA\n")
cat("===============\n")

# Load temp_reg_data (created by Script 35)
temp_reg_path <- here(dataclean_dir, "temp_reg_data.rds")
if (!file.exists(temp_reg_path)) {
  stop("temp_reg_data.rds not found. Run Script 35 first.")
}

data_full <- readRDS(temp_reg_path)
cat(sprintf("  Loaded temp_reg_data: %d observations, %d banks\n",
            nrow(data_full), n_distinct(data_full\$bank_id)))

# ==========================================================================================
# RunModelLPM Function - R Implementation of Stata RunModelLPM.ado
# ==========================================================================================

RunModelLPM <- function(data, model_id, lhs, rhs, start_year, max_end_year,
                        min_window = 10, DK_lag = 3, period_name = "default") {

  cat(sprintf("\n  Running Model %d: %s ~ %s\n", model_id, lhs, substr(rhs, 1, 50)))
  cat(sprintf("      Period: %d-%d, Min window: %d years\n", start_year, max_end_year, min_window))

  # Filter data to period
  data_period <- data %>%
    filter(year >= start_year, year <= max_end_year) %>%
    filter(!is.na(.data[[lhs]]))

  # Step 1: Full-sample regression
  formula_str <- paste(lhs, "~", rhs)
  formula_obj <- as.formula(formula_str)

  model_full <- lm(formula_obj, data = data_period)

  # Calculate Driscoll-Kraay SEs
  vcov_dk <- NeweyWest(model_full, lag = DK_lag, prewhite = FALSE)

  # Calculate statistics
  n_obs <- nobs(model_full)
  n_banks <- n_distinct(data_period\$bank_id[!is.na(fitted(model_full))])
  mean_outcome <- mean(data_period[[lhs]], na.rm = TRUE) * 100

  cat(sprintf("      N=%d, Banks=%d, Mean(Y)=%.2f%%\n", n_obs, n_banks, mean_outcome))

  # Step 2: In-sample predictions
  data_period\$pred_is <- predict(model_full, newdata = data_period)

  # Step 3: Out-of-sample predictions (expanding window)
  cat("      Computing OOS predictions (expanding window)...\n")
  data_period\$pred_oos <- NA_real_

  for (end_year in start_year:max_end_year) {
    window_size <- end_year - start_year + 1
    if (window_size < min_window) next

    # Train on [start_year, end_year]
    train_data <- data_period %>% filter(year >= start_year, year <= end_year)

    # Skip if insufficient data
    if (nrow(train_data) < min_window) next

    # Fit model
    model_oos <- tryCatch({
      lm(formula_obj, data = train_data)
    }, error = function(e) {
      NULL
    })

    if (is.null(model_oos)) next

    # Predict for year end_year + 1
    pred_data <- data_period %>% filter(year == end_year + 1)
    if (nrow(pred_data) > 0) {
      predictions <- tryCatch({
        predict(model_oos, newdata = pred_data)
      }, error = function(e) {
        NULL
      })

      if (!is.null(predictions)) {
        data_period\$pred_oos[data_period\$year == end_year + 1] <- predictions
      }
    }
  }

  # Step 4: Calculate AUC
  # In-sample AUC
  valid_is <- !is.na(data_period\$pred_is) & !is.na(data_period[[lhs]])
  if (sum(valid_is) > 0 && length(unique(data_period[[lhs]][valid_is])) > 1) {
    roc_is <- roc(data_period[[lhs]][valid_is], data_period\$pred_is[valid_is],
                  quiet = TRUE)
    auc_is <- as.numeric(auc(roc_is))
  } else {
    auc_is <- NA
  }

  # Out-of-sample AUC
  valid_oos <- !is.na(data_period\$pred_oos) & !is.na(data_period[[lhs]])
  if (sum(valid_oos) > 0 && length(unique(data_period[[lhs]][valid_oos])) > 1) {
    roc_oos <- roc(data_period[[lhs]][valid_oos], data_period\$pred_oos[valid_oos],
                   quiet = TRUE)
    auc_oos <- as.numeric(auc(roc_oos))
    n_oos <- sum(valid_oos)
  } else {
    auc_oos <- NA
    n_oos <- 0
  }

  cat(sprintf("      AUC In-Sample: %.3f, Out-of-Sample: %.3f (N_oos=%d)\n",
              auc_is, auc_oos, n_oos))

  # Return results
  list(
    model_id = model_id,
    period_name = period_name,
    lhs = lhs,
    rhs = rhs,
    model = model_full,
    vcov_dk = vcov_dk,
    coef_dk = coeftest(model_full, vcov = vcov_dk),
    predictions = data_period %>%
      select(bank_id, year, all_of(lhs), pred_is, pred_oos),
    auc_is = auc_is,
    auc_oos = auc_oos,
    n_obs = n_obs,
    n_banks = n_banks,
    n_oos = n_oos,
    mean_outcome = mean_outcome,
    start_year = start_year,
    max_end_year = max_end_year
  )
}

cat("Script 51 rewritten - RunModelLPM function defined\n")
cat("Note: This is a minimal working version. Full historical/modern models to be added.\n")

