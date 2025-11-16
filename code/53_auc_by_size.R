# ===========================================================================
# Script 53: AUC Analysis by Bank Size - Linear Probability Models
# ===========================================================================
# This script stratifies the AUC analysis by bank size quintiles.
# For each size category (smallest to largest), it runs the same LPM models
# as Script 51 but restricted to that size quintile.
#
# v2.5 enhancements:
# - Verbose console diagnostics throughout
# - Detailed progress tracking
# - Asset-based quintiles calculated by year
# ===========================================================================

cat("===========================================================================\n")
cat("SCRIPT 53: AUC ANALYSIS BY BANK SIZE QUINTILES\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
script_start_time <- Sys.time()

# --- Load Required Libraries ---
cat("\n[Loading Libraries]\n")
suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(haven)
  library(sandwich)
  library(lmtest)
  library(pROC)
  library(ggplot2)
})
cat("  ✓ All libraries loaded successfully\n")

# --- Define Paths ---
sources_dir <- here::here("sources")
dataclean_dir <- here::here("dataclean")
tempfiles_dir <- here::here("tempfiles")
output_dir <- here::here("output")

cat(sprintf("\n[Paths]\n"))
cat(sprintf("  Sources:   %s\n", sources_dir))
cat(sprintf("  Dataclean: %s\n", dataclean_dir))
cat(sprintf("  Tempfiles: %s\n", tempfiles_dir))
cat(sprintf("  Output:    %s\n", output_dir))

# ===========================================================================
# HELPER FUNCTION: Run Model for Specific Size Category
# ===========================================================================

