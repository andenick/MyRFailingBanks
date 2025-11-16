# ===========================================================================
# Script 52: AUC Analysis - Generalized Linear Models (Logistic Regression)
# ===========================================================================
#
# Purpose: Compare predictive power using GLM (logistic) vs LPM (Script 51)
#          Same model specifications as Script 51, but with logit link function
#
# Stata source: qje-repkit-to-upload/code/52_auc_glm.do (203 lines)
#               qje-repkit-to-upload/code/RunModelLogit.ado (74 lines)
#
# Key outputs:
# - Table B.6 Panel A & B: AUC metrics for GLM models
# - Prediction files for all periods (GLM vs LPM comparison)
#
# Methods:
# - Generalized Linear Models with binomial family and logit link
# - Rolling out-of-sample predictions (same as Script 51)
# - ROC curve analysis and AUC calculation
#
# v2.5: Full implementation with verbose diagnostics
# ===========================================================================

cat("\n")
cat("===========================================================================\n")
cat("SCRIPT 52: AUC ANALYSIS - LOGISTIC REGRESSION (GLM)\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
cat("===========================================================================\n\n")

script_start_time <- Sys.time()

# --- Load Environment ---
cat("--- Loading Environment ---\n")
source(here::here("code", "00_setup.R"))

cat("  Loading required packages...\n")
library(pROC)
cat("  ✓ Packages loaded\n\n")

# ===========================================================================
# HELPER FUNCTION: RunModelLogit (Stata: RunModelLogit.ado)
# ===========================================================================

RunModelLogit <- function(data, model_id, lhs, rhs, start_year, max_end_year,
                          min_window = 10) {
  cat(sprintf("\n=== GLM Model %d: %s ~ %s ===\n", model_id, lhs, rhs))
  cat(sprintf(
    "  Sample: %d-%d | Min window: %d years\n",
    start_year, max_end_year, min_window
  ))

  model_start_time <- Sys.time()

  # --- 1. Full-sample regression ---
  cat("\n  [Step 1/3] Running full-sample GLM...\n")

  formula_str <- paste0(lhs, " ~ ", rhs)
  cat(sprintf("    Formula: %s\n", formula_str))

  # Run GLM - let glm() handle missing values via listwise deletion (matches Stata behavior)
  model_full <- glm(as.formula(formula_str),
    data = data,
    family = binomial(link = "logit"),
    na.action = na.omit
  )

  # Statistics - use model.frame() to get actual observations used
  model_obs <- model.frame(model_full)
  n_obs <- nrow(model_obs)

  # Get bank_id from original data for observations used in model
  model_data_indices <- attr(model_obs, "row.names")
  if (is.character(model_data_indices)) {
    model_data_indices <- as.integer(model_data_indices)
  }
  model_bank_ids <- data$bank_id[model_data_indices]
  n_banks <- n_distinct(model_bank_ids)
  mean_outcome <- mean(model_obs[[lhs]], na.rm = TRUE) * 100

  cat(sprintf(
    "    Observations: %d | Banks: %d | Mean: %.3f%%\n",
    n_obs, n_banks, mean_outcome
  ))
  cat(sprintf("    Converged: %s\n", ifelse(model_full$converged, "Yes", "No")))

  # In-sample predictions (predicted probabilities)
  # Generate predictions for ALL observations (matches Stata behavior)
  data$pred_insample <- predict(model_full, newdata = data, type = "response")
  # Count predictions that are non-missing AND have non-missing outcome
  valid_preds <- sum(!is.na(data$pred_insample) & !is.na(data[[lhs]]))
  cat(sprintf("    In-sample predictions: %d\n", valid_preds))

  # --- 2. Rolling OOS predictions ---
  cat("\n  [Step 2/3] Running rolling OOS predictions...\n")

  data$pred_oos <- NA_real_

  n_oos <- 0
  for (end_year in start_year:max_end_year) {
    window <- end_year - start_year + 1
    if (window < min_window) next

    # Training sample: start_year to end_year (inclusive, matches Stata)
    train_data <- data %>% filter(year >= start_year & year <= end_year)
    # Test sample: year == end_year + 1 (predictions for next year)
    test_data <- data %>% filter(year == end_year + 1)

    if (nrow(train_data) == 0 || nrow(test_data) == 0) next

    # Fit model on training data - let glm() handle missing values (matches Stata)
    model_oos <- tryCatch(
      {
        glm(as.formula(formula_str),
          data = train_data,
          family = binomial(link = "logit"),
          na.action = na.omit,
          control = glm.control(maxit = 50)
        )
      },
      error = function(e) {
        cat(sprintf("      Warning: GLM failed for year %d\n", end_year))
        return(NULL)
      }
    )

    if (is.null(model_oos) || !model_oos$converged) next

    pred_oos <- tryCatch(
      {
        predict(model_oos, newdata = test_data, type = "response")
      },
      error = function(e) NULL
    )

    if (!is.null(pred_oos)) {
      data$pred_oos[data$year == end_year + 1] <- pred_oos
      n_oos <- n_oos + length(pred_oos)
    }

    if (end_year %% 10 == 0) {
      cat(sprintf("      Year %d: %d predictions so far\n", end_year, n_oos))
    }
  }

  cat(sprintf("    Total OOS predictions: %d\n", n_oos))

  # --- 3. Calculate AUC ---
  cat("\n  [Step 3/3] Calculating AUC...\n")

  # Check if response has both levels (0 and 1) - needed for ROC calculation
  insample_valid <- !is.na(data[[lhs]]) & !is.na(data$pred_insample)
  insample_outcomes <- unique(data[[lhs]][insample_valid])

  if (length(insample_outcomes) < 2) {
    cat(sprintf(
      "    [WARN] Warning: Response has only %d unique value(s) - cannot calculate ROC
",
      length(insample_outcomes)
    ))
    roc_insample <- NULL
    auc_insample <- NA_real_
  } else {
    roc_insample <- roc(data[[lhs]], data$pred_insample, quiet = TRUE, direction = "<")
    auc_insample <- as.numeric(auc(roc_insample))
  }

  oos_valid <- !is.na(data$pred_oos) & !is.na(data[[lhs]])
  if (sum(oos_valid) > 10) {
    # Check if OOS response has both levels
    oos_outcomes <- unique(data[[lhs]][oos_valid])

    if (length(oos_outcomes) < 2) {
      cat(sprintf(
        "    [WARN] Warning: OOS response has only %d unique value(s) - cannot calculate ROC
",
        length(oos_outcomes)
      ))
      roc_oos <- NULL
      auc_oos <- NA_real_
    } else {
      roc_oos <- roc(data[[lhs]][oos_valid], data$pred_oos[oos_valid],
        quiet = TRUE, direction = "<"
      )
      auc_oos <- as.numeric(auc(roc_oos))
    }
  } else {
    roc_oos <- NULL
    auc_oos <- NA_real_
  }

  cat(sprintf("    ✓ AUC in-sample: %.4f\n", auc_insample))
  if (!is.na(auc_oos)) {
    cat(sprintf("    ✓ AUC out-of-sample: %.4f\n", auc_oos))
  }

  # --- Export regression coefficient table as CSV ---
  coef_full <- coef(model_full)
  se_full <- sqrt(diag(vcov(model_full)))
  t_stats <- coef_full / se_full
  p_values <- 2 * pnorm(-abs(t_stats))
  ci_lower <- coef_full - 1.96 * se_full
  ci_upper <- coef_full + 1.96 * se_full

  coef_table <- data.frame(
    variable = names(coef_full),
    coefficient = coef_full,
    std_error = se_full,
    z_statistic = t_stats,
    p_value = p_values,
    ci_lower_95 = ci_lower,
    ci_upper_95 = ci_upper,
    row.names = NULL
  )

  period_name <- ifelse(start_year >= 1863 & max_end_year <= 1934, "historical",
    ifelse(start_year >= 1959 & max_end_year <= 2024, "modern",
      ifelse(start_year >= 1863 & max_end_year <= 1904, "nb",
        ifelse(start_year >= 1914 & max_end_year <= 1928, "ef", "gd")
      )
    )
  )
  reg_csv_file <- file.path(tables_dir, sprintf("regression_glm_model_%d_%s.csv", model_id, period_name))
  write.csv(coef_table, reg_csv_file, row.names = FALSE)
  cat(sprintf("    ✓ Regression table exported: %s\n", basename(reg_csv_file)))

  # Predictions dataset
  pred_data <- data %>%
    select(bank_id, year, quarters_to_failure,
      outcome = all_of(lhs),
      pred_insample, pred_oos
    ) %>%
    filter(!is.na(pred_insample) | !is.na(pred_oos)) %>%
    mutate(
      model_id = model_id,
      model_type = 2, # 2 = GLM
      smp_start = start_year,
      smp_end = max_end_year
    )

  duration <- as.numeric(difftime(Sys.time(), model_start_time, units = "mins"))
  cat(sprintf("    ✓ Model %d completed in %.2f minutes\n", model_id, duration))

  return(list(
    model_full = model_full,
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
# 1. LOAD DATA & DEFINE VARIABLES
# ===========================================================================

cat("===========================================================================\n")
cat("PART 1: DATA LOADING\n")
cat("===========================================================================\n\n")

cat("--- Loading Data ---\n")
reg_data <- haven::read_dta(file.path(tempfiles_dir, "temp_reg_data.dta"))

cat(sprintf(
  "  Observations: %d | Banks: %d\n",
  nrow(reg_data), n_distinct(reg_data$bank_id)
))
cat(sprintf("  Year range: %d-%d\n\n", min(reg_data$year), max(reg_data$year)))

# Clean data types from Stata import
cat("--- Cleaning Data Types ---\n")
labelled_vars <- names(reg_data)[sapply(reg_data, haven::is.labelled)]
if (length(labelled_vars) > 0) {
  cat(sprintf("  Converting %d haven_labelled variables to numeric\n", length(labelled_vars)))
  reg_data <- reg_data %>%
    mutate(across(where(haven::is.labelled), as.numeric))
}
if ("growth_cat" %in% names(reg_data) && !is.factor(reg_data$growth_cat)) {
  reg_data <- reg_data %>% mutate(growth_cat = factor(growth_cat))
  cat("  ✓ Converted growth_cat to factor\n")
}
cat("  ✓ Data types cleaned\n\n")
# Variable specifications (same as Script 51)
solvency_hist <- "surplus_ratio"
funding_hist <- "noncore_ratio"
solvency_mod <- "income_ratio"
funding_mod <- "noncore_ratio"

# ===========================================================================
# 2. HISTORICAL SAMPLE (1863-1934)
# ===========================================================================

cat("===========================================================================\n")
cat("PART 2: HISTORICAL SAMPLE GLM MODELS (1863-1934)\n")
cat("===========================================================================\n")

hist_data <- reg_data %>% filter(year >= 1863 & year <= 1934)
cat(sprintf("\n  Sample: %d obs | %d banks\n\n", nrow(hist_data), n_distinct(hist_data$bank_id)))

hist_results <- list()

cat("--- Running Historical GLM Models ---\n")

hist_results[[1]] <- RunModelLogit(
  hist_data, 1, "F1_failure",
  paste0(solvency_hist, " + log_age"), 1863, 1934, 10
)

hist_results[[2]] <- RunModelLogit(
  hist_data, 2, "F1_failure",
  paste0(funding_hist, " + log_age"), 1863, 1934, 10
)

hist_results[[3]] <- RunModelLogit(
  hist_data, 3, "F1_failure",
  paste0(funding_hist, " * ", solvency_hist, " + log_age"), 1863, 1934, 10
)

hist_results[[4]] <- RunModelLogit(
  hist_data, 4, "F1_failure",
  paste0(funding_hist, " * ", solvency_hist, " + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years"),
  1863, 1934, 10
)

if ("F1_failure_run" %in% names(hist_data)) {
  hist_results[[5]] <- RunModelLogit(
    hist_data, 5, "F1_failure_run",
    paste0(funding_hist, " * ", solvency_hist, " + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years"),
    1880, 1934, 10
  )
}

if ("F3_failure" %in% names(hist_data)) {
  hist_results[[7]] <- RunModelLogit(
    hist_data, 7, "F3_failure",
    paste0(funding_hist, " * ", solvency_hist, " + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years"),
    1863, 1934, 10
  )
}

if ("F5_failure" %in% names(hist_data)) {
  hist_results[[8]] <- RunModelLogit(
    hist_data, 8, "F5_failure",
    paste0(funding_hist, " * ", solvency_hist, " + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years"),
    1863, 1934, 10
  )
}

cat(sprintf("\n✓ Historical GLM completed: %d models\n\n", sum(!sapply(hist_results, is.null))))

# ===========================================================================
# 3. MODERN SAMPLE (1959-2023)
# ===========================================================================

cat("===========================================================================\n")
cat("PART 3: MODERN SAMPLE GLM MODELS (1959-2023)\n")
cat("===========================================================================\n")

modern_data <- reg_data %>%
  filter(year >= 1959 & year <= 2023) %>%
  filter(!is.na(income_ratio))

cat(sprintf("\n  Sample: %d obs | %d banks\n\n", nrow(modern_data), n_distinct(modern_data$bank_id)))

modern_results <- list()

cat("--- Running Modern GLM Models ---\n")

modern_results[[1]] <- RunModelLogit(
  modern_data, 1, "F1_failure",
  paste0(solvency_mod, " + log_age"), 1959, 2023, 10
)

modern_results[[2]] <- RunModelLogit(
  modern_data, 2, "F1_failure",
  paste0(funding_mod, " + log_age"), 1959, 2023, 10
)

modern_results[[3]] <- RunModelLogit(
  modern_data, 3, "F1_failure",
  paste0(funding_mod, " * ", solvency_mod, " + log_age"), 1959, 2023, 10
)

modern_results[[4]] <- RunModelLogit(
  modern_data, 4, "F1_failure",
  paste0(funding_mod, " * ", solvency_mod, " + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years"),
  1959, 2023, 10
)

if ("F1_failure_run" %in% names(modern_data)) {
  modern_results[[5]] <- RunModelLogit(
    modern_data, 5, "F1_failure_run",
    paste0(funding_mod, " * ", solvency_mod, " + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years"),
    1993, 2023, 10
  )
}

if ("F3_failure" %in% names(modern_data)) {
  modern_results[[7]] <- RunModelLogit(
    modern_data, 7, "F3_failure",
    paste0(funding_mod, " * ", solvency_mod, " + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years"),
    1959, 2023, 10
  )
}

if ("F5_failure" %in% names(modern_data)) {
  modern_results[[8]] <- RunModelLogit(
    modern_data, 8, "F5_failure",
    paste0(funding_mod, " * ", solvency_mod, " + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years"),
    1959, 2023, 10
  )
}

cat(sprintf("\n✓ Modern GLM completed: %d models\n\n", sum(!sapply(modern_results, is.null))))

# ===========================================================================
# 4. GRANULAR PERIODS (1863-1904, 1914-1928, 1929-1934)
# ===========================================================================

cat("===========================================================================\n")
cat("PART 4: GRANULAR PERIOD GLM MODELS\n")
cat("===========================================================================\n\n")

# National Banking (1863-1904)
cat("--- National Banking Era (1863-1904) ---\n")
nb_data <- reg_data %>% filter(year >= 1863 & year <= 1904)
cat(sprintf("  Sample: %d obs\n", nrow(nb_data)))

nb_results <- list()
nb_results[[4]] <- RunModelLogit(
  nb_data, 4, "F1_failure",
  "emergency_borrowing * surplus_ratio + emergency_borrowing * profit_shortfall + loan_ratio + leverage + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years",
  1863, 1904, 10
)

# Early Fed (1914-1928)
cat("\n--- Early Federal Reserve (1914-1928) ---\n")
ef_data <- reg_data %>% filter(year >= 1914 & year <= 1928)
cat(sprintf("  Sample: %d obs\n", nrow(ef_data)))

ef_results <- list()
ef_results[[4]] <- RunModelLogit(
  ef_data, 4, "F1_failure",
  "noncore_ratio * surplus_ratio + loan_ratio + leverage + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years",
  1914, 1928, 10
)

# Great Depression (1929-1934) - train on 1880-1928, test 1929-1934
cat("\n--- Great Depression (1929-1934) ---\n")
gd_data <- reg_data %>% filter(year >= 1880 & year <= 1934)
cat(sprintf("  Sample: %d obs (training 1880-1928, testing 1929-1934)\n", nrow(gd_data)))

gd_results <- list()
gd_results[[4]] <- RunModelLogit(
  gd_data, 4, "F1_failure",
  "emergency_borrowing * surplus_ratio + emergency_borrowing * profit_shortfall + loan_ratio + leverage + log_age + growth_cat + gdp_growth_3years + inf_cpi_3years",
  1880, 1934, 10
)

cat("\n✓ Granular periods GLM completed\n\n")

# ===========================================================================
# 5. SAVE PREDICTIONS
# ===========================================================================

cat("===========================================================================\n")
cat("PART 5: SAVING PREDICTION FILES\n")
cat("===========================================================================\n\n")

n_saved <- 0

cat("--- Saving Historical Predictions ---\n")
for (i in seq_along(hist_results)) {
  if (!is.null(hist_results[[i]])) {
    saveRDS(
      hist_results[[i]]$pred_data,
      file.path(tempfiles_dir, sprintf("PV_GLM_%d_1863_1934.rds", i))
    )
    haven::write_dta(
      hist_results[[i]]$pred_data,
      file.path(tempfiles_dir, sprintf("PV_GLM_%d_1863_1934.dta", i))
    )
    write.csv(
      hist_results[[i]]$pred_data,
      file.path(tempfiles_dir, sprintf("PV_GLM_%d_1863_1934.csv", i)),
      row.names = FALSE
    )
    n_saved <- n_saved + 3
    cat(sprintf("  ✓ Model %d saved (RDS + DTA + CSV)\n", i))
  }
}

cat("\n--- Saving Modern Predictions ---\n")
for (i in seq_along(modern_results)) {
  if (!is.null(modern_results[[i]])) {
    saveRDS(
      modern_results[[i]]$pred_data,
      file.path(tempfiles_dir, sprintf("PV_GLM_%d_1959_2023.rds", i))
    )
    haven::write_dta(
      modern_results[[i]]$pred_data,
      file.path(tempfiles_dir, sprintf("PV_GLM_%d_1959_2023.dta", i))
    )
    write.csv(
      modern_results[[i]]$pred_data,
      file.path(tempfiles_dir, sprintf("PV_GLM_%d_1959_2023.csv", i)),
      row.names = FALSE
    )
    n_saved <- n_saved + 3
    cat(sprintf("  ✓ Model %d saved (RDS + DTA + CSV)\n", i))
  }
}

cat("\n--- Saving Granular Period Predictions ---\n")
for (i in seq_along(nb_results)) {
  if (!is.null(nb_results[[i]])) {
    saveRDS(
      nb_results[[i]]$pred_data,
      file.path(tempfiles_dir, sprintf("PV_GLM_%d_1863_1904.rds", i))
    )
    haven::write_dta(
      nb_results[[i]]$pred_data,
      file.path(tempfiles_dir, sprintf("PV_GLM_%d_1863_1904.dta", i))
    )
    write.csv(
      nb_results[[i]]$pred_data,
      file.path(tempfiles_dir, sprintf("PV_GLM_%d_1863_1904.csv", i)),
      row.names = FALSE
    )
    n_saved <- n_saved + 3
  }
}

for (i in seq_along(ef_results)) {
  if (!is.null(ef_results[[i]])) {
    saveRDS(
      ef_results[[i]]$pred_data,
      file.path(tempfiles_dir, sprintf("PV_GLM_%d_1914_1928.rds", i))
    )
    haven::write_dta(
      ef_results[[i]]$pred_data,
      file.path(tempfiles_dir, sprintf("PV_GLM_%d_1914_1928.dta", i))
    )
    write.csv(
      ef_results[[i]]$pred_data,
      file.path(tempfiles_dir, sprintf("PV_GLM_%d_1914_1928.csv", i)),
      row.names = FALSE
    )
    n_saved <- n_saved + 3
  }
}

for (i in seq_along(gd_results)) {
  if (!is.null(gd_results[[i]])) {
    saveRDS(
      gd_results[[i]]$pred_data,
      file.path(tempfiles_dir, sprintf("PV_GLM_%d_1929_1934.rds", i))
    )
    haven::write_dta(
      gd_results[[i]]$pred_data,
      file.path(tempfiles_dir, sprintf("PV_GLM_%d_1929_1934.dta", i))
    )
    write.csv(
      gd_results[[i]]$pred_data,
      file.path(tempfiles_dir, sprintf("PV_GLM_%d_1929_1934.csv", i)),
      row.names = FALSE
    )
    n_saved <- n_saved + 3
  }
}

cat(sprintf("\n✓ Saved %d prediction files\n\n", n_saved))

# ===========================================================================
# 6. CREATE AUC TABLES
# ===========================================================================

cat("===========================================================================\n")
cat("PART 6: CREATING AUC SUMMARY TABLES\n")
cat("===========================================================================\n\n")

extract_auc <- function(results_list, period_name) {
  auc_df <- data.frame()
  for (i in seq_along(results_list)) {
    if (!is.null(results_list[[i]])) {
      stats <- results_list[[i]]$summary_stats
      auc_df <- rbind(auc_df, data.frame(
        period = period_name,
        model = stats$model_id,
        n_obs = stats$n_obs,
        n_banks = stats$n_banks,
        mean_outcome = stats$mean_outcome,
        auc_insample = stats$auc_insample,
        auc_oos = stats$auc_oos
      ))
    }
  }
  return(auc_df)
}

auc_hist <- extract_auc(hist_results, "Historical (1863-1934)")
auc_modern <- extract_auc(modern_results, "Modern (1959-2023)")

auc_table <- rbind(auc_hist, auc_modern)

write.csv(auc_table, file.path(tempfiles_dir, "table_b6_auc_glm.csv"), row.names = FALSE)

cat("✓ Table B.6 saved\n")
print(auc_table)

# ===========================================================================
# 7. COMPLETION
# ===========================================================================

script_duration <- as.numeric(difftime(Sys.time(), script_start_time, units = "mins"))

cat("\n===========================================================================\n")
cat("SCRIPT 52 COMPLETED SUCCESSFULLY\n")
cat("===========================================================================\n")
cat(sprintf("  Runtime: %.1f minutes\n", script_duration))
cat(sprintf("  Historical models: %d\n", sum(!sapply(hist_results, is.null))))
cat(sprintf("  Modern models: %d\n", sum(!sapply(modern_results, is.null))))
cat(sprintf(
  "  Granular models: %d\n",
  sum(!sapply(nb_results, is.null)) +
    sum(!sapply(ef_results, is.null)) +
    sum(!sapply(gd_results, is.null))
))
cat("  Next: Script 53 (AUC by bank size)\n")
cat("===========================================================================\n\n")
