# ===========================================================================
# Specification Tests & Diagnostics
# ===========================================================================
# Purpose: Validate model specifications with diagnostic tests
#          - VIF for multicollinearity
#          - Residual diagnostics (LPM only)
#          - Hosmer-Lemeshow goodness of fit (Logit/Probit)
# Author: Claude Code
# Date: 2025-11-30
# ===========================================================================

library(tidyverse)
library(haven)
library(car)  # For VIF
library(ResourceSelection)  # For Hosmer-Lemeshow test

cat("\n")
cat("===========================================================================\n")
cat("SPECIFICATION TESTS & DIAGNOSTICS\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
cat("===========================================================================\n\n")

# Load models from OOS validation
cat("Step 1: Loading estimated models...\n\n")

models_path <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/validation/outputs/oos_models_train.rds"

if (!file.exists(models_path)) {
  stop("ERROR: Models file not found. Run 01_out_of_sample_validation.R first")
}

models_train <- readRDS(models_path)
cat(sprintf("  ✓ Loaded %d models\n\n", length(models_train)))

# Load data
data_path <- "D:/Arcanum/Projects/FailingBanks/Technical/data/comprehensive_comparison/correia_reg_modern.rds"
data_modern <- readRDS(data_path)
data_train <- data_modern %>% filter(year >= 2000 & year <= 2015)

# ===========================================================================
# 2. VIF (VARIANCE INFLATION FACTORS) - MULTICOLLINEARITY
# ===========================================================================

cat("Step 2: Calculating VIF for multicollinearity...\n\n")

# Focus on Model 3 and Model 4 (have interactions)
vif_results <- tibble()

for (model_key in c("spec3_lpm", "spec4_lpm")) {
  model <- models_train[[model_key]]

  tryCatch({
    vif_vals <- vif(model)

    # Handle both vector and matrix VIF results
    if (is.matrix(vif_vals)) {
      vif_vals <- vif_vals[, "GVIF^(1/(2*Df))"]
    }

    for (var_name in names(vif_vals)) {
      vif_results <- vif_results %>%
        add_row(
          model = model_key,
          variable = var_name,
          vif = vif_vals[var_name]
        )
    }
  }, error = function(e) {
    cat(sprintf("  ⚠ Could not calculate VIF for %s: %s\n", model_key, e$message))
  })
}

cat("  VIF results:\n\n")
print(vif_results %>% arrange(desc(vif)), n = 20)

cat("\n  INTERPRETATION:\n")
max_vif <- max(vif_results$vif, na.rm = TRUE)
if (max_vif < 5) {
  cat("    ✓ No multicollinearity concerns (all VIF < 5)\n\n")
} else if (max_vif < 10) {
  cat("    ⚠ Moderate multicollinearity (some VIF 5-10)\n\n")
} else {
  cat("    ⚠ Severe multicollinearity (some VIF > 10)\n\n")
}

# ===========================================================================
# 3. RESIDUAL DIAGNOSTICS (LPM ONLY)
# ===========================================================================

cat("Step 3: Residual diagnostics for LPM models...\n\n")

residual_diagnostics <- function(model, model_name) {
  cat(sprintf("  Analyzing %s:\n", model_name))

  # Get residuals and fitted values
  resid <- residuals(model)
  fitted <- fitted(model)

  # Check for problematic fitted values (outside [0,1])
  outside_range <- sum(fitted < 0 | fitted > 1, na.rm = TRUE)
  pct_outside <- outside_range / length(fitted) * 100

  cat(sprintf("    Fitted values outside [0,1]: %d (%.1f%%)\n",
              outside_range, pct_outside))

  # Mean and SD of residuals
  cat(sprintf("    Mean residual: %.6f (should be ~0)\n", mean(resid, na.rm = TRUE)))
  cat(sprintf("    SD residual: %.4f\n\n", sd(resid, na.rm = TRUE)))

  return(tibble(
    model = model_name,
    outside_range = outside_range,
    pct_outside = pct_outside,
    mean_resid = mean(resid, na.rm = TRUE),
    sd_resid = sd(resid, na.rm = TRUE)
  ))
}

resid_results <- bind_rows(
  residual_diagnostics(models_train$spec3_lpm, "Model 3 LPM"),
  residual_diagnostics(models_train$spec4_lpm, "Model 4 LPM")
)

# ===========================================================================
# 4. HOSMER-LEMESHOW GOODNESS OF FIT (LOGIT)
# ===========================================================================

cat("Step 4: Hosmer-Lemeshow goodness of fit test (Logit models)...\n\n")

hl_results <- tibble()

for (model_key in c("spec3_logit", "spec4_logit")) {
  model <- models_train[[model_key]]

  cat(sprintf("  Testing %s:\n", model_key))

  tryCatch({
    # Get observed outcomes and fitted probabilities
    y <- model$y
    fitted_prob <- fitted(model)

    # Hosmer-Lemeshow test
    hl_test <- hoslem.test(y, fitted_prob, g = 10)

    cat(sprintf("    H-L Chi-square: %.4f\n", hl_test$statistic))
    cat(sprintf("    p-value: %.4f\n", hl_test$p.value))

    if (hl_test$p.value > 0.05) {
      cat("    ✓ Good fit (p > 0.05)\n\n")
    } else {
      cat("    ⚠ Poor fit (p < 0.05)\n\n")
    }

    hl_results <- hl_results %>%
      add_row(
        model = model_key,
        chi_square = as.numeric(hl_test$statistic),
        p_value = hl_test$p.value,
        interpretation = ifelse(hl_test$p.value > 0.05, "Good fit", "Poor fit")
      )

  }, error = function(e) {
    cat(sprintf("    ⚠ Error: %s\n\n", e$message))
  })
}

# ===========================================================================
# 5. SAVE RESULTS
# ===========================================================================

cat("Step 5: Saving diagnostic results...\n\n")

output_dir <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/validation/outputs"

write_csv(vif_results, file.path(output_dir, "vif_diagnostics.csv"))
cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "vif_diagnostics.csv")))

