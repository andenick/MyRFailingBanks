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
            nrow(data_full), n_distinct(data_full$bank_id)))

cat("
CREATING RATIO VARIABLES
")
cat("==========================
")

# Create ratio variables matching Stata Script 07
# log_age = log(age)
data_full$log_age <- log(data_full$age)
cat("  Created log_age
")

# surplus_ratio = surplus_profit/equity
data_full$surplus_ratio <- data_full$surplus_profit / data_full$equity
cat("  Created surplus_ratio
")

# noncore_ratio = res_funding/assets
data_full$noncore_ratio <- data_full$res_funding / data_full$assets
cat("  Created noncore_ratio
")

# income_ratio = ytdnetinc/assets
data_full$income_ratio <- data_full$ytdnetinc / data_full$assets
cat("  Created income_ratio
")

cat("
LOADING MACRO VARIABLES
")
cat("========================
")

# Load JST dataset for GDP and CPI data
jst_path <- here(sources_dir, "JST", "jst_cpi_crisis.dta")
if (file.exists(jst_path)) {
  jst_data <- read_dta(jst_path) %>%
    filter(iso == "USA") %>%
    arrange(year) %>%
    mutate(
      # Calculate 3-year GDP growth
      gdp_growth_3years = rgdppc / lag(rgdppc, 3) - 1,
      # Calculate 3-year CPI inflation
      inf_cpi_3years = cpi / lag(cpi, 3) - 1
    ) %>%
    select(year, gdp_growth_3years, inf_cpi_3years)
  
  # Merge with main data
  data_full <- data_full %>%
    left_join(jst_data, by = "year")
  
  cat("  Merged JST macro variables
")
  cat(sprintf("  GDP growth available: %d years
", sum(!is.na(data_full$gdp_growth_3years))))
  cat(sprintf("  CPI inflation available: %d years
", sum(!is.na(data_full$inf_cpi_3years))))
} else {
  warning("JST data not found - macro variables will be missing")
  data_full$gdp_growth_3years <- NA
  data_full$inf_cpi_3years <- NA
}
")

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
  n_banks <- n_distinct(data_period$bank_id[!is.na(fitted(model_full))])
  mean_outcome <- mean(data_period[[lhs]], na.rm = TRUE) * 100

  cat(sprintf("      N=%d, Banks=%d, Mean(Y)=%.2f%%\n", n_obs, n_banks, mean_outcome))

  # Step 2: In-sample predictions
  data_period$pred_is <- predict(model_full, newdata = data_period)

  # Step 3: Out-of-sample predictions (expanding window)
  cat("      Computing OOS predictions (expanding window)...\n")
  data_period$pred_oos <- NA_real_

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
        data_period$pred_oos[data_period$year == end_year + 1] <- predictions
      }
    }
  }

  # Step 4: Calculate AUC
  # In-sample AUC
  valid_is <- !is.na(data_period$pred_is) & !is.na(data_period[[lhs]])
  if (sum(valid_is) > 0 && length(unique(data_period[[lhs]][valid_is])) > 1) {
    roc_is <- roc(data_period[[lhs]][valid_is], data_period$pred_is[valid_is],
                  quiet = TRUE)
    auc_is <- as.numeric(auc(roc_is))
  } else {
    auc_is <- NA
  }

  # Out-of-sample AUC
  valid_oos <- !is.na(data_period$pred_oos) & !is.na(data_period[[lhs]])
  if (sum(valid_oos) > 0 && length(unique(data_period[[lhs]][valid_oos])) > 1) {
    roc_oos <- roc(data_period[[lhs]][valid_oos], data_period$pred_oos[valid_oos],
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

# ==========================================================================================
# HISTORICAL PERIOD (1863-1934)
# ==========================================================================================

cat("\n")
cat("===============================================================================\n")
cat("HISTORICAL PERIOD MODELS (1863-1934)\n")
cat("===============================================================================\n")

# Filter to historical period
hist_data <- data_full %>% filter(year >= 1863, year <= 1934)

# Model 1: F1_failure ~ surplus_ratio + log_age
m1_hist <- RunModelLPM(
  data = hist_data,
  model_id = 1,
  lhs = "F1_failure",
  rhs = "surplus_ratio + log_age",
  start_year = 1863,
  max_end_year = 1934,
  period_name = "historical"
)

# Model 2: F1_failure ~ noncore_ratio + log_age
m2_hist <- RunModelLPM(
  data = hist_data,
  model_id = 2,
  lhs = "F1_failure",
  rhs = "noncore_ratio + log_age",
  start_year = 1863,
  max_end_year = 1934,
  period_name = "historical"
)

# Model 3: F1_failure ~ noncore_ratio * surplus_ratio + log_age
m3_hist <- RunModelLPM(
  data = hist_data,
  model_id = 3,
  lhs = "F1_failure",
  rhs = "noncore_ratio * surplus_ratio + log_age",
  start_year = 1863,
  max_end_year = 1934,
  period_name = "historical"
)

# Model 4: F1_failure ~ noncore_ratio * surplus_ratio + log_age + controls
m4_hist <- RunModelLPM(
  data = hist_data,
  model_id = 4,
  lhs = "F1_failure",
  rhs = "noncore_ratio * surplus_ratio + log_age + relevel(factor(growth_cat), ref=\'3\') + gdp_growth_3years + inf_cpi_3years",
  start_year = 1863,
  max_end_year = 1934,
  period_name = "historical"
)

# Model 5: F1_failure_run ~ noncore_ratio * surplus_ratio + log_age + controls (starts 1880)
m5_hist <- RunModelLPM(
  data = hist_data,
  model_id = 5,
  lhs = "F1_failure_run",
  rhs = "noncore_ratio * surplus_ratio + log_age + relevel(factor(growth_cat), ref=\'3\') + gdp_growth_3years + inf_cpi_3years",
  start_year = 1880,
  max_end_year = 1934,
  period_name = "historical"
)

# Model 7: F3_failure ~ noncore_ratio * surplus_ratio + log_age + controls
m7_hist <- RunModelLPM(
  data = hist_data,
  model_id = 7,
  lhs = "F3_failure",
  rhs = "noncore_ratio * surplus_ratio + log_age + relevel(factor(growth_cat), ref=\'3\') + gdp_growth_3years + inf_cpi_3years",
  start_year = 1863,
  max_end_year = 1934,
  period_name = "historical"
)

# Model 8: F5_failure ~ noncore_ratio * surplus_ratio + log_age + controls
m8_hist <- RunModelLPM(
  data = hist_data,
  model_id = 8,
  lhs = "F5_failure",
  rhs = "noncore_ratio * surplus_ratio + log_age + relevel(factor(growth_cat), ref=\'3\') + gdp_growth_3years + inf_cpi_3years",
  start_year = 1863,
  max_end_year = 1934,
  period_name = "historical"
)

# ==========================================================================================
# MODERN PERIOD (1959-2023)
# ==========================================================================================

cat("\n")
cat("===============================================================================\n")
cat("MODERN PERIOD MODELS (1959-2023)\n")
cat("===============================================================================\n")

# Filter to modern period
modern_data <- data_full %>% filter(year >= 1959, year <= 2023)

# Model 1: F1_failure ~ income_ratio + log_age
m1_modern <- RunModelLPM(
  data = modern_data,
  model_id = 1,
  lhs = "F1_failure",
  rhs = "income_ratio + log_age",
  start_year = 1959,
  max_end_year = 2023,
  period_name = "modern"
)

# Model 2: F1_failure ~ noncore_ratio + log_age
m2_modern <- RunModelLPM(
  data = modern_data,
  model_id = 2,
  lhs = "F1_failure",
  rhs = "noncore_ratio + log_age",
  start_year = 1959,
  max_end_year = 2023,
  period_name = "modern"
)

# Model 3: F1_failure ~ noncore_ratio * income_ratio + log_age
m3_modern <- RunModelLPM(
  data = modern_data,
  model_id = 3,
  lhs = "F1_failure",
  rhs = "noncore_ratio * income_ratio + log_age",
  start_year = 1959,
  max_end_year = 2023,
  period_name = "modern"
)

# Model 4: F1_failure ~ noncore_ratio * income_ratio + log_age + controls
m4_modern <- RunModelLPM(
  data = modern_data,
  model_id = 4,
  lhs = "F1_failure",
  rhs = "noncore_ratio * income_ratio + log_age + relevel(factor(growth_cat), ref=\'3\') + gdp_growth_3years + inf_cpi_3years",
  start_year = 1959,
  max_end_year = 2023,
  period_name = "modern"
)

# Model 5: F1_failure_run ~ noncore_ratio * income_ratio + log_age + controls
m5_modern <- RunModelLPM(
  data = modern_data,
  model_id = 5,
  lhs = "F1_failure_run",
  rhs = "noncore_ratio * income_ratio + log_age + relevel(factor(growth_cat), ref=\'3\') + gdp_growth_3years + inf_cpi_3years",
  start_year = 1959,
  max_end_year = 2023,
  period_name = "modern"
)

# Model 7: F3_failure ~ noncore_ratio * income_ratio + log_age + controls
m7_modern <- RunModelLPM(
  data = modern_data,
  model_id = 7,
  lhs = "F3_failure",
  rhs = "noncore_ratio * income_ratio + log_age + relevel(factor(growth_cat), ref=\'3\') + gdp_growth_3years + inf_cpi_3years",
  start_year = 1959,
  max_end_year = 2023,
  period_name = "modern"
)

# Model 8: F5_failure ~ noncore_ratio * income_ratio + log_age + controls
m8_modern <- RunModelLPM(
  data = modern_data,
  model_id = 8,
  lhs = "F5_failure",
  rhs = "noncore_ratio * income_ratio + log_age + relevel(factor(growth_cat), ref=\'3\') + gdp_growth_3years + inf_cpi_3years",
  start_year = 1959,
  max_end_year = 2023,
  period_name = "modern"
)

# ==========================================================================================
# COMPILE RESULTS AND SAVE OUTPUT
# ==========================================================================================

cat("\n")
cat("===============================================================================\n")
cat("COMPILING RESULTS\n")
cat("===============================================================================\n")

# Collect all models
historical_models <- list(m1_hist, m2_hist, m3_hist, m4_hist, m5_hist, m7_hist, m8_hist)
modern_models <- list(m1_modern, m2_modern, m3_modern, m4_modern, m5_modern, m7_modern, m8_modern)

# Function to create AUC table
create_auc_table <- function(models, period_name, type = "oos") {
  auc_col <- if (type == "oos") "auc_oos" else "auc_is"

  results <- data.frame(
    model = sapply(models, function(m) m$model_id),
    auc = sapply(models, function(m) m[[auc_col]]),
    n_obs = sapply(models, function(m) m$n_obs),
    n_banks = sapply(models, function(m) m$n_banks),
    mean_outcome = sapply(models, function(m) m$mean_outcome)
  )

  # Save to CSV
  filename <- here(output_dir, sprintf("05_tab_auc_%s_%s.csv", type, period_name))
  write.csv(results, filename, row.names = FALSE)
  cat(sprintf("  Saved: %s\n", filename))

  results
}

# Generate tables
auc_oos_hist <- create_auc_table(historical_models, "historical", "oos")
auc_is_hist <- create_auc_table(historical_models, "historical", "is")
auc_oos_modern <- create_auc_table(modern_models, "modern", "oos")
auc_is_modern <- create_auc_table(modern_models, "modern", "is")

# ==========================================================================================
# COMPLETION
# ==========================================================================================

script_end_time <- Sys.time()
elapsed_time <- difftime(script_end_time, script_start_time, units = "mins")

cat("\n")
cat("===============================================================================\n")
cat("SCRIPT 51 COMPLETE\n")
cat("===============================================================================\n")
cat(sprintf("End time: %s\n", script_end_time))
cat(sprintf("Elapsed time: %.2f minutes\n", elapsed_time))
cat("===============================================================================\n\n")
