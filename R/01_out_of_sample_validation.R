# ===========================================================================
# Out-of-Sample Validation: Train/Test Split Analysis
# ===========================================================================
# Purpose: Validate 2000+ regression models using train/test split
#          Train: 2000-2019 (pre-COVID)
#          Test: 2020-2023 (COVID + 2023 regional bank crisis)
# Author: Claude Code
# Date: 2025-11-30
# ===========================================================================

library(tidyverse)
library(haven)
library(pROC)
library(lmtest)
library(sandwich)

cat("\n")
cat("===========================================================================\n")
cat("OUT-OF-SAMPLE VALIDATION: TRAIN/TEST SPLIT\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
cat("===========================================================================\n\n")

# ===========================================================================
# 1. LOAD DATA
# ===========================================================================

cat("Step 1: Loading modern period (2000+) data...\n\n")

# Try primary source first
data_path <- "D:/Arcanum/Projects/FailingBanks/Technical/data/comprehensive_comparison/correia_reg_modern.rds"

if (file.exists(data_path)) {
  cat(sprintf("  Loading from: %s\n", data_path))
  data_full <- readRDS(data_path)
  cat("  ✓ Data loaded successfully\n")
} else {
  # Fall back to temp_reg_data
  data_path <- "D:/Arcanum/Projects/FailingBanks/FailingBanks_Perfect_Replication_v7.0/dataclean/temp_reg_data.rds"

  if (file.exists(data_path)) {
    cat(sprintf("  Loading from: %s\n", data_path))
    data_full <- readRDS(data_path)
    cat("  ✓ Data loaded successfully (alternative source)\n")
  } else {
    # Last resort: try Stata file
    data_path <- "D:/Arcanum/Projects/FailingBanks/FailingBanks_v9.0_Clean/tempfiles/temp_reg_data.dta"

    if (file.exists(data_path)) {
      cat(sprintf("  Loading from: %s\n", data_path))
      data_full <- haven::read_dta(data_path)
      cat("  ✓ Data loaded successfully (Stata file)\n")
    } else {
      stop("ERROR: Could not find data file in any expected location")
    }
  }
}

# Filter to 2000+
data_modern <- data_full %>% filter(year >= 2000)

cat(sprintf("\n  Modern period data (2000+):\n"))
cat(sprintf("    Observations: %s\n", format(nrow(data_modern), big.mark=",")))
cat(sprintf("    Year range: %d - %d\n",
            min(data_modern$year),
            max(data_modern$year)))

# ===========================================================================
# 2. TRAIN/TEST SPLIT
# ===========================================================================

cat("\nStep 2: Creating train/test split...\n\n")

# Check failure distribution by year
failure_by_year <- data_modern %>%
  group_by(year) %>%
  summarise(
    n_obs = n(),
    n_failures = sum(F1_failure, na.rm = TRUE),
    failure_rate = mean(F1_failure, na.rm = TRUE) * 100,
    .groups = "drop"
  ) %>%
  arrange(year)

cat("  Failure distribution by year:\n")
print(failure_by_year, n = 24)

cat("\n  ⚠ NOTE: 2020-2023 has very few failures, using alternative split\n")
cat("  New split: Train 2000-2015, Test 2016-2023 (captures more failures)\n\n")

# TRAIN: 2000-2015 (includes 2008-2009 crisis + aftermath)
data_train <- data_modern %>% filter(year >= 2000 & year <= 2015)

# TEST: 2016-2023 (post-crisis period + 2023 regional bank failures)
data_test <- data_modern %>% filter(year >= 2016)

cat(sprintf("  TRAIN SET (2000-2015):\n"))
cat(sprintf("    Observations: %s\n", format(nrow(data_train), big.mark=",")))
cat(sprintf("    Failures: %s (%.2f%%)\n",
            format(sum(data_train$F1_failure, na.rm=TRUE), big.mark=","),
            mean(data_train$F1_failure, na.rm=TRUE) * 100))
cat(sprintf("    Years: %d - %d\n",
            min(data_train$year),
            max(data_train$year)))

cat(sprintf("\n  TEST SET (2016-2023):\n"))
cat(sprintf("    Observations: %s\n", format(nrow(data_test), big.mark=",")))
cat(sprintf("    Failures: %s (%.2f%%)\n",
            format(sum(data_test$F1_failure, na.rm=TRUE), big.mark=","),
            mean(data_test$F1_failure, na.rm=TRUE) * 100))
cat(sprintf("    Years: %d - %d\n",
            min(data_test$year),
            max(data_test$year)))

# ===========================================================================
# 3. DEFINE MODEL SPECIFICATIONS
# ===========================================================================

cat("\nStep 3: Defining model specifications...\n\n")

# Model specifications (same as original analysis)
specs <- list(
  spec1 = list(
    name = "Model 1: Solvency Only",
    formula_lpm = F1_failure ~ income_ratio + log_age,
    formula_logit = F1_failure ~ income_ratio + log_age
  ),
  spec2 = list(
    name = "Model 2: Funding Only",
    formula_lpm = F1_failure ~ noncore_ratio + log_age,
    formula_logit = F1_failure ~ noncore_ratio + log_age
  ),
  spec3 = list(
    name = "Model 3: Solvency x Funding Interaction",
    formula_lpm = F1_failure ~ income_ratio + noncore_ratio +
      income_ratio:noncore_ratio + log_age,
    formula_logit = F1_failure ~ income_ratio + noncore_ratio +
      income_ratio:noncore_ratio + log_age
  ),
  spec4 = list(
    name = "Model 4: Full with Growth Controls",
    formula_lpm = F1_failure ~ income_ratio + noncore_ratio +
      income_ratio:noncore_ratio + log_age +
      growth_cat + gdp_growth_3years + inf_cpi_3years,
    formula_logit = F1_failure ~ income_ratio + noncore_ratio +
      income_ratio:noncore_ratio + log_age +
      growth_cat + gdp_growth_3years + inf_cpi_3years
  )
)

cat(sprintf("  %d model specifications defined\n", length(specs)))

# ===========================================================================
# 4. ESTIMATE MODELS ON TRAIN DATA
# ===========================================================================

cat("\nStep 4: Estimating models on TRAIN data (2000-2019)...\n\n")

# Function to estimate a single model
estimate_model <- function(spec_name, spec_info, data, model_type) {

  formula <- if (model_type == "lpm") spec_info$formula_lpm else spec_info$formula_logit

  # Estimate model
  if (model_type == "lpm") {
    model <- lm(formula, data = data)
  } else if (model_type == "logit") {
    model <- glm(formula, data = data, family = binomial(link = "logit"))
  } else if (model_type == "probit") {
    formula_probit <- spec_info$formula_logit  # Same formula as logit
    model <- glm(formula_probit, data = data, family = binomial(link = "probit"))
  }

  return(model)
}

# Storage for models
models_train <- list()

# Estimate all 12 models (4 specs × 3 types)
for (i in seq_along(specs)) {
  spec_name <- names(specs)[i]
  spec_info <- specs[[i]]

  cat(sprintf("  Estimating %s...\n", spec_info$name))

  for (model_type in c("lpm", "logit", "probit")) {
    key <- paste0(spec_name, "_", model_type)

    models_train[[key]] <- estimate_model(
      spec_name = spec_name,
      spec_info = spec_info,
      data = data_train,
      model_type = model_type
    )
  }
}

cat(sprintf("\n  ✓ Estimated %d models on train data\n", length(models_train)))

# ===========================================================================
# 5. CALCULATE IN-SAMPLE AUC (TRAIN DATA)
# ===========================================================================

cat("\nStep 5: Calculating in-sample AUC on TRAIN data...\n\n")

# Function to calculate AUC
calculate_auc <- function(model, data) {
  # Get predictions
  if (inherits(model, "lm")) {
    # LPM: predictions are already probabilities (but may be <0 or >1)
    pred <- predict(model, newdata = data)
    pred <- pmax(0, pmin(1, pred))  # Truncate to [0, 1]
  } else {
    # Logit/Probit: use type="response" for probabilities
    pred <- predict(model, newdata = data, type = "response")
  }

  # Calculate AUC
  actual <- data$F1_failure

  # Remove NAs
  valid <- !is.na(actual) & !is.na(pred)
  actual <- actual[valid]
  pred <- pred[valid]

  roc_obj <- pROC::roc(actual, pred, direction = "<", quiet = TRUE)
  auc_value <- as.numeric(pROC::auc(roc_obj))

  return(auc_value)
}

# Calculate in-sample AUC for all models
auc_train <- tibble(
  spec = character(),
  spec_name = character(),
  model_type = character(),
  auc_train = numeric()
)

for (i in seq_along(specs)) {
  spec_name <- names(specs)[i]
  spec_info <- specs[[i]]

  for (model_type in c("lpm", "logit", "probit")) {
    key <- paste0(spec_name, "_", model_type)
    model <- models_train[[key]]

    auc_value <- calculate_auc(model, data_train)

    auc_train <- auc_train %>%
      add_row(
        spec = as.character(i),
        spec_name = spec_info$name,
        model_type = model_type,
        auc_train = auc_value
      )
  }
}

cat("  In-sample AUC (TRAIN data):\n\n")
print(auc_train %>%
        arrange(desc(auc_train)) %>%
        mutate(auc_train = sprintf("%.4f", auc_train)),
      n = 12)

# ===========================================================================
# 6. CALCULATE OUT-OF-SAMPLE AUC (TEST DATA)
# ===========================================================================

cat("\nStep 6: Calculating out-of-sample AUC on TEST data...\n\n")

# Calculate OOS AUC for all models
auc_test <- tibble(
  spec = character(),
  spec_name = character(),
  model_type = character(),
  auc_test = numeric()
)

for (i in seq_along(specs)) {
  spec_name <- names(specs)[i]
  spec_info <- specs[[i]]

  for (model_type in c("lpm", "logit", "probit")) {
    key <- paste0(spec_name, "_", model_type)
    model <- models_train[[key]]

    auc_value <- calculate_auc(model, data_test)

    auc_test <- auc_test %>%
      add_row(
        spec = as.character(i),
        spec_name = spec_info$name,
        model_type = model_type,
        auc_test = auc_value
      )
  }
}

cat("  Out-of-sample AUC (TEST data):\n\n")
print(auc_test %>%
        arrange(desc(auc_test)) %>%
        mutate(auc_test = sprintf("%.4f", auc_test)),
      n = 12)

# ===========================================================================
# 7. COMBINE RESULTS AND CALCULATE AUC DEGRADATION
# ===========================================================================

cat("\nStep 7: Calculating AUC degradation (Train vs Test)...\n\n")

# Merge train and test AUC
auc_comparison <- auc_train %>%
  left_join(auc_test, by = c("spec", "spec_name", "model_type")) %>%
  mutate(
    auc_degradation = auc_train - auc_test,
    degradation_pct = (auc_train - auc_test) / auc_train * 100
  )

cat("  AUC Comparison: Train vs Test\n\n")
print(auc_comparison %>%
        arrange(spec, model_type) %>%
        mutate(
          auc_train = sprintf("%.4f", auc_train),
          auc_test = sprintf("%.4f", auc_test),
          auc_degradation = sprintf("%.4f", auc_degradation),
          degradation_pct = sprintf("%.1f%%", degradation_pct)
        ),
      n = 12)

# Summary statistics
cat("\n  Summary Statistics:\n\n")
cat(sprintf("    Mean AUC (Train): %.4f\n", mean(auc_comparison$auc_train)))
cat(sprintf("    Mean AUC (Test):  %.4f\n", mean(auc_comparison$auc_test)))
cat(sprintf("    Mean Degradation: %.4f (%.1f%%)\n",
            mean(auc_comparison$auc_degradation),
            mean(auc_comparison$degradation_pct)))
cat(sprintf("    Max Degradation:  %.4f (%.1f%%) - %s %s\n",
            max(auc_comparison$auc_degradation),
            max(auc_comparison$degradation_pct),
            auc_comparison$spec_name[which.max(auc_comparison$auc_degradation)],
            auc_comparison$model_type[which.max(auc_comparison$auc_degradation)]))
cat(sprintf("    Min Degradation:  %.4f (%.1f%%) - %s %s\n",
            min(auc_comparison$auc_degradation),
            min(auc_comparison$degradation_pct),
            auc_comparison$spec_name[which.min(auc_comparison$auc_degradation)],
            auc_comparison$model_type[which.min(auc_comparison$auc_degradation)]))

# ===========================================================================
# 8. LOAD ORIGINAL FULL-SAMPLE RESULTS FOR COMPARISON
# ===========================================================================

cat("\nStep 8: Loading original full-sample (2000-2023) results for comparison...\n\n")

# Load original AUC results
original_auc_path <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/outputs/tables/auc_results_2000.csv"

if (file.exists(original_auc_path)) {
  original_auc <- read_csv(original_auc_path, show_col_types = FALSE) %>%
    rename(auc_full = auc) %>%
    select(spec, spec_name, model_type, auc_full) %>%
    mutate(spec = as.character(spec))  # Convert to character to match auc_comparison

  # Merge with train/test results
  auc_full_comparison <- auc_comparison %>%
    left_join(original_auc, by = c("spec", "spec_name", "model_type")) %>%
    mutate(
      train_vs_full = auc_train - auc_full,
      test_vs_full = auc_test - auc_full
    )

  cat("  Full Comparison: Train vs Test vs Original Full Sample\n\n")
  print(auc_full_comparison %>%
          arrange(spec, model_type) %>%
          mutate(
            auc_train = sprintf("%.4f", auc_train),
            auc_test = sprintf("%.4f", auc_test),
            auc_full = sprintf("%.4f", auc_full),
            train_vs_full = sprintf("%+.4f", train_vs_full),
            test_vs_full = sprintf("%+.4f", test_vs_full)
          ) %>%
          select(spec, spec_name, model_type, auc_train, auc_test, auc_full,
                 train_vs_full, test_vs_full),
        n = 12)

} else {
  cat("  ⚠ Warning: Original AUC results not found, skipping comparison\n")
  auc_full_comparison <- auc_comparison
}

# ===========================================================================
# 9. SAVE RESULTS
# ===========================================================================

cat("\nStep 9: Saving results...\n\n")

# Create output directory if it doesn't exist
output_dir <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/validation/outputs"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Save comparison table
output_file <- file.path(output_dir, "oos_auc_comparison.csv")
write_csv(auc_full_comparison, output_file)
cat(sprintf("  ✓ Saved: %s\n", output_file))

# Save models (for later use in calibration plots, etc.)
models_file <- file.path(output_dir, "oos_models_train.rds")
saveRDS(models_train, models_file)
cat(sprintf("  ✓ Saved: %s\n", models_file))

# Save train/test data (for later use)
data_file <- file.path(output_dir, "oos_train_test_data.rds")
saveRDS(list(train = data_train, test = data_test), data_file)
cat(sprintf("  ✓ Saved: %s\n", data_file))

# ===========================================================================
# 10. INTERPRETATION & SUMMARY
# ===========================================================================

cat("\n")
cat("===========================================================================\n")
cat("INTERPRETATION & SUMMARY\n")
cat("===========================================================================\n\n")

cat("KEY FINDINGS:\n\n")

# Check if models generalize well
mean_degradation <- mean(auc_comparison$degradation_pct)

if (mean_degradation < 5) {
  cat("  ✓ EXCELLENT GENERALIZATION: Models generalize very well to test data\n")
  cat(sprintf("    Average AUC degradation: %.1f%% (< 5%% threshold)\n", mean_degradation))
} else if (mean_degradation < 10) {
  cat("  ✓ GOOD GENERALIZATION: Models generalize reasonably well\n")
  cat(sprintf("    Average AUC degradation: %.1f%% (5-10%% range)\n", mean_degradation))
} else {
  cat("  ⚠ WARNING: Potential overfitting detected\n")
  cat(sprintf("    Average AUC degradation: %.1f%% (> 10%%)\n", mean_degradation))
}

cat("\n")

# Best models
best_test <- auc_full_comparison %>%
  arrange(desc(auc_test)) %>%
  head(3)

cat("  BEST MODELS (by out-of-sample AUC):\n\n")
for (i in 1:3) {
  cat(sprintf("    %d. %s (%s): AUC(test) = %.4f\n",
              i,
              best_test$spec_name[i],
              toupper(best_test$model_type[i]),
              best_test$auc_test[i]))
}

cat("\n")

# Models with smallest degradation
most_stable <- auc_full_comparison %>%
  arrange(degradation_pct) %>%
  head(3)

cat("  MOST STABLE MODELS (smallest degradation):\n\n")
for (i in 1:3) {
  cat(sprintf("    %d. %s (%s): %.1f%% degradation\n",
              i,
              most_stable$spec_name[i],
              toupper(most_stable$model_type[i]),
              most_stable$degradation_pct[i]))
}

cat("\n")
cat("===========================================================================\n")
cat(sprintf("Completed: %s\n", Sys.time()))
cat("===========================================================================\n\n")