write_csv(resid_results, file.path(output_dir, "residual_diagnostics.csv"))
cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "residual_diagnostics.csv")))

if (nrow(hl_results) > 0) {
  write_csv(hl_results, file.path(output_dir, "hosmer_lemeshow_tests.csv"))
  cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "hosmer_lemeshow_tests.csv")))
}

# ===========================================================================
# 6. SUMMARY
# ===========================================================================

cat("\n")
cat("===========================================================================\n")
cat("DIAGNOSTIC SUMMARY\n")
cat("===========================================================================\n\n")

cat("MULTICOLLINEARITY (VIF):\n")
if (nrow(vif_results) > 0) {
  cat(sprintf("  Max VIF: %.2f\n", max(vif_results$vif, na.rm = TRUE)))
  if (max(vif_results$vif, na.rm = TRUE) < 5) {
    cat("  ✓ PASS: No concerns\n\n")
  } else {
    cat("  ⚠ REVIEW: Some elevated VIF values\n\n")
  }
}

cat("RESIDUAL DIAGNOSTICS:\n")
if (nrow(resid_results) > 0) {
  avg_outside <- mean(resid_results$pct_outside)
  cat(sprintf("  Avg fitted values outside [0,1]: %.1f%%\n", avg_outside))
  if (avg_outside < 5) {
    cat("  ✓ ACCEPTABLE: < 5%% outside bounds\n\n")
  } else {
    cat("  ⚠ NOTE: LPM can predict outside [0,1], consider Logit/Probit\n\n")
  }
}

cat("HOSMER-LEMESHOW TESTS:\n")
if (nrow(hl_results) > 0) {
  good_fit_count <- sum(hl_results$interpretation == "Good fit")
  cat(sprintf("  Models with good fit: %d / %d\n", good_fit_count, nrow(hl_results)))
  if (good_fit_count == nrow(hl_results)) {
    cat("  ✓ PASS: All models show good fit\n\n")
  } else {
    cat("  ⚠ REVIEW: Some models may have specification issues\n\n")
  }
}

cat("===========================================================================\n")
cat(sprintf("Completed: %s\n", Sys.time()))
cat("===========================================================================\n\n")