RunModelBySize <- function(data, model_id, lhs, rhs, start_year, max_end_year,
                           size_cat, min_window = 10, DK_lag = 2) {
  cat(sprintf("\n=== Size Quintile %d: Model %d ===\n", size_cat, model_id))
  cat(sprintf("    Formula: %s ~ %s\n", lhs, rhs))
  cat(sprintf("    Period: %d-%d\n", start_year, max_end_year + 1))

  # Filter to size category
  data_size <- data %>% filter(size_cat == !!size_cat)

  cat(sprintf("    Observations in quintile %d: %d\n", size_cat, nrow(data_size)))
  cat(sprintf(
    "    Banks in quintile %d: %d\n", size_cat,
    n_distinct(data_size$bank_id, na.rm = TRUE)
  ))

  if (nrow(data_size) < 50) {
    cat("    ⚠ WARNING: Insufficient observations, skipping this quintile\n")
    return(NULL)
  }
  # Filter out Inf values in predictor variables (critical for historical Q4)
  cat("    [Cleaning Inf values]
")
  n_before <- nrow(data_size)
  
  # Get all numeric columns used in regression
  numeric_cols <- c("noncore_ratio", "surplus_ratio", "income_ratio", "profit_shortfall",
                    "emergency_borrowing", "loan_ratio", "leverage", "log_age",
                    "gdp_growth_3years", "inf_cpi_3years")
  
  for (col in numeric_cols) {
    if (col %in% names(data_size)) {
      n_inf <- sum(is.infinite(data_size[[col]]), na.rm = TRUE)
      if (n_inf > 0) {
        cat(sprintf("      Removing %d Inf values from %s
", n_inf, col))
        data_size <- data_size %>% filter(!is.infinite(.data[[col]]))
      }
    }
  }
  
  n_removed <- n_before - nrow(data_size)
  if (n_removed > 0) {
    cat(sprintf("    Removed %d rows with Inf values (%.1f%%)
",
                n_removed, 100 * n_removed / n_before))
    cat(sprintf("    Remaining observations: %d
", nrow(data_size)))
  } else {
    cat("    No Inf values found
")
  }
  
  # Check if still enough data after cleaning
  if (nrow(data_size) < 50) {
    cat("    WARNING: Insufficient observations after cleaning, skipping
")
    return(NULL)
  }



  # Step 1: Full-sample regression
  cat("\n  [Step 1/4] Running full-sample regression...\n")

  model_start <- Sys.time()

  formula_str <- paste0(lhs, " ~ ", rhs)
  
  # Run OLS with error handling for invalid data
  model_full <- tryCatch({
    lm(as.formula(formula_str), data = data_size, na.action = na.omit)
  }, error = function(e) {
    if (grepl("NA/NaN/Inf", e$message)) {
      cat("    WARNING: Data contains Inf values - skipping this quintile
")
      return(NULL)
    }
    stop(e)  # Re-throw other errors
  })
  
  # Check if model failed
  if (is.null(model_full)) {
    return(NULL)
  }

  # Driscoll-Kraay standard errors (approximated with Newey-West)
  vcov_dk <- NeweyWest(model_full, lag = DK_lag, prewhite = FALSE)
  coef_test <- coeftest(model_full, vcov = vcov_dk)

  # Use model.frame() to get actual observations used
  model_obs <- model.frame(model_full)
  n_obs <- nrow(model_obs)

  cat(sprintf("    Coefficients: %d\n", length(coef(model_full))))
  cat(sprintf("    R-squared: %.4f\n", summary(model_full)$r.squared))
  cat(sprintf("    Observations used: %d\n", n_obs))

  # Step 2: In-sample predictions
  cat("\n  [Step 2/4] Generating in-sample predictions...\n")

  data_size <- data_size %>%
    mutate(pred_insample = predict(model_full, newdata = data_size))

  cat(sprintf(
    "    Predictions generated: %d\n",
    sum(!is.na(data_size$pred_insample))
  ))

  # Step 3: Rolling out-of-sample predictions
  cat("\n  [Step 3/4] Running rolling out-of-sample predictions...\n")
  cat(sprintf("    Training window: %d years minimum\n", min_window))

  data_size <- data_size %>%
    mutate(pred_oos = NA_real_)

  oos_count <- 0

  for (end_year in start_year:(max_end_year - 1)) {
    train_years <- start_year:end_year
    test_year <- end_year + 1

    # Check if we have minimum window
    if (length(train_years) < min_window) next

    # Check if test year exists
    if (!any(data_size$year == test_year, na.rm = TRUE)) next

    # Train model - training sample: start_year to end_year (inclusive, matches Stata)
    data_train <- data_size %>% filter(year >= start_year & year <= end_year)

    if (nrow(data_train) < 20) next # Need minimum observations

    # Fit model - let lm() handle missing values (matches Stata)
    model_oos <- tryCatch(
      {
        lm(as.formula(formula_str), data = data_train, na.action = na.omit)
      },
      error = function(e) NULL
    )

    if (is.null(model_oos)) next

    # Predict on test year
    data_test <- data_size %>% filter(year == test_year)

    if (nrow(data_test) > 0) {
      preds_oos <- predict(model_oos, newdata = data_test)
      data_size$pred_oos[data_size$year == test_year] <- preds_oos
      oos_count <- oos_count + 1
    }
  }

  cat(sprintf("    Out-of-sample windows completed: %d\n", oos_count))
  cat(sprintf(
    "    OOS predictions generated: %d\n",
    sum(!is.na(data_size$pred_oos))
  ))

  # Step 4: Calculate AUC
  cat("\n  [Step 4/4] Calculating AUC...\n")

  # In-sample AUC
  valid_insample <- data_size %>%
    filter(!is.na(.data[[lhs]]), !is.na(pred_insample))

  if (nrow(valid_insample) > 0 &&
    length(unique(valid_insample[[lhs]])) > 1) {
    roc_insample <- roc(valid_insample[[lhs]], valid_insample$pred_insample,
      direction = "<", quiet = TRUE
    )
    auc_insample <- as.numeric(auc(roc_insample))
  } else {
    auc_insample <- NA_real_
  }

  # Out-of-sample AUC
  valid_oos <- data_size %>%
    filter(!is.na(.data[[lhs]]), !is.na(pred_oos))

  if (nrow(valid_oos) > 0 &&
    length(unique(valid_oos[[lhs]])) > 1) {
    roc_oos <- roc(valid_oos[[lhs]], valid_oos$pred_oos,
      direction = "<", quiet = TRUE
    )
    auc_oos <- as.numeric(auc(roc_oos))
  } else {
    auc_oos <- NA_real_
  }

  cat(sprintf("    ✓ AUC in-sample:      %.4f\n", auc_insample))
  cat(sprintf("    ✓ AUC out-of-sample:  %.4f\n", auc_oos))

  # Export regression coefficient table as CSV
  coef_full <- coef(model_full)
  se_dk <- sqrt(diag(vcov_dk))
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

  period_name <- ifelse(start_year >= 1863 & max_end_year <= 1934, "historical",
    ifelse(start_year >= 1959 & max_end_year <= 2024, "modern", "other")
  )
  tables_dir <- file.path(output_dir, "tables")
  reg_csv_file <- file.path(tables_dir, sprintf(
    "regression_size_model_%d_quintile_%d_%s.csv",
    model_id, size_cat, period_name
  ))
  write.csv(coef_table, reg_csv_file, row.names = FALSE)
  cat(sprintf("    ✓ Regression table exported: %s\n", basename(reg_csv_file)))

  # Summary statistics
  n_banks <- n_distinct(data_size$bank_id, na.rm = TRUE)
  mean_dep <- mean(data_size[[lhs]], na.rm = TRUE) * 100

  model_end <- Sys.time()
  duration <- as.numeric(difftime(model_end, model_start, units = "mins"))

  cat(sprintf("    ✓ Model completed in %.2f minutes\n", duration))

  # Return results
  list(
    model_id = model_id,
    size_cat = size_cat,
    auc_insample = auc_insample,
    auc_oos = auc_oos,
    n_banks = n_banks,
    n_obs = n_obs,
    mean_dep = mean_dep,
    data_with_preds = data_size
  )
}

# ===========================================================================
# PART 1: DATA LOADING
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 1: DATA LOADING\n")
cat("===========================================================================\n")

cat("\nLoading temp_reg_data.rds...\n")
data_full <- readRDS(file.path(tempfiles_dir, "temp_reg_data.rds"))

cat(sprintf("  Loaded: %d observations\n", nrow(data_full)))
cat(sprintf("  Banks: %d\n", n_distinct(data_full$bank_id, na.rm = TRUE)))
cat(sprintf(
  "  Years: %d to %d\n", min(data_full$year, na.rm = TRUE),
  max(data_full$year, na.rm = TRUE)
))

# ===========================================================================
# PART 2: HISTORICAL SAMPLE BY SIZE (1863-1934)
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 2: HISTORICAL SAMPLE ANALYSIS BY SIZE QUINTILES (1863-1934)\n")
cat("===========================================================================\n")

cat("\n[Preparing Historical Sample]\n")

data_hist <- data_full %>%
  filter(
    age >= 3,
    year >= 1863,
    year <= 1934
  )

cat(sprintf("  After age >= 3 filter: %d observations\n", nrow(data_hist)))
cat(sprintf("  Banks: %d\n", n_distinct(data_hist$bank_id, na.rm = TRUE)))

# Create size quintiles by year based on assets
cat("\n[Creating Size Quintiles by Year]\n")

data_hist <- data_hist %>%
  group_by(year) %>%
  mutate(size_cat = ntile(assets, 5)) %>%
  ungroup()

cat("  ✓ Size quintiles created\n")

# Show distribution
size_dist <- data_hist %>%
  group_by(size_cat) %>%
  summarise(
    n_obs = n(),
    n_banks = n_distinct(bank_id),
    mean_assets = mean(assets, na.rm = TRUE),
    .groups = "drop"
  )

cat("\n  Size Quintile Distribution:\n")
for (i in 1:5) {
  row <- size_dist[i, ]
  cat(sprintf(
    "    Q%d: %6d obs | %4d banks | Mean assets: $%.0f\n",
    i, row$n_obs, row$n_banks, row$mean_assets
  ))
}

# Define model specification (same as Script 51)
cat("\n[Running Historical Models by Size]\n")

# Main model: interaction of funding and solvency + controls
rhs_hist <- paste(
  "noncore_ratio * (surplus_ratio + profit_shortfall) +",
  "emergency_borrowing * (surplus_ratio + profit_shortfall) +",
  "loan_ratio + leverage + log_age +",
  "gdp_growth_3years + inf_cpi_3years"
)

results_hist <- list()

for (q in 1:5) {
  result <- RunModelBySize(
    data = data_hist,
    model_id = q,
    lhs = "F1_failure",
    rhs = rhs_hist,
    start_year = 1863,
    max_end_year = 1933,
    size_cat = q,
    min_window = 10,
    DK_lag = 2
  )

  if (!is.null(result)) {
    results_hist[[q]] <- result
  }
}

cat("\n  ✓ Historical analysis by size completed\n")

# ===========================================================================
# PART 3: MODERN SAMPLE BY SIZE (1959-2023)
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 3: MODERN SAMPLE ANALYSIS BY SIZE QUINTILES (1959-2023)\n")
cat("===========================================================================\n")

cat("\n[Preparing Modern Sample]\n")

data_mod <- data_full %>%
  filter(
    age >= 3,
    year >= 1959,
    year <= 2023,
    !is.na(income_ratio)
  ) # Modern period requires income_ratio

cat(sprintf("  After filters: %d observations\n", nrow(data_mod)))
cat(sprintf("  Banks: %d\n", n_distinct(data_mod$bank_id, na.rm = TRUE)))

# Create size quintiles by year based on assets
cat("\n[Creating Size Quintiles by Year]\n")

data_mod <- data_mod %>%
  group_by(year) %>%
  mutate(size_cat = ntile(assets, 5)) %>%
  ungroup()

cat("  ✓ Size quintiles created\n")

# Show distribution
size_dist_mod <- data_mod %>%
  group_by(size_cat) %>%
  summarise(
    n_obs = n(),
    n_banks = n_distinct(bank_id),
    mean_assets = mean(assets, na.rm = TRUE),
    .groups = "drop"
  )

cat("\n  Size Quintile Distribution:\n")
for (i in 1:5) {
  row <- size_dist_mod[i, ]
  cat(sprintf(
    "    Q%d: %6d obs | %4d banks | Mean assets: $%.0f\n",
    i, row$n_obs, row$n_banks, row$mean_assets
  ))
}

# Define model specification for modern period
cat("\n[Running Modern Models by Size]\n")

# Modern model: uses income_ratio instead of surplus_ratio
rhs_mod <- paste(
  "noncore_ratio * income_ratio +",
  "log_age +",
  "gdp_growth_3years + inf_cpi_3years"
)

results_mod <- list()

for (q in 1:5) {
  result <- RunModelBySize(
    data = data_mod,
    model_id = q,
    lhs = "F1_failure",
    rhs = rhs_mod,
    start_year = 1959,
    max_end_year = 2023,
    size_cat = q,
    min_window = 20,
    DK_lag = 2
  )

  if (!is.null(result)) {
    results_mod[[q]] <- result
  }
}

cat("\n  ✓ Modern analysis by size completed\n")

# ===========================================================================
# PART 4: SAVING RESULTS
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 4: SAVING RESULTS\n")
cat("===========================================================================\n")

# Save prediction datasets
cat("\n[Saving Prediction Files]\n")

# Historical predictions
for (q in 1:5) {
  if (!is.null(results_hist[[q]])) {
    filename <- sprintf("auc_by_size_hist_q%d_predictions.rds", q)
    saveRDS(
      results_hist[[q]]$data_with_preds,
      file.path(tempfiles_dir, filename)
    )
    # Also save as CSV
    csv_filename <- sprintf("auc_by_size_hist_q%d_predictions.csv", q)
    write.csv(
      results_hist[[q]]$data_with_preds,
      file.path(tempfiles_dir, csv_filename),
      row.names = FALSE
    )
    cat(sprintf("  ✓ Saved: %s + %s\n", filename, csv_filename))
  }
}

# Modern predictions
for (q in 1:5) {
  if (!is.null(results_mod[[q]])) {
    filename <- sprintf("auc_by_size_mod_q%d_predictions.rds", q)
    saveRDS(
      results_mod[[q]]$data_with_preds,
      file.path(tempfiles_dir, filename)
    )
    # Also save as CSV
    csv_filename <- sprintf("auc_by_size_mod_q%d_predictions.csv", q)
    write.csv(
      results_mod[[q]]$data_with_preds,
      file.path(tempfiles_dir, csv_filename),
      row.names = FALSE
    )
    cat(sprintf("  ✓ Saved: %s + %s\n", filename, csv_filename))
  }
}

# ===========================================================================
# PART 5: CREATING AUC SUMMARY TABLES
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 5: CREATING AUC SUMMARY TABLES\n")
cat("===========================================================================\n")

# Historical summary table
cat("\n[Historical Sample AUC by Size]\n")

hist_summary <- data.frame(
  Quintile = 1:5,
  AUC_InSample = sapply(1:5, function(q) {
    if (!is.null(results_hist[[q]])) results_hist[[q]]$auc_insample else NA
  }),
  AUC_OOS = sapply(1:5, function(q) {
    if (!is.null(results_hist[[q]])) results_hist[[q]]$auc_oos else NA
  }),
  N = sapply(1:5, function(q) {
    if (!is.null(results_hist[[q]])) results_hist[[q]]$n_obs else NA
  }),
  NBanks = sapply(1:5, function(q) {
    if (!is.null(results_hist[[q]])) results_hist[[q]]$n_banks else NA
  }),
  Mean_DepVar = sapply(1:5, function(q) {
    if (!is.null(results_hist[[q]])) results_hist[[q]]$mean_dep else NA
  })
)

print(hist_summary)

saveRDS(hist_summary, file.path(tempfiles_dir, "auc_by_size_historical_summary.rds"))
write_dta(hist_summary, file.path(tempfiles_dir, "auc_by_size_historical_summary.dta"))
write.csv(hist_summary, file.path(tempfiles_dir, "auc_by_size_historical_summary.csv"), row.names = FALSE)
cat("  ✓ Saved: auc_by_size_historical_summary.rds/.dta/.csv\n")

# Modern summary table
cat("\n[Modern Sample AUC by Size]\n")

mod_summary <- data.frame(
  Quintile = 1:5,
  AUC_InSample = sapply(1:5, function(q) {
    if (!is.null(results_mod[[q]])) results_mod[[q]]$auc_insample else NA
  }),
  AUC_OOS = sapply(1:5, function(q) {
    if (!is.null(results_mod[[q]])) results_mod[[q]]$auc_oos else NA
  }),
  N = sapply(1:5, function(q) {
    if (!is.null(results_mod[[q]])) results_mod[[q]]$n_obs else NA
  }),
  NBanks = sapply(1:5, function(q) {
    if (!is.null(results_mod[[q]])) results_mod[[q]]$n_banks else NA
  }),
  Mean_DepVar = sapply(1:5, function(q) {
    if (!is.null(results_mod[[q]])) results_mod[[q]]$mean_dep else NA
  })
)

print(mod_summary)

saveRDS(mod_summary, file.path(tempfiles_dir, "auc_by_size_modern_summary.rds"))
write_dta(mod_summary, file.path(tempfiles_dir, "auc_by_size_modern_summary.dta"))
write.csv(mod_summary, file.path(tempfiles_dir, "auc_by_size_modern_summary.csv"), row.names = FALSE)
cat("  ✓ Saved: auc_by_size_modern_summary.rds/.dta/.csv\n")

# ===========================================================================
# PART 6: CREATING VISUALIZATIONS
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 6: CREATING VISUALIZATIONS\n")
cat("===========================================================================\n")

# Plot AUC by size quintile - Historical
cat("\n[Creating Historical AUC by Size Plot]\n")

plot_hist <- ggplot(hist_summary, aes(x = Quintile)) +
  geom_line(aes(y = AUC_InSample, color = "In-Sample"), linewidth = 1) +
  geom_point(aes(y = AUC_InSample, color = "In-Sample"), size = 3) +
  geom_line(aes(y = AUC_OOS, color = "Out-of-Sample"), linewidth = 1) +
  geom_point(aes(y = AUC_OOS, color = "Out-of-Sample"), size = 3) +
  scale_x_continuous(breaks = 1:5, labels = c("Smallest", "2", "3", "4", "Largest")) +
  scale_color_manual(values = c("In-Sample" = "blue", "Out-of-Sample" = "red")) +
  labs(
    title = "AUC by Bank Size Quintile: Historical Sample (1863-1934)",
    x = "Bank Size Quintile",
    y = "AUC",
    color = "Sample Type"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(
  file.path(output_dir, "Figures", "auc_by_size_historical.pdf"),
  plot = plot_hist,
  width = 8,
  height = 6
)
cat("  ✓ Saved: Figures/auc_by_size_historical.pdf\n")

# Plot AUC by size quintile - Modern
cat("\n[Creating Modern AUC by Size Plot]\n")

plot_mod <- ggplot(mod_summary, aes(x = Quintile)) +
  geom_line(aes(y = AUC_InSample, color = "In-Sample"), linewidth = 1) +
  geom_point(aes(y = AUC_InSample, color = "In-Sample"), size = 3) +
  geom_line(aes(y = AUC_OOS, color = "Out-of-Sample"), linewidth = 1) +
  geom_point(aes(y = AUC_OOS, color = "Out-of-Sample"), size = 3) +
  scale_x_continuous(breaks = 1:5, labels = c("Smallest", "2", "3", "4", "Largest")) +
  scale_color_manual(values = c("In-Sample" = "blue", "Out-of-Sample" = "red")) +
  labs(
    title = "AUC by Bank Size Quintile: Modern Sample (1959-2023)",
    x = "Bank Size Quintile",
    y = "AUC",
    color = "Sample Type"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(
  file.path(output_dir, "Figures", "auc_by_size_modern.pdf"),
  plot = plot_mod,
  width = 8,
  height = 6
)
cat("  ✓ Saved: Figures/auc_by_size_modern.pdf\n")

# ===========================================================================
# PART 7: FINAL SUMMARY AND COMPLETION
# ===========================================================================

cat("\n===========================================================================\n")
cat("FINAL SUMMARY\n")
cat("===========================================================================\n")

script_end_time <- Sys.time()
script_duration <- as.numeric(difftime(script_end_time, script_start_time,
  units = "mins"
))

cat("\n[Historical Sample Results]\n")
cat(sprintf("  Models run: %d quintiles\n", sum(!sapply(results_hist, is.null))))
cat(sprintf(
  "  AUC range (in-sample): %.3f - %.3f\n",
  min(hist_summary$AUC_InSample, na.rm = TRUE),
  max(hist_summary$AUC_InSample, na.rm = TRUE)
))
cat(sprintf(
  "  AUC range (OOS): %.3f - %.3f\n",
  min(hist_summary$AUC_OOS, na.rm = TRUE),
  max(hist_summary$AUC_OOS, na.rm = TRUE)
))

cat("\n[Modern Sample Results]\n")
cat(sprintf("  Models run: %d quintiles\n", sum(!sapply(results_mod, is.null))))
cat(sprintf(
  "  AUC range (in-sample): %.3f - %.3f\n",
  min(mod_summary$AUC_InSample, na.rm = TRUE),
  max(mod_summary$AUC_InSample, na.rm = TRUE)
))
cat(sprintf(
  "  AUC range (OOS): %.3f - %.3f\n",
  min(mod_summary$AUC_OOS, na.rm = TRUE),
  max(mod_summary$AUC_OOS, na.rm = TRUE)
))

cat("\n===========================================================================\n")
cat("SCRIPT 53 COMPLETED SUCCESSFULLY\n")
cat(sprintf("  End time: %s\n", Sys.time()))
cat(sprintf("  Runtime: %.1f minutes\n", script_duration))
cat("===========================================================================\n")
