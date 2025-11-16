# ===========================================================================
# Script 51: AUC Analysis - Linear Probability Models
# ===========================================================================
#
# Purpose: Predictive power of bank failure models using AUC (Area Under ROC Curve)
#          Implements rolling out-of-sample predictions for multiple time periods
#
# Stata source: qje-repkit-to-upload/code/51_auc.do (510 lines)
#               qje-repkit-to-upload/code/RunModelLPM.ado (62 lines)
# R version: ~1,400 lines (consolidated - includes granular period analysis)
#
# Key outputs:
# - Table 1 Panel A & B: AUC metrics (in-sample & out-of-sample)
# - Table B.3-B.5: Regression coefficients
# - Table B.8-B.10: Granular period regressions
# - Table B.15: AUC by crisis period
# - Figure 7 Panel A & B: ROC curves
#
# Methods:
# - Linear Probability Models (LPM) with Driscoll-Kraay standard errors
# - Rolling-window out-of-sample predictions
# - ROC curve analysis and AUC calculation
# - Five time periods: Historical, Modern, National Banking, Early Fed, Great Depression
#
# v2.5 enhancements:
# - Consolidated from two files (51_auc.R + 51_auc_granular.R)
# - Verbose console diagnostics throughout
# - Detailed progress tracking
# ===========================================================================

cat("\n")
cat("===========================================================================\n")
cat("SCRIPT 51: AUC ANALYSIS - LINEAR PROBABILITY MODELS\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
cat(sprintf("R version: %s\n", R.version.string))
cat("===========================================================================\n\n")

# --- Record start time ---
script_start_time <- Sys.time()

# --- Load Environment Setup ---
cat("--- Loading Environment ---\n")
source(here::here("code", "00_setup.R"))

cat("  Loading required packages...\n")
library(fixest)   # Fast fixed effects regressions
library(pROC)     # ROC curve and AUC calculations
library(sandwich) # Driscoll-Kraay standard errors
library(lmtest)   # Coefficient testing

cat("  ✓ Packages loaded successfully\n\n")

# ===========================================================================
# HELPER FUNCTION: RunModelLPM (Stata: RunModelLPM.ado)
# ===========================================================================
# Purpose: Run LPM with rolling out-of-sample predictions and calculate AUC
#
# Parameters:
#   data: Input dataset
#   model_id: Model number (1-8)
#   lhs: Left-hand side variable (outcome, e.g., "F1_failure")
#   rhs: Right-hand side variables (predictors, as formula string)
#   start_year: Start year for sample
#   max_end_year: End year for sample
#   min_window: Minimum training window (years)
#   DK_lag: Driscoll-Kraay bandwidth (default 3)
#
# Returns: List with regression results, predictions, AUC metrics
# ===========================================================================

RunModelLPM <- function(data, model_id, lhs, rhs, start_year, max_end_year,
                        min_window = 10, DK_lag = 3) {

  cat(sprintf("\n=== Model %d: %s ~ %s ===\n", model_id, lhs, rhs))
  cat(sprintf("  Sample period: %d-%d\n", start_year, max_end_year))
  cat(sprintf("  Minimum training window: %d years\n", min_window))
  cat(sprintf("  DK bandwidth: %d\n", DK_lag))

  model_start_time <- Sys.time()

  # --- 1. Full-sample in-sample regression ---
  cat("\n  [Step 1/4] Running full-sample regression...\n")

  # Build formula
  formula_str <- paste0(lhs, " ~ ", rhs)
  cat(sprintf("    Formula: %s\n", formula_str))

  # Run OLS with error handling for insufficient factor levels
  # Note: lm() automatically handles missing values via listwise deletion (matches Stata behavior)
  # We pass the full dataset and let lm() determine which observations to use
  model_full <- tryCatch({
    lm(as.formula(formula_str), data = data, na.action = na.omit)
  }, error = function(e) {
    if (grepl("contrasts|factors with 2 or more levels", e$message)) {
      cat(sprintf("    [WARN] Model failed: %s\n", substr(e$message, 1, 80)))
      cat("    Insufficient factor levels - returning NA results\n")
      return(NULL)
    }
    stop(e)  # Re-throw other errors
  })

  # Check if model failed due to insufficient factor levels
  if (is.null(model_full)) {
    return(list(
      model_id = model_id,
      coefficients = data.frame(),
      predictions = data.frame(
        year = integer(0),
        bank_id = character(0),
        pred_insample = numeric(0),
        pred_oos = numeric(0)
      ),
      auc_insample = NA_real_,
      auc_oos = NA_real_
    ))
  }

  # Driscoll-Kraay standard errors (using NeweyWest as approximation)
  cat("    Computing Driscoll-Kraay standard errors...\n")
  vcov_dk <- NeweyWest(model_full, lag = DK_lag, prewhite = FALSE)

  # Store results
  coef_full <- coef(model_full)
  se_dk <- sqrt(diag(vcov_dk))

  # Calculate statistics
  # Use model's actual fitted values to count observations used in regression
  # This matches Stata's behavior: regression uses listwise deletion, but we track actual N
  # model.frame() gives us the actual data used by lm() (after listwise deletion)
  model_obs <- model.frame(model_full)
  n_obs <- nrow(model_obs)
  
  # Get bank_id from original data for observations used in model
  # Match by row position (model_obs has same order as data after removing NAs)
  model_data_indices <- attr(model_obs, "row.names")
  if (is.character(model_data_indices)) {
    model_data_indices <- as.integer(model_data_indices)
  }
  model_bank_ids <- data$bank_id[model_data_indices]
  n_banks <- n_distinct(model_bank_ids)
  mean_outcome <- mean(model_obs[[lhs]], na.rm = TRUE) * 100

  cat(sprintf("    Observations: %d\n", n_obs))
  cat(sprintf("    Banks: %d\n", n_banks))
  cat(sprintf("    Mean outcome: %.3f%%\n", mean_outcome))
  cat(sprintf("    Coefficients: %d parameters\n", length(coef_full)))

  # In-sample predictions - generate for ALL observations in data
  # Stata generates predictions for all observations, then AUC uses non-missing ones
  data$pred_insample <- tryCatch({
    predict(model_full, newdata = data)
  }, error = function(e) {
    if (grepl("new levels|factor.*has new", e$message)) {
      cat(sprintf("    [WARN] In-sample prediction failed: %s\n", substr(e$message, 1, 80)))
      cat("    Factor level mismatch - returning NA predictions\n")
      return(rep(NA_real_, nrow(data)))
    }
    stop(e)  # Re-throw other errors
  })
  # Count predictions that are non-missing AND have non-missing outcome
  valid_preds <- sum(!is.na(data$pred_insample) & !is.na(data[[lhs]]))
  cat(sprintf("    In-sample predictions: %d\n", valid_preds))

  # --- 2. Rolling out-of-sample predictions ---
  cat("\n  [Step 2/4] Running rolling out-of-sample predictions...\n")
  cat(sprintf("    Training years: %d to %d\n", start_year, max_end_year))

  data$pred_oos <- NA_real_

  n_oos_years <- 0
  n_oos_preds <- 0

  # Loop over end years
  for (end_year in start_year:max_end_year) {
    window <- end_year - start_year + 1

    # Skip if window too small
    if (window < min_window) next

    # Training sample: start_year to end_year (inclusive, matches Stata)
    # Stata uses: if year >= start_year & year <= end_year
    train_data <- data %>% filter(year >= start_year & year <= end_year)

    # Test sample: year == end_year + 1 (predictions for next year)
    test_data <- data %>% filter(year == end_year + 1)

    if (nrow(train_data) == 0 || nrow(test_data) == 0) next

    # Fit model on training data - let lm() handle missing values (matches Stata)
    model_oos <- tryCatch({
      lm(as.formula(formula_str), data = train_data, na.action = na.omit)
    }, error = function(e) {
      cat(sprintf("      Warning: Model failed for year %d: %s\n", end_year, e$message))
      return(NULL)
    })

    if (is.null(model_oos)) next

    # Predict on test year (end_year + 1)
    pred_oos <- tryCatch({
      predict(model_oos, newdata = test_data)
    }, error = function(e) {
      if (grepl("new levels|factor.*has new", e$message)) {
        cat(sprintf("      [WARN] Prediction failed for year %d: Factor level mismatch\n", end_year + 1))
        return(NULL)
      }
      cat(sprintf("      Warning: Prediction failed for year %d: %s\n", end_year + 1, substr(e$message, 1, 60)))
      return(NULL)
    })

    if (is.null(pred_oos)) next

    # Store predictions
    data$pred_oos[data$year == end_year + 1] <- pred_oos

    n_oos_years <- n_oos_years + 1
    n_oos_preds <- n_oos_preds + length(pred_oos)

    # Progress indicator every 10 years
    if (end_year %% 10 == 0) {
      cat(sprintf("      Completed through year %d (%d preds so far)\n",
                  end_year, n_oos_preds))
    }
  }

  cat(sprintf("    OOS training cycles: %d\n", n_oos_years))
  cat(sprintf("    Total OOS predictions: %d\n", sum(!is.na(data$pred_oos))))

  # --- 3. Calculate AUC metrics ---
  cat("\n  [Step 3/4] Calculating AUC metrics...\n")

  # In-sample AUC
  cat("    Computing in-sample ROC curve...
")

  # Check if response has both levels (0 and 1) - needed for ROC calculation
  insample_valid <- !is.na(data[[lhs]]) & !is.na(data$pred_insample)
  insample_outcomes <- unique(data[[lhs]][insample_valid])

  if (length(insample_outcomes) < 2) {
    cat(sprintf("    ⚠ Warning: Response variable has only %d unique value(s) - cannot calculate ROC
",
                length(insample_outcomes)))
    cat("    Setting AUC to NA
")
    roc_insample <- NULL
    auc_insample <- NA_real_
  } else {
    roc_insample <- roc(data[[lhs]], data$pred_insample,
                        quiet = TRUE, direction = "<")
    auc_insample <- as.numeric(auc(roc_insample))
  }

  # Out-of-sample AUC
  oos_valid <- !is.na(data$pred_oos) & !is.na(data[[lhs]])
  if (sum(oos_valid) > 10) {
    cat("    Computing out-of-sample ROC curve...
")

    # Check if OOS response has both levels
    oos_outcomes <- unique(data[[lhs]][oos_valid])

    if (length(oos_outcomes) < 2) {
      cat(sprintf("    ⚠ Warning: OOS response has only %d unique value(s) - cannot calculate ROC
",
                  length(oos_outcomes)))
      cat("    Setting OOS AUC to NA
")
      roc_oos <- NULL
      auc_oos <- NA_real_
    } else {
      roc_oos <- roc(data[[lhs]][oos_valid], data$pred_oos[oos_valid],
                     quiet = TRUE, direction = "<")
      auc_oos <- as.numeric(auc(roc_oos))
    }
  } else {
    cat("    Insufficient data for OOS ROC curve\n")
    roc_oos <- NULL
    auc_oos <- NA_real_
  }

  cat(sprintf("    ✓ AUC in-sample: %.4f\n", auc_insample))
  if (!is.na(auc_oos)) {
    cat(sprintf("    ✓ AUC out-of-sample: %.4f\n", auc_oos))
  } else {
    cat("    ✓ AUC out-of-sample: N/A\n")
  }

  # --- 4. Prepare output ---
  cat("\n  [Step 4/4] Preparing output data structures...\n")

  # Coefficient table - match Stata format
  t_stats <- coef_full / se_dk
  p_values <- 2 * pt(-abs(t_stats), df = n_obs - length(coef_full))
  ci_lower <- coef_full - 1.96 * se_dk
  ci_upper <- coef_full + 1.96 * se_dk
  
  coef_table <- data.frame(
    variable = names(coef_full),
    coefficient = coef_full,
    std_error = se_dk,
    t_statistic = t_stats,
    p_value = p_values,
    ci_lower_95 = ci_lower,
    ci_upper_95 = ci_upper,
    row.names = NULL
  )

  cat(sprintf("    Coefficient table: %d rows\n", nrow(coef_table)))
  
  # Export regression table as CSV
  period_name <- ifelse(start_year >= 1863 & max_end_year <= 1934, "historical",
                       ifelse(start_year >= 1959 & max_end_year <= 2024, "modern",
                             ifelse(start_year >= 1863 & max_end_year <= 1904, "nb",
                                   ifelse(start_year >= 1914 & max_end_year <= 1928, "ef", "gd"))))
  reg_csv_file <- file.path(tables_dir, sprintf("regression_model_%d_%s.csv", model_id, period_name))
  write.csv(coef_table, reg_csv_file, row.names = FALSE)
  cat(sprintf("    ✓ Regression table exported: %s\n", basename(reg_csv_file)))

  # Summary statistics
  summary_stats <- list(
    model_id = model_id,
    n_obs = n_obs,
    n_banks = n_banks,
    mean_outcome = mean_outcome,
    auc_insample = auc_insample,
    auc_oos = auc_oos
  )

  # Predictions dataset (for saving)
  pred_data <- data %>%
    select(bank_id, year, quarters_to_failure,
           outcome = all_of(lhs),
           pred_insample, pred_oos) %>%
    filter(!is.na(pred_insample) | !is.na(pred_oos)) %>%
    mutate(
      model_id = model_id,
      model_type = 1,  # 1 = LPM
      smp_start = start_year,
      smp_end = max_end_year
    ) %>%
    select(bank_id, year, model_id, model_type, smp_start, smp_end,
           quarters_to_failure, outcome, pred_insample, pred_oos)

  cat(sprintf("    Prediction dataset: %d observations\n", nrow(pred_data)))

  model_duration <- as.numeric(difftime(Sys.time(), model_start_time, units = "mins"))
  cat(sprintf("    ✓ Model %d completed in %.2f minutes\n", model_id, model_duration))

  # Return results
  return(list(
    model_full = model_full,
    vcov_dk = vcov_dk,
    coef_table = coef_table,
    summary_stats = summary_stats,
    roc_insample = roc_insample,
    roc_oos = roc_oos,
    pred_data = pred_data,
    data_with_predictions = data
  ))
}

# ===========================================================================
# HELPER FUNCTION: RunModelGD (for Great Depression - special training logic)
# ===========================================================================

RunModelGD <- function(data, model_id, lhs, rhs, DK_lag = 3) {

  cat(sprintf("\n=== GD Model %d: %s ~ %s ===\n", model_id, lhs, rhs))

  model_start_time <- Sys.time()

  start_year <- 1880
  train_end <- 1928  # Train through 1928
  test_start <- 1929  # Test 1929-1934
  test_end <- 1934

  cat(sprintf("  Training period: %d-%d\n", start_year, train_end))
  cat(sprintf("  Testing period: %d-%d\n", test_start, test_end))

  # --- In-sample regression (full test period 1929-1934) ---
  cat("\n  [Step 1/4] Running in-sample regression (test period only)...\n")
  train_full <- data %>% filter(year >= test_start & year <= test_end)

  cat(sprintf("    Test period observations: %d\n", nrow(train_full)))

  formula_str <- paste0(lhs, " ~ ", rhs)

  # Run OLS with error handling for insufficient factor levels
  # Let lm() handle missing values via listwise deletion (matches Stata behavior)
  model_full <- tryCatch({
    lm(as.formula(formula_str), data = train_full, na.action = na.omit)
  }, error = function(e) {
    if (grepl("contrasts|factors with 2 or more levels", e$message)) {
      cat(sprintf("    [WARN] Model failed: %s\n", substr(e$message, 1, 80)))
      cat("    Insufficient factor levels - returning NA results\n")
      return(NULL)
    }
    stop(e)  # Re-throw other errors
  })

  # Check if model failed due to insufficient factor levels
  if (is.null(model_full)) {
    return(list(
      model_id = model_id,
      coefficients = data.frame(),
      predictions = data.frame(
        year = integer(0),
        bank_id = character(0),
        pred_insample = numeric(0),
        pred_oos = numeric(0)
      ),
      auc_insample = NA_real_,
      auc_oos = NA_real_
    ))
  }

  vcov_dk <- NeweyWest(model_full, lag = DK_lag, prewhite = FALSE)

  # Statistics - use model.frame() to get actual observations used
  model_obs <- model.frame(model_full)
  n_obs <- nrow(model_obs)
  
  # Get bank_id from original data for observations used in model
  model_data_indices <- attr(model_obs, "row.names")
  if (is.character(model_data_indices)) {
    model_data_indices <- as.integer(model_data_indices)
  }
  model_bank_ids <- train_full$bank_id[model_data_indices]
  n_banks <- n_distinct(model_bank_ids)
  mean_outcome <- mean(model_obs[[lhs]], na.rm = TRUE) * 100

  cat(sprintf("    Observations: %d | Banks: %d | Mean outcome: %.3f%%\n",
              n_obs, n_banks, mean_outcome))

  # In-sample predictions
  data$pred_insample <- NA_real_
  insample_preds <- tryCatch({
    predict(model_full, newdata = data %>% filter(year >= test_start & year <= test_end))
  }, error = function(e) {
    if (grepl("new levels|factor.*has new", e$message)) {
      cat(sprintf("    [WARN] In-sample prediction failed: %s\n", substr(e$message, 1, 80)))
      cat("    Factor level mismatch - skipping in-sample predictions\n")
      return(NULL)
    }
    stop(e)  # Re-throw other errors
  })

  if (!is.null(insample_preds)) {
    data$pred_insample[data$year >= test_start & data$year <= test_end] <- insample_preds
  }

  # --- Out-of-sample predictions ---
  cat("\n  [Step 2/4] Running out-of-sample predictions...\n")
  cat("    Training on 1880-1928, predicting 1929-1934\n")

  data$pred_oos <- NA_real_

  # Specific years: 1904 (24 years after 1880), then 1929-1934
  train_years <- c(1904, 1929:1934)
  cat(sprintf("    Training cycles: %d\n", length(train_years)))

  n_oos_preds <- 0
  for (end_year in train_years) {
    train_data <- data %>% filter(year >= start_year & year <= end_year)
    test_data <- data %>% filter(year == end_year + 1)

    if (nrow(train_data) == 0 || nrow(test_data) == 0) next

    # Fit model - let lm() handle missing values (matches Stata)
    model_oos <- tryCatch({
      lm(as.formula(formula_str), data = train_data, na.action = na.omit)
    }, error = function(e) NULL)

    if (is.null(model_oos)) next

    pred_oos <- tryCatch({
      predict(model_oos, newdata = test_data)
    }, error = function(e) {
      if (grepl("new levels|factor.*has new", e$message)) {
        cat(sprintf("      [WARN] Prediction failed for year %d: Factor level mismatch\n", end_year + 1))
        return(NULL)
      }
      cat(sprintf("      [WARN] Prediction failed for year %d: %s\n", end_year + 1, substr(e$message, 1, 60)))
      return(NULL)
    })

    if (!is.null(pred_oos)) {
      data$pred_oos[data$year == end_year + 1] <- pred_oos
      n_oos_preds <- n_oos_preds + length(pred_oos)
      cat(sprintf("      Year %d: %d predictions\n", end_year + 1, length(pred_oos)))
    }
  }

  cat(sprintf("    Total OOS predictions: %d\n", n_oos_preds))

  # Calculate AUC
  cat("\n  [Step 3/4] Calculating AUC metrics...\n")
  test_mask <- data$year >= test_start & data$year <= test_end

  # Check if test period response has both levels (excluding NAs)
  test_outcomes <- unique(data[[lhs]][test_mask & !is.na(data[[lhs]])])

  # Also check if predictions are available (not all NA)
  insample_valid <- !is.na(data[[lhs]][test_mask]) & !is.na(data$pred_insample[test_mask])
  valid_predictions <- sum(insample_valid)

  if (length(test_outcomes) < 2) {
    cat(sprintf("    ⚠ Warning: Test period response has only %d unique value(s) - cannot calculate ROC
",
                length(test_outcomes)))
    cat("    Setting AUC to NA
")
    roc_insample <- NULL
    auc_insample <- NA_real_
  } else if (valid_predictions == 0) {
    cat("    ⚠ Warning: All in-sample predictions are NA - cannot calculate ROC
")
    cat("    Setting AUC to NA
")
    roc_insample <- NULL
    auc_insample <- NA_real_
  } else {
    # Wrap in tryCatch to handle edge cases
    roc_insample <- tryCatch({
      roc(data[[lhs]][test_mask], data$pred_insample[test_mask],
          quiet = TRUE, direction = "<")
    }, error = function(e) {
      if (grepl("must have two levels", e$message)) {
        cat("    ⚠ Warning: Response variable lacks variation - cannot calculate ROC\n")
        return(NULL)
      }
      stop(e)  # Re-throw other errors
    })
    auc_insample <- if (!is.null(roc_insample)) as.numeric(auc(roc_insample)) else NA_real_
  }

  oos_valid <- !is.na(data$pred_oos) & !is.na(data[[lhs]]) & test_mask
  if (sum(oos_valid) > 10) {
    # Wrap in tryCatch to handle edge cases
    roc_oos <- tryCatch({
      roc(data[[lhs]][oos_valid], data$pred_oos[oos_valid],
          quiet = TRUE, direction = "<")
    }, error = function(e) {
      if (grepl("must have two levels", e$message)) {
        cat("    ⚠ Warning: OOS response variable lacks variation - cannot calculate ROC\n")
        return(NULL)
      }
      stop(e)  # Re-throw other errors
    })
    auc_oos <- if (!is.null(roc_oos)) as.numeric(auc(roc_oos)) else NA_real_
  } else {
    roc_oos <- NULL
    auc_oos <- NA_real_
  }

  cat(sprintf("    ✓ AUC in-sample: %.4f\n", auc_insample))
  if (!is.na(auc_oos)) {
    cat(sprintf("    ✓ AUC out-of-sample: %.4f\n", auc_oos))
  }

  # Coefficient table
  cat("\n  [Step 4/4] Preparing output...\n")
  coef_full <- coef(model_full)

  # Handle case where vcov_dk dimensions don't match coefficients (due to NA coefficients)
  # Remove NA coefficients and match with vcov_dk
  valid_coefs <- !is.na(coef_full)
  coef_valid <- coef_full[valid_coefs]

  # Check if vcov_dk matches valid coefficients
  if (nrow(vcov_dk) != length(coef_valid)) {
    cat(sprintf("    [WARN] Coefficient/vcov mismatch: %d coefficients, %dx%d vcov\n",
                length(coef_valid), nrow(vcov_dk), ncol(vcov_dk)))
    cat("    Using model-based standard errors instead of Driscoll-Kraay\n")
    se_dk <- sqrt(diag(vcov(model_full)))[valid_coefs]
  } else {
    se_dk <- sqrt(diag(vcov_dk))
  }

  # Coefficient table - match Stata format
  t_stats <- coef_valid / se_dk
  p_values <- 2 * pt(-abs(t_stats), df = n_obs - length(coef_valid))
  ci_lower <- coef_valid - 1.96 * se_dk
  ci_upper <- coef_valid + 1.96 * se_dk
  
  coef_table <- data.frame(
    variable = names(coef_valid),
    coefficient = coef_valid,
    std_error = se_dk,
    t_statistic = t_stats,
    p_value = p_values,
    ci_lower_95 = ci_lower,
    ci_upper_95 = ci_upper,
    row.names = NULL
  )
  
  # Export regression table as CSV
  reg_csv_file <- file.path(tables_dir, sprintf("regression_gd_model_%d.csv", model_id))
  write.csv(coef_table, reg_csv_file, row.names = FALSE)
  cat(sprintf("    ✓ Regression table exported: %s\n", basename(reg_csv_file)))

  # Predictions dataset
  pred_data <- data %>%
    filter(year >= test_start & year <= test_end) %>%
    select(bank_id, year, quarters_to_failure,
           outcome = all_of(lhs),
           pred_insample, pred_oos) %>%
    filter(!is.na(pred_insample) | !is.na(pred_oos)) %>%
    mutate(
      model_id = model_id,
      model_type = 1,
      smp_start = 1929,
      smp_end = 1934
    )

  model_duration <- as.numeric(difftime(Sys.time(), model_start_time, units = "mins"))
  cat(sprintf("    ✓ GD Model %d completed in %.2f minutes\n", model_id, model_duration))

  # Return results
  return(list(
    model_full = model_full,
    vcov_dk = vcov_dk,
    coef_table = coef_table,
    summary_stats = list(
      model_id = model_id,
      n_obs = n_obs,
      n_banks = n_banks,
      mean_outcome = mean_outcome,
      auc_insample = auc_insample,
      auc_oos = auc_oos
    ),
    roc_insample = roc_insample,
    roc_oos = roc_oos,
    pred_data = pred_data
  ))
}

# ===========================================================================
# DEFINE GLOBAL VARIABLE SPECIFICATIONS (Stata: common.do)
# ===========================================================================

cat("--- Defining Variable Specifications ---\n")

# Historical sample (1863-1934)
solvency_hist <- "surplus_ratio"
funding_hist <- "noncore_ratio"

# Modern (1959-2024))
solvency_mod <- "income_ratio"
funding_mod <- "noncore_ratio"

# National Banking Era (1863-1904)
solvency_NB <- "surplus_ratio"
solvency_additional_NB <- "profit_shortfall"
funding_NB <- "emergency_borrowing"

# Early Federal Reserve (1914-1928)
solvency_EF <- "surplus_ratio"
solvency_additional_EF <- "profit_shortfall"
funding_EF <- "noncore_ratio"

# Great Depression (1929-1934)
solvency_GD <- "surplus_ratio"
solvency_additional_GD <- "profit_shortfall"
funding_GD <- "emergency_borrowing"

# Growth and macro controls
growth_controls <- c("growth_cat", "gdp_growth_3years", "inf_cpi_3years")

# Driscoll-Kraay bandwidth
DK <- 3

cat("  ✓ Variable specifications defined\n\n")

# ===========================================================================
# 1. LOAD DATA
# ===========================================================================

cat("===========================================================================\n")
cat("PART 1: DATA LOADING\n")
cat("===========================================================================\n\n")

cat("--- Loading Regression Data ---\n")
data_file <- file.path(tempfiles_dir, "temp_reg_data.dta")
cat(sprintf("  File: %s\n", data_file))

if (!file.exists(data_file)) {
  stop(sprintf("ERROR: Data file not found: %s\n", data_file))
}

file_size_mb <- file.size(data_file) / (1024^2)
cat(sprintf("  File size: %.1f MB\n", file_size_mb))

cat("  Reading Stata file...\n")
load_start <- Sys.time()
reg_data <- haven::read_dta(data_file)
load_duration <- as.numeric(difftime(Sys.time(), load_start, units = "secs"))

cat(sprintf("  ✓ Data loaded in %.1f seconds\n", load_duration))
cat(sprintf("  Observations: %d\n", nrow(reg_data)))
cat(sprintf("  Variables: %d\n", ncol(reg_data)))
cat(sprintf("  Unique banks: %d\n", n_distinct(reg_data$bank_id)))
cat(sprintf("  Year range: %d - %d\n", min(reg_data$year), max(reg_data$year)))
cat(sprintf("  Memory: %.1f MB\n\n", object.size(reg_data)/(1024^2)))

# Clean data types from Stata import
cat("--- Cleaning Data Types ---\n")

# Convert any haven_labelled variables to numeric
labelled_vars <- names(reg_data)[sapply(reg_data, haven::is.labelled)]
if (length(labelled_vars) > 0) {
  cat(sprintf("  Converting %d haven_labelled variables to numeric\n", length(labelled_vars)))
  reg_data <- reg_data %>%
    mutate(across(where(haven::is.labelled), as.numeric))
}

# Convert growth_cat to factor (if it exists and is not already a factor)
if ("growth_cat" %in% names(reg_data) && !is.factor(reg_data$growth_cat)) {
  reg_data <- reg_data %>%
    mutate(growth_cat = factor(growth_cat))
  cat("  ✓ Converted growth_cat to factor\n")
}

cat("  ✓ Data types cleaned\n\n")

# ===========================================================================
# 2. HISTORICAL SAMPLE MODELS (1863-1934)
# ===========================================================================

cat("===========================================================================\n")
cat("PART 2: HISTORICAL SAMPLE REGRESSIONS (1863-1934)\n")
cat("===========================================================================\n")

# Filter to historical period
cat("\n--- Filtering to Historical Period ---\n")
hist_data <- reg_data %>%
  filter(year >= 1863 & year <= 1934)

cat(sprintf("  Observations: %d (%.1f%% of total)\n",
            nrow(hist_data),
            100*nrow(hist_data)/nrow(reg_data)))
cat(sprintf("  Banks: %d\n", n_distinct(hist_data$bank_id)))
cat(sprintf("  Years: %d\n", length(unique(hist_data$year))))

# Check for required variables
required_vars <- c("F1_failure", solvency_hist, funding_hist, "log_age")
missing_vars <- setdiff(required_vars, names(hist_data))
if (length(missing_vars) > 0) {
  stop(sprintf("ERROR: Missing required variables: %s\n",
               paste(missing_vars, collapse = ", ")))
}
cat("  ✓ All required variables present\n\n")

# Storage for results
hist_results <- list()
hist_start_time <- Sys.time()

cat("--- Running Historical Models (7 models) ---\n")

# Model 1: Solvency only
cat("\n[Historical Model 1/7] Solvency only\n")
hist_results[[1]] <- RunModelLPM(
  data = hist_data,
  model_id = 1,
  lhs = "F1_failure",
  rhs = paste0(solvency_hist, " + log_age"),
  start_year = 1863,
  max_end_year = 1934,
  min_window = 10,
  DK_lag = DK
)

# Model 2: Funding only
cat("\n[Historical Model 2/7] Funding only\n")
hist_results[[2]] <- RunModelLPM(
  data = hist_data,
  model_id = 2,
  lhs = "F1_failure",
  rhs = paste0(funding_hist, " + log_age"),
  start_year = 1863,
  max_end_year = 1934,
  min_window = 10,
  DK_lag = DK
)

# Model 3: Solvency × Funding interaction
cat("\n[Historical Model 3/7] Solvency × Funding interaction\n")
hist_results[[3]] <- RunModelLPM(
  data = hist_data,
  model_id = 3,
  lhs = "F1_failure",
  rhs = paste0(funding_hist, " * ", solvency_hist, " + log_age"),
  start_year = 1863,
  max_end_year = 1934,
  min_window = 10,
  DK_lag = DK
)

# Model 4: Full specification with growth controls
cat("\n[Historical Model 4/7] Full specification\n")
hist_results[[4]] <- RunModelLPM(
  data = hist_data,
  model_id = 4,
  lhs = "F1_failure",
  rhs = paste0(funding_hist, " * ", solvency_hist, " + log_age + ",
               "growth_cat + gdp_growth_3years + inf_cpi_3years"),
  start_year = 1863,
  max_end_year = 1934,
  min_window = 10,
  DK_lag = DK
)

# Model 5: Bank run failures (requires run data from 1880+)
if ("F1_failure_run" %in% names(hist_data)) {
  cat("\n[Historical Model 5/7] Bank run failures\n")
  hist_results[[5]] <- RunModelLPM(
    data = hist_data,
    model_id = 5,
    lhs = "F1_failure_run",
    rhs = paste0(funding_hist, " * ", solvency_hist, " + log_age + ",
                 "growth_cat + gdp_growth_3years + inf_cpi_3years"),
    start_year = 1880,  # Note: starts later
    max_end_year = 1934,
    min_window = 10,
    DK_lag = DK
  )
} else {
  cat("\n[Historical Model 5/7] SKIPPED - F1_failure_run not available\n")
}

# Model 7: 3-year failure horizon
if ("F3_failure" %in% names(hist_data)) {
  cat("\n[Historical Model 7/7] 3-year failure horizon\n")
  hist_results[[7]] <- RunModelLPM(
    data = hist_data,
    model_id = 7,
    lhs = "F3_failure",
    rhs = paste0(funding_hist, " * ", solvency_hist, " + log_age + ",
                 "growth_cat + gdp_growth_3years + inf_cpi_3years"),
    start_year = 1863,
    max_end_year = 1934,
    min_window = 10,
    DK_lag = DK
  )
} else {
  cat("\n[Historical Model 7/7] SKIPPED - F3_failure not available\n")
}

# Model 8: 5-year failure horizon
if ("F5_failure" %in% names(hist_data)) {
  cat("\n[Historical Model 8/7] 5-year failure horizon\n")
  hist_results[[8]] <- RunModelLPM(
    data = hist_data,
    model_id = 8,
    lhs = "F5_failure",
    rhs = paste0(funding_hist, " * ", solvency_hist, " + log_age + ",
                 "growth_cat + gdp_growth_3years + inf_cpi_3years"),
    start_year = 1863,
    max_end_year = 1934,
    min_window = 10,
    DK_lag = DK
  )
} else {
  cat("\n[Historical Model 8/7] SKIPPED - F5_failure not available\n")
}

hist_duration <- as.numeric(difftime(Sys.time(), hist_start_time, units = "mins"))
cat(sprintf("\n✓ Historical sample completed: %d models in %.1f minutes\n\n",
            sum(!sapply(hist_results, is.null)), hist_duration))

# ===========================================================================
# 3. MODERN SAMPLE MODELS (1959-2024)
# ===========================================================================

cat("===========================================================================\n")
cat("PART 3: MODERN SAMPLE REGRESSIONS (1959-2024)\n")
cat("===========================================================================\n")

# Filter to modern period
cat("\n--- Filtering to Modern Period ---\n")
modern_data <- reg_data %>%
  filter(year >= 1959 & year <= 2023)

cat(sprintf("  Observations: %d (%.1f%% of total)\n",
            nrow(modern_data),
            100*nrow(modern_data)/nrow(reg_data)))
cat(sprintf("  Banks: %d\n", n_distinct(modern_data$bank_id)))
cat(sprintf("  Years: %d\n\n", length(unique(modern_data$year))))

# Storage for results
modern_results <- list()
modern_start_time <- Sys.time()

cat("--- Running Modern Models (7 models) ---\n")

# Model 1: Solvency only
cat("\n[Modern Model 1/7] Solvency only\n")
modern_results[[1]] <- RunModelLPM(
  data = modern_data,
  model_id = 1,
  lhs = "F1_failure",
  rhs = paste0(solvency_mod, " + log_age"),
  start_year = 1959,
  max_end_year = 2023,
  min_window = 10,
  DK_lag = DK
)

# Model 2: Funding only
cat("\n[Modern Model 2/7] Funding only\n")
modern_results[[2]] <- RunModelLPM(
  data = modern_data,
  model_id = 2,
  lhs = "F1_failure",
  rhs = paste0(funding_mod, " + log_age"),
  start_year = 1959,
  max_end_year = 2023,
  min_window = 10,
  DK_lag = DK
)

# Model 3: Solvency × Funding interaction
cat("\n[Modern Model 3/7] Solvency × Funding interaction\n")
modern_results[[3]] <- RunModelLPM(
  data = modern_data,
  model_id = 3,
  lhs = "F1_failure",
  rhs = paste0(funding_mod, " * ", solvency_mod, " + log_age"),
  start_year = 1959,
  max_end_year = 2023,
  min_window = 10,
  DK_lag = DK
)

# Model 4: Full specification with growth controls
cat("\n[Modern Model 4/7] Full specification\n")
modern_results[[4]] <- RunModelLPM(
  data = modern_data,
  model_id = 4,
  lhs = "F1_failure",
  rhs = paste0(funding_mod, " * ", solvency_mod, " + log_age + ",
               "growth_cat + gdp_growth_3years + inf_cpi_3years"),
  start_year = 1959,
  max_end_year = 2023,
  min_window = 10,
  DK_lag = DK
)

# Model 5: Bank run failures (from 1993+)
if ("F1_failure_run" %in% names(modern_data)) {
  cat("\n[Modern Model 5/7] Bank run failures\n")
  modern_results[[5]] <- RunModelLPM(
    data = modern_data,
    model_id = 5,
    lhs = "F1_failure_run",
    rhs = paste0(funding_mod, " * ", solvency_mod, " + log_age + ",
                 "growth_cat + gdp_growth_3years + inf_cpi_3years"),
    start_year = 1993,  # Note: starts later
    max_end_year = 2023,
    min_window = 10,
    DK_lag = DK
  )
} else {
  cat("\n[Modern Model 5/7] SKIPPED - F1_failure_run not available\n")
}

# Model 7: 3-year failure horizon
if ("F3_failure" %in% names(modern_data)) {
  cat("\n[Modern Model 7/7] 3-year failure horizon\n")
  modern_results[[7]] <- RunModelLPM(
    data = modern_data,
    model_id = 7,
    lhs = "F3_failure",
    rhs = paste0(funding_mod, " * ", solvency_mod, " + log_age + ",
                 "growth_cat + gdp_growth_3years + inf_cpi_3years"),
    start_year = 1959,
    max_end_year = 2023,
    min_window = 10,
    DK_lag = DK
  )
} else {
  cat("\n[Modern Model 7/7] SKIPPED - F3_failure not available\n")
}

# Model 8: 5-year failure horizon
if ("F5_failure" %in% names(modern_data)) {
  cat("\n[Modern Model 8/7] 5-year failure horizon\n")
  modern_results[[8]] <- RunModelLPM(
    data = modern_data,
    model_id = 8,
    lhs = "F5_failure",
    rhs = paste0(funding_mod, " * ", solvency_mod, " + log_age + ",
                 "growth_cat + gdp_growth_3years + inf_cpi_3years"),
    start_year = 1959,
    max_end_year = 2023,
    min_window = 10,
    DK_lag = DK
  )
} else {
  cat("\n[Modern Model 8/7] SKIPPED - F5_failure not available\n")
}

modern_duration <- as.numeric(difftime(Sys.time(), modern_start_time, units = "mins"))
cat(sprintf("\n✓ Modern sample completed: %d models in %.1f minutes\n\n",
            sum(!sapply(modern_results, is.null)), modern_duration))

# ===========================================================================
# 4. GRANULAR PERIOD: NATIONAL BANKING ERA (1863-1904)
# ===========================================================================

cat("===========================================================================\n")
cat("PART 4: NATIONAL BANKING ERA REGRESSIONS (1863-1904)\n")
cat("===========================================================================\n")

cat("\n--- Filtering to National Banking Period ---\n")
nb_data <- reg_data %>%
  filter(year >= 1863 & year <= 1904)

cat(sprintf("  Observations: %d\n", nrow(nb_data)))
cat(sprintf("  Banks: %d\n", n_distinct(nb_data$bank_id)))
cat(sprintf("  Years: %d\n\n", length(unique(nb_data$year))))

nb_results <- list()
nb_start_time <- Sys.time()

cat("--- Running National Banking Models (7 models) ---\n")

# Model 1: Solvency
cat("\n[NB Model 1/7] Solvency\n")
nb_results[[1]] <- RunModelLPM(
  data = nb_data,
  model_id = 1,
  lhs = "F1_failure",
  rhs = "surplus_ratio + profit_shortfall + loan_ratio + leverage + log_age",
  start_year = 1863,
  max_end_year = 1904,
  min_window = 10,
  DK_lag = DK
)

# Model 2: Funding
cat("\n[NB Model 2/7] Funding\n")
nb_results[[2]] <- RunModelLPM(
  data = nb_data,
  model_id = 2,
  lhs = "F1_failure",
  rhs = "emergency_borrowing + log_age",
  start_year = 1863,
  max_end_year = 1904,
  min_window = 10,
  DK_lag = DK
)

# Model 3: Solvency × Funding
cat("\n[NB Model 3/7] Solvency × Funding\n")
nb_results[[3]] <- RunModelLPM(
  data = nb_data,
  model_id = 3,
  lhs = "F1_failure",
  rhs = "emergency_borrowing * surplus_ratio + emergency_borrowing * profit_shortfall + loan_ratio + leverage + log_age",
  start_year = 1863,
  max_end_year = 1904,
  min_window = 10,
  DK_lag = DK
)

# Model 4: Full specification
cat("\n[NB Model 4/7] Full specification\n")
nb_results[[4]] <- RunModelLPM(
  data = nb_data,
  model_id = 4,
  lhs = "F1_failure",
  rhs = "emergency_borrowing * surplus_ratio + emergency_borrowing * profit_shortfall + loan_ratio + leverage + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years",
  start_year = 1863,
  max_end_year = 1904,
  min_window = 10,
  DK_lag = DK
)

# Model 5: Bank runs
if ("F1_failure_run" %in% names(nb_data)) {
  cat("\n[NB Model 5/7] Bank runs\n")
  nb_results[[5]] <- RunModelLPM(
    data = nb_data,
    model_id = 5,
    lhs = "F1_failure_run",
    rhs = "emergency_borrowing * surplus_ratio + emergency_borrowing * profit_shortfall + loan_ratio + leverage + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years",
    start_year = 1880,
    max_end_year = 1904,
    min_window = 10,
    DK_lag = DK
  )
} else {
  cat("\n[NB Model 5/7] SKIPPED - F1_failure_run not available\n")
}

# Model 7: 3-year horizon
if ("F3_failure" %in% names(nb_data)) {
  cat("\n[NB Model 7/7] 3-year horizon\n")
  nb_results[[7]] <- RunModelLPM(
    data = nb_data,
    model_id = 7,
    lhs = "F3_failure",
    rhs = "emergency_borrowing * surplus_ratio + emergency_borrowing * profit_shortfall + loan_ratio + leverage + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years",
    start_year = 1863,
    max_end_year = 1904,
    min_window = 10,
    DK_lag = DK
  )
} else {
  cat("\n[NB Model 7/7] SKIPPED - F3_failure not available\n")
}

# Model 8: 5-year horizon
if ("F5_failure" %in% names(nb_data)) {
  cat("\n[NB Model 8/7] 5-year horizon\n")
  nb_results[[8]] <- RunModelLPM(
    data = nb_data,
    model_id = 8,
    lhs = "F5_failure",
    rhs = "emergency_borrowing * surplus_ratio + emergency_borrowing * profit_shortfall + loan_ratio + leverage + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years",
    start_year = 1863,
    max_end_year = 1904,
    min_window = 10,
    DK_lag = DK
  )
} else {
  cat("\n[NB Model 8/7] SKIPPED - F5_failure not available\n")
}

nb_duration <- as.numeric(difftime(Sys.time(), nb_start_time, units = "mins"))
cat(sprintf("\n✓ National Banking completed: %d models in %.1f minutes\n\n",
            sum(!sapply(nb_results, is.null)), nb_duration))

# ===========================================================================
# 5. GRANULAR PERIOD: EARLY FEDERAL RESERVE (1914-1928)
# ===========================================================================

cat("===========================================================================\n")
cat("PART 5: EARLY FEDERAL RESERVE REGRESSIONS (1914-1928)\n")
cat("===========================================================================\n")

cat("\n--- Filtering to Early Fed Period ---\n")
ef_data <- reg_data %>%
  filter(year >= 1914 & year <= 1928)

cat(sprintf("  Observations: %d\n", nrow(ef_data)))
cat(sprintf("  Banks: %d\n", n_distinct(ef_data$bank_id)))
cat(sprintf("  Years: %d\n", length(unique(ef_data$year))))
cat("  Note: Using DK bandwidth of 2 (shorter period)\n\n")

ef_results <- list()
ef_start_time <- Sys.time()
DK_ef <- 2  # Stata line 299

cat("--- Running Early Fed Models (7 models) ---\n")

# Model 1: Solvency
cat("\n[EF Model 1/7] Solvency\n")
ef_results[[1]] <- RunModelLPM(
  data = ef_data,
  model_id = 1,
  lhs = "F1_failure",
  rhs = "surplus_ratio + loan_ratio + leverage + log_age",
  start_year = 1914,
  max_end_year = 1928,
  min_window = 10,
  DK_lag = DK_ef
)

# Model 2: Funding
cat("\n[EF Model 2/7] Funding\n")
ef_results[[2]] <- RunModelLPM(
  data = ef_data,
  model_id = 2,
  lhs = "F1_failure",
  rhs = "noncore_ratio + log_age",
  start_year = 1914,
  max_end_year = 1928,
  min_window = 10,
  DK_lag = DK_ef
)

# Model 3: Solvency × Funding
cat("\n[EF Model 3/7] Solvency × Funding\n")
ef_results[[3]] <- RunModelLPM(
  data = ef_data,
  model_id = 3,
  lhs = "F1_failure",
  rhs = "noncore_ratio * surplus_ratio + loan_ratio + leverage + log_age",
  start_year = 1914,
  max_end_year = 1928,
  min_window = 10,
  DK_lag = DK_ef
)

# Model 4: Full specification
cat("\n[EF Model 4/7] Full specification\n")
ef_results[[4]] <- RunModelLPM(
  data = ef_data,
  model_id = 4,
  lhs = "F1_failure",
  rhs = "noncore_ratio * surplus_ratio + loan_ratio + leverage + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years",
  start_year = 1914,
  max_end_year = 1928,
  min_window = 10,
  DK_lag = DK_ef
)

# Model 5: Bank runs
if ("F1_failure_run" %in% names(ef_data)) {
  cat("\n[EF Model 5/7] Bank runs\n")
  ef_results[[5]] <- RunModelLPM(
    data = ef_data,
    model_id = 5,
    lhs = "F1_failure_run",
    rhs = "noncore_ratio * surplus_ratio + loan_ratio + leverage + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years",
    start_year = 1914,
    max_end_year = 1928,
    min_window = 10,
    DK_lag = DK_ef
  )
} else {
  cat("\n[EF Model 5/7] SKIPPED - F1_failure_run not available\n")
}

# Model 7: 3-year horizon
if ("F3_failure" %in% names(ef_data)) {
  cat("\n[EF Model 7/7] 3-year horizon\n")
  ef_results[[7]] <- RunModelLPM(
    data = ef_data,
    model_id = 7,
    lhs = "F3_failure",
    rhs = "noncore_ratio * surplus_ratio + loan_ratio + leverage + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years",
    start_year = 1914,
    max_end_year = 1928,
    min_window = 10,
    DK_lag = DK_ef
  )
} else {
  cat("\n[EF Model 7/7] SKIPPED - F3_failure not available\n")
}

# Model 8: 5-year horizon
if ("F5_failure" %in% names(ef_data)) {
  cat("\n[EF Model 8/7] 5-year horizon\n")
  ef_results[[8]] <- RunModelLPM(
    data = ef_data,
    model_id = 8,
    lhs = "F5_failure",
    rhs = "noncore_ratio * surplus_ratio + loan_ratio + leverage + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years",
    start_year = 1914,
    max_end_year = 1928,
    min_window = 10,
    DK_lag = DK_ef
  )
} else {
  cat("\n[EF Model 8/7] SKIPPED - F5_failure not available\n")
}

ef_duration <- as.numeric(difftime(Sys.time(), ef_start_time, units = "mins"))
cat(sprintf("\n✓ Early Fed completed: %d models in %.1f minutes\n\n",
            sum(!sapply(ef_results, is.null)), ef_duration))

# ===========================================================================
# 6. GRANULAR PERIOD: GREAT DEPRESSION (1929-1934)
# ===========================================================================

cat("===========================================================================\n")
cat("PART 6: GREAT DEPRESSION REGRESSIONS (1929-1934)\n")
cat("===========================================================================\n")

cat("\n--- Preparing Great Depression Data ---\n")
cat("  Training period: 1880-1928\n")
cat("  Testing period: 1929-1934\n")

gd_data <- reg_data %>%
  filter(year >= 1880 & year <= 1934)

cat(sprintf("  Full dataset: %d observations\n", nrow(gd_data)))
cat(sprintf("  Banks: %d\n\n", n_distinct(gd_data$bank_id)))

gd_results <- list()
gd_start_time <- Sys.time()

cat("--- Running Great Depression Models (7 models) ---\n")
cat("  Note: Using custom RunModelGD function\n")

# Model 1: Solvency
cat("\n[GD Model 1/7] Solvency\n")
gd_results[[1]] <- RunModelGD(
  data = gd_data,
  model_id = 1,
  lhs = "F1_failure",
  rhs = "surplus_ratio + profit_shortfall + loan_ratio + leverage + log_age",
  DK_lag = DK
)

# Model 2: Funding
cat("\n[GD Model 2/7] Funding\n")
gd_results[[2]] <- RunModelGD(
  data = gd_data,
  model_id = 2,
  lhs = "F1_failure",
  rhs = "emergency_borrowing + log_age",
  DK_lag = DK
)

# Model 3: Solvency × Funding
cat("\n[GD Model 3/7] Solvency × Funding\n")
gd_results[[3]] <- RunModelGD(
  data = gd_data,
  model_id = 3,
  lhs = "F1_failure",
  rhs = "emergency_borrowing * surplus_ratio + emergency_borrowing * profit_shortfall + loan_ratio + leverage + log_age",
  DK_lag = DK
)

# Model 4: Full specification
cat("\n[GD Model 4/7] Full specification\n")
gd_results[[4]] <- RunModelGD(
  data = gd_data,
  model_id = 4,
  lhs = "F1_failure",
  rhs = "emergency_borrowing * surplus_ratio + emergency_borrowing * profit_shortfall + loan_ratio + leverage + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years",
  DK_lag = DK
)

# Model 5: Bank runs
if ("F1_failure_run" %in% names(gd_data)) {
  cat("\n[GD Model 5/7] Bank runs\n")
  gd_results[[5]] <- RunModelGD(
    data = gd_data,
    model_id = 5,
    lhs = "F1_failure_run",
    rhs = "emergency_borrowing * surplus_ratio + emergency_borrowing * profit_shortfall + loan_ratio + leverage + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years",
    DK_lag = DK
  )
} else {
  cat("\n[GD Model 5/7] SKIPPED - F1_failure_run not available\n")
}

# Model 7: 3-year horizon
if ("F3_failure" %in% names(gd_data)) {
  cat("\n[GD Model 7/7] 3-year horizon\n")
  gd_results[[7]] <- RunModelGD(
    data = gd_data,
    model_id = 7,
    lhs = "F3_failure",
    rhs = "emergency_borrowing * surplus_ratio + emergency_borrowing * profit_shortfall + loan_ratio + leverage + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years",
    DK_lag = DK
  )
} else {
  cat("\n[GD Model 7/7] SKIPPED - F3_failure not available\n")
}

# Model 8: 5-year horizon
if ("F5_failure" %in% names(gd_data)) {
  cat("\n[GD Model 8/7] 5-year horizon\n")
  gd_results[[8]] <- RunModelGD(
    data = gd_data,
    model_id = 8,
    lhs = "F5_failure",
    rhs = "emergency_borrowing * surplus_ratio + emergency_borrowing * profit_shortfall + loan_ratio + leverage + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years",
    DK_lag = DK
  )
} else {
  cat("\n[GD Model 8/7] SKIPPED - F5_failure not available\n")
}

gd_duration <- as.numeric(difftime(Sys.time(), gd_start_time, units = "mins"))
cat(sprintf("\n✓ Great Depression completed: %d models in %.1f minutes\n\n",
            sum(!sapply(gd_results, is.null)), gd_duration))

# ===========================================================================
# 7. SAVE PREDICTION FILES
# ===========================================================================

cat("===========================================================================\n")
cat("PART 7: SAVING PREDICTION FILES\n")
cat("===========================================================================\n\n")

save_start_time <- Sys.time()
n_files_saved <- 0

cat("--- Saving Historical Predictions (1863-1934) ---\n")
for (i in seq_along(hist_results)) {
  if (!is.null(hist_results[[i]]) && is.data.frame(hist_results[[i]]$pred_data) && nrow(hist_results[[i]]$pred_data) > 0) {
    # RDS format
    pred_file_rds <- file.path(tempfiles_dir, sprintf("PV_LPM_%d_1863_1934.rds", i))
    saveRDS(hist_results[[i]]$pred_data, pred_file_rds)

    # Stata format
    pred_file_dta <- file.path(tempfiles_dir, sprintf("PV_LPM_%d_1863_1934.dta", i))
    haven::write_dta(hist_results[[i]]$pred_data, pred_file_dta)

    # CSV format (for easy comparison)
    pred_file_csv <- file.path(tempfiles_dir, sprintf("PV_LPM_%d_1863_1934.csv", i))
    write.csv(hist_results[[i]]$pred_data, pred_file_csv, row.names = FALSE)

    n_files_saved <- n_files_saved + 3
    cat(sprintf("  ✓ Model %d: %d predictions (RDS + DTA + CSV)\n",
                i, nrow(hist_results[[i]]$pred_data)))
  } else {
    cat(sprintf("  ⚠ Model %d: Skipped (no valid predictions)\n", i))
  }
}

cat("\n--- Saving Modern (1959-2024)) ---\n")
for (i in seq_along(modern_results)) {
  if (!is.null(modern_results[[i]]) && is.data.frame(modern_results[[i]]$pred_data) && nrow(modern_results[[i]]$pred_data) > 0) {
    pred_file_rds <- file.path(tempfiles_dir, sprintf("PV_LPM_%d_1959_2024.rds", i))
    saveRDS(modern_results[[i]]$pred_data, pred_file_rds)

    pred_file_dta <- file.path(tempfiles_dir, sprintf("PV_LPM_%d_1959_2024.dta", i))
    haven::write_dta(modern_results[[i]]$pred_data, pred_file_dta)

    # CSV format (for easy comparison)
    pred_file_csv <- file.path(tempfiles_dir, sprintf("PV_LPM_%d_1959_2024.csv", i))
    write.csv(modern_results[[i]]$pred_data, pred_file_csv, row.names = FALSE)

    n_files_saved <- n_files_saved + 3
    cat(sprintf("  ✓ Model %d: %d predictions (RDS + DTA + CSV)\n",
                i, nrow(modern_results[[i]]$pred_data)))
  } else {
    cat(sprintf("  ⚠ Model %d: Skipped (no valid predictions)\n", i))
  }
}

cat("\n--- Saving National Banking Predictions (1863-1904) ---\n")
for (i in seq_along(nb_results)) {
  if (!is.null(nb_results[[i]]) && is.data.frame(nb_results[[i]]$pred_data) && nrow(nb_results[[i]]$pred_data) > 0) {
    saveRDS(nb_results[[i]]$pred_data,
            file.path(tempfiles_dir, sprintf("PV_LPM_%d_1863_1904.rds", i)))
    haven::write_dta(nb_results[[i]]$pred_data,
                     file.path(tempfiles_dir, sprintf("PV_LPM_%d_1863_1904.dta", i)))
    write.csv(nb_results[[i]]$pred_data,
              file.path(tempfiles_dir, sprintf("PV_LPM_%d_1863_1904.csv", i)),
              row.names = FALSE)

    n_files_saved <- n_files_saved + 3
    cat(sprintf("  ✓ Model %d: %d predictions (RDS + DTA + CSV)\n",
                i, nrow(nb_results[[i]]$pred_data)))
  } else {
    cat(sprintf("  ⚠ Model %d: Skipped (no valid predictions)\n", i))
  }
}

cat("\n--- Saving Early Fed Predictions (1914-1928) ---\n")
for (i in seq_along(ef_results)) {
  if (!is.null(ef_results[[i]]) && is.data.frame(ef_results[[i]]$pred_data) && nrow(ef_results[[i]]$pred_data) > 0) {
    saveRDS(ef_results[[i]]$pred_data,
            file.path(tempfiles_dir, sprintf("PV_LPM_%d_1914_1928.rds", i)))
    haven::write_dta(ef_results[[i]]$pred_data,
                     file.path(tempfiles_dir, sprintf("PV_LPM_%d_1914_1928.dta", i)))
    write.csv(ef_results[[i]]$pred_data,
              file.path(tempfiles_dir, sprintf("PV_LPM_%d_1914_1928.csv", i)),
              row.names = FALSE)

    n_files_saved <- n_files_saved + 3
    cat(sprintf("  ✓ Model %d: %d predictions (RDS + DTA + CSV)\n",
                i, nrow(ef_results[[i]]$pred_data)))
  } else {
    cat(sprintf("  ⚠ Model %d: Skipped (no valid predictions)\n", i))
  }
}

cat("\n--- Saving Great Depression Predictions (1929-1934) ---\n")
for (i in seq_along(gd_results)) {
  if (!is.null(gd_results[[i]]) && is.data.frame(gd_results[[i]]$pred_data) && nrow(gd_results[[i]]$pred_data) > 0) {
    saveRDS(gd_results[[i]]$pred_data,
            file.path(tempfiles_dir, sprintf("PV_LPM_%d_1929_1934.rds", i)))
    haven::write_dta(gd_results[[i]]$pred_data,
                     file.path(tempfiles_dir, sprintf("PV_LPM_%d_1929_1934.dta", i)))
    write.csv(gd_results[[i]]$pred_data,
              file.path(tempfiles_dir, sprintf("PV_LPM_%d_1929_1934.csv", i)),
              row.names = FALSE)

    n_files_saved <- n_files_saved + 3
    cat(sprintf("  ✓ Model %d: %d predictions (RDS + DTA + CSV)\n",
                i, nrow(gd_results[[i]]$pred_data)))
  } else {
    cat(sprintf("  ⚠ Model %d: Skipped (no valid predictions)\n", i))
  }
}

save_duration <- as.numeric(difftime(Sys.time(), save_start_time, units = "secs"))
cat(sprintf("\n✓ Saved %d prediction files in %.1f seconds\n\n", n_files_saved, save_duration))

# ===========================================================================
# 8. CREATE AUC SUMMARY TABLES
# ===========================================================================

cat("===========================================================================\n")
cat("PART 8: CREATING AUC SUMMARY TABLES\n")
cat("===========================================================================\n\n")

# Extract AUC function
extract_auc <- function(results_list, period_name) {
  cat(sprintf("  Extracting AUC metrics for %s...\n", period_name))

  auc_df <- data.frame(
    period = character(),
    model = integer(),
    n_obs = integer(),
    n_banks = integer(),
    mean_outcome = numeric(),
    auc_insample = numeric(),
    auc_oos = numeric(),
    stringsAsFactors = FALSE
  )

  for (i in seq_along(results_list)) {
    if (!is.null(results_list[[i]]) && !is.null(results_list[[i]]$summary_stats)) {
      stats <- results_list[[i]]$summary_stats

      # Check if stats has all required fields
      if (!is.null(stats$model_id) && !is.null(stats$n_obs)) {
        auc_df <- rbind(auc_df, data.frame(
          period = period_name,
          model = stats$model_id,
          n_obs = stats$n_obs,
          n_banks = stats$n_banks,
          mean_outcome = stats$mean_outcome,
          auc_insample = stats$auc_insample,
          auc_oos = stats$auc_oos,
          stringsAsFactors = FALSE
        ))
      }
    }
  }

  cat(sprintf("    ✓ Extracted %d models\n", nrow(auc_df)))
  return(auc_df)
}

cat("--- Extracting AUC Metrics ---\n")
auc_hist <- extract_auc(hist_results, "Historical (1863-1934)")
auc_modern <- extract_auc(modern_results, "Modern (1959-2024))")
auc_nb <- extract_auc(nb_results, "National Banking (1863-1904)")
auc_ef <- extract_auc(ef_results, "Early Fed (1914-1928)")
auc_gd <- extract_auc(gd_results, "Great Depression (1929-1934)")

# Table 1: Main historical and modern results
cat("\n--- Creating Table 1 (Main Results) ---\n")
auc_table1 <- rbind(auc_hist, auc_modern)

table1_file_rds <- file.path(tempfiles_dir, "table1_auc_summary.rds")
table1_file_csv <- file.path(tempfiles_dir, "table1_auc_summary.csv")

saveRDS(auc_table1, table1_file_rds)
write.csv(auc_table1, table1_file_csv, row.names = FALSE)

cat(sprintf("  ✓ Saved: %s (%.1f KB)\n",
            basename(table1_file_csv),
            file.size(table1_file_csv)/1024))

cat("\n--- Table 1 Summary ---\n")
print(auc_table1)

# Table B.15: All periods including granular
cat("\n--- Creating Table B.15 (All Periods) ---\n")
auc_table_full <- rbind(auc_hist, auc_modern, auc_nb, auc_ef, auc_gd)

tableB15_file_rds <- file.path(tempfiles_dir, "table_auc_all_periods.rds")
tableB15_file_csv <- file.path(tempfiles_dir, "table_auc_all_periods.csv")

saveRDS(auc_table_full, tableB15_file_rds)
write.csv(auc_table_full, tableB15_file_csv, row.names = FALSE)

cat(sprintf("  ✓ Saved: %s (%.1f KB)\n",
            basename(tableB15_file_csv),
            file.size(tableB15_file_csv)/1024))

cat("\n--- Table B.15 Summary ---\n")
cat(sprintf("  Total periods: %d\n", length(unique(auc_table_full$period))))
cat(sprintf("  Total models: %d\n", nrow(auc_table_full)))
cat(sprintf("  Mean AUC in-sample: %.4f\n", mean(auc_table_full$auc_insample, na.rm = TRUE)))
cat(sprintf("  Mean AUC out-of-sample: %.4f\n", mean(auc_table_full$auc_oos, na.rm = TRUE)))
cat("\n")

# ===========================================================================
# 9. CREATE ROC CURVE PLOTS (Figure 7)
# ===========================================================================

cat("===========================================================================\n")
cat("PART 9: CREATING ROC CURVE PLOTS (FIGURE 7)\n")
cat("===========================================================================\n\n")

# Plot helper function
plot_roc_curves <- function(results_list, period_name, filename) {

  cat(sprintf("  Creating ROC curves for %s...\n", period_name))

  output_file <- file.path(figures_dir, filename)

  pdf(output_file, width = 12, height = 6)
  par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))

  # Panel A: In-sample
  plot(NULL, xlim = c(0, 1), ylim = c(0, 1),
       xlab = "False Positive Rate (1 - Specificity)",
       ylab = "True Positive Rate (Sensitivity)",
       main = paste0(period_name, "\nIn-Sample ROC Curves"),
       cex.main = 1.1, cex.lab = 0.9)
  abline(0, 1, lty = 2, col = "gray50", lwd = 1.5)

  colors <- c("blue", "red", "darkgreen", "purple", "orange", "brown", "pink", "cyan")
  legend_text <- c()
  legend_colors <- c()

  for (i in seq_along(results_list)) {
    if (!is.null(results_list[[i]]) && !is.null(results_list[[i]]$roc_insample)) {
      roc_obj <- results_list[[i]]$roc_insample
      lines(1 - roc_obj$specificities, roc_obj$sensitivities,
            col = colors[i], lwd = 2)
      legend_text <- c(legend_text,
                      sprintf("Model %d (%.3f)", i,
                              results_list[[i]]$summary_stats$auc_insample))
      legend_colors <- c(legend_colors, colors[i])
    }
  }

  legend("bottomright", legend = legend_text, col = legend_colors,
         lwd = 2, cex = 0.7, bg = "white")

  # Panel B: Out-of-sample
  plot(NULL, xlim = c(0, 1), ylim = c(0, 1),
       xlab = "False Positive Rate (1 - Specificity)",
       ylab = "True Positive Rate (Sensitivity)",
       main = paste0(period_name, "\nOut-of-Sample ROC Curves"),
       cex.main = 1.1, cex.lab = 0.9)
  abline(0, 1, lty = 2, col = "gray50", lwd = 1.5)

  legend_text_oos <- c()
  legend_colors_oos <- c()

  for (i in seq_along(results_list)) {
    if (!is.null(results_list[[i]]) && !is.null(results_list[[i]]$roc_oos)) {
      roc_obj <- results_list[[i]]$roc_oos
      lines(1 - roc_obj$specificities, roc_obj$sensitivities,
            col = colors[i], lwd = 2)
      legend_text_oos <- c(legend_text_oos,
                          sprintf("Model %d (%.3f)", i,
                                  results_list[[i]]$summary_stats$auc_oos))
      legend_colors_oos <- c(legend_colors_oos, colors[i])
    }
  }

  legend("bottomright", legend = legend_text_oos, col = legend_colors_oos,
         lwd = 2, cex = 0.7, bg = "white")

  dev.off()

  file_size_kb <- file.size(output_file) / 1024
  cat(sprintf("    ✓ Saved: %s (%.1f KB)\n", filename, file_size_kb))
}

cat("--- Creating Figure 7 Panels ---\n")

# Figure 7A: Historical
plot_roc_curves(hist_results, "Historical (1863-1934)", "figure7a_roc_historical.pdf")

# Figure 7B: Modern
plot_roc_curves(modern_results, "Modern (1959-2024))", "figure7b_roc_modern.pdf")

cat("\n")

# ===========================================================================
# 10. FINAL SUMMARY AND COMPLETION
# ===========================================================================

script_duration <- as.numeric(difftime(Sys.time(), script_start_time, units = "mins"))

cat("===========================================================================\n")
cat("SCRIPT 51 COMPLETED SUCCESSFULLY\n")
cat("===========================================================================\n\n")

cat("--- Execution Summary ---\n")
cat(sprintf("  Total runtime: %.1f minutes (%.1f hours)\n",
            script_duration, script_duration/60))
cat(sprintf("  Start time: %s\n", script_start_time))
cat(sprintf("  End time: %s\n\n", Sys.time()))

cat("--- Models Run ---\n")
cat(sprintf("  Historical (1863-1934): %d models\n",
            sum(!sapply(hist_results, is.null))))
cat(sprintf("  Modern (1959-2024)): %d models\n",
            sum(!sapply(modern_results, is.null))))
cat(sprintf("  National Banking (1863-1904): %d models\n",
            sum(!sapply(nb_results, is.null))))
cat(sprintf("  Early Fed (1914-1928): %d models\n",
            sum(!sapply(ef_results, is.null))))
cat(sprintf("  Great Depression (1929-1934): %d models\n",
            sum(!sapply(gd_results, is.null))))
cat(sprintf("  TOTAL: %d models\n\n",
            sum(!sapply(hist_results, is.null)) +
            sum(!sapply(modern_results, is.null)) +
            sum(!sapply(nb_results, is.null)) +
            sum(!sapply(ef_results, is.null)) +
            sum(!sapply(gd_results, is.null))))

cat("--- Outputs Created ---\n")
cat(sprintf("  Prediction files: %d (RDS + DTA + CSV formats)\n", n_files_saved))
cat("  Regression coefficient tables: Multiple CSV files in output/tables/\n")
cat("  AUC summary tables: 2 (Table 1, Table B.15) - CSV format\n")
cat("  ROC curve plots: 2 (Figure 7A, Figure 7B)\n\n")

cat("--- Key Files ---\n")
cat(sprintf("  %s\n", file.path(tempfiles_dir, "table1_auc_summary.csv")))
cat(sprintf("  %s\n", file.path(tempfiles_dir, "table_auc_all_periods.csv")))
cat(sprintf("  %s\n", file.path(figures_dir, "figure7a_roc_historical.pdf")))
cat(sprintf("  %s\n\n", file.path(figures_dir, "figure7b_roc_modern.pdf")))

cat("--- Next Steps ---\n")
cat("  → Script 52: AUC with GLM (logistic regression)\n")
cat("  → Script 53: AUC by bank size quartiles\n")
cat("  → Script 54: TPR/FPR curve analysis\n")
cat("  → Script 55: Precision-Recall AUC\n\n")

cat("===========================================================================\n\n")
