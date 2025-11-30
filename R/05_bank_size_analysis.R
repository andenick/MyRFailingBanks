# ===========================================================================
# Bank Size Heterogeneity Analysis
# ===========================================================================
# Purpose: Examine whether failure prediction varies by bank size
#          - Estimate models by size category
#          - Compare AUC across size bins
#          - Analyze coefficient differences by size
# Author: Claude Code
# Date: 2025-11-30
# ===========================================================================

library(tidyverse)
library(haven)
library(pROC)

cat("\n")
cat("===========================================================================\n")
cat("BANK SIZE HETEROGENEITY ANALYSIS\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
cat("===========================================================================\n\n")

# ===========================================================================
# 1. LOAD DATA
# ===========================================================================

cat("Step 1: Loading modern period (2000+) data...\n\n")

data_path <- "D:/Arcanum/Projects/FailingBanks/Technical/data/comprehensive_comparison/correia_reg_modern.rds"

if (file.exists(data_path)) {
  cat(sprintf("  Loading from: %s\n", data_path))
  data_modern <- readRDS(data_path)
  cat("  ✓ Data loaded successfully\n")
} else {
  data_path <- "D:/Arcanum/Projects/FailingBanks/FailingBanks_Perfect_Replication_v7.0/dataclean/temp_reg_data.rds"

  if (file.exists(data_path)) {
    cat(sprintf("  Loading from: %s\n", data_path))
    data_full <- readRDS(data_path)
    data_modern <- data_full %>% filter(year >= 2000)
    cat("  ✓ Data loaded successfully (alternative source)\n")
  } else {
    data_path <- "D:/Arcanum/Projects/FailingBanks/FailingBanks_v9.0_Clean/tempfiles/temp_reg_data.dta"

    if (file.exists(data_path)) {
      cat(sprintf("  Loading from: %s\n", data_path))
      data_full <- haven::read_dta(data_path)
      data_modern <- data_full %>% filter(year >= 2000)
      cat("  ✓ Data loaded successfully (Stata file)\n")
    } else {
      stop("ERROR: Could not find data file")
    }
  }
}

cat(sprintf("\n  Data loaded: %s observations\n", format(nrow(data_modern), big.mark=",")))

# ===========================================================================
# 2. CREATE SIZE CATEGORIES
# ===========================================================================

cat("\nStep 2: Creating bank size categories...\n\n")

# Need asset variable - check what's available
if (!"asset" %in% names(data_modern)) {
  cat("  ⚠ Warning: 'asset' variable not found, checking alternatives...\n")
  asset_vars <- names(data_modern)[grepl("asset", names(data_modern), ignore.case = TRUE)]
  cat(sprintf("  Available asset-related variables: %s\n", paste(asset_vars, collapse=", ")))

  # Try common alternatives
  if ("assets" %in% names(data_modern)) {
    data_modern <- data_modern %>% mutate(asset = assets)
  } else if ("total_assets" %in% names(data_modern)) {
    data_modern <- data_modern %>% mutate(asset = total_assets)
  } else {
    stop("ERROR: No asset variable found for size categorization")
  }
}

# Create size categories (in millions)
data_modern <- data_modern %>%
  mutate(
    asset_millions = asset / 1000,  # Assuming asset is in thousands
    size_category = case_when(
      asset_millions < 100 ~ "1. Tiny (<$100M)",
      asset_millions >= 100 & asset_millions < 1000 ~ "2. Small ($100M-$1B)",
      asset_millions >= 1000 & asset_millions < 10000 ~ "3. Medium ($1B-$10B)",
      asset_millions >= 10000 ~ "4. Large (>$10B)",
      TRUE ~ "Unknown"
    )
  )

# Summary by size category
size_summary <- data_modern %>%
  group_by(size_category) %>%
  summarise(
    n_obs = n(),
    n_failures = sum(F1_failure, na.rm = TRUE),
    failure_rate = mean(F1_failure, na.rm = TRUE) * 100,
    mean_assets = mean(asset_millions, na.rm = TRUE),
    median_assets = median(asset_millions, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(size_category)

cat("  Bank size distribution:\n\n")
print(size_summary)

# ===========================================================================
# 3. ESTIMATE MODELS BY SIZE CATEGORY
# ===========================================================================

cat("\nStep 3: Estimating models by size category...\n\n")

# Focus on Model 3 (interaction) and Model 4 (full) for size analysis
# Use LPM only (logit/probit had convergence issues in validation)

estimate_by_size <- function(data, size_cat, model_spec) {

  # Filter to size category
  data_size <- data %>% filter(size_category == size_cat)

  if (nrow(data_size) < 100 || sum(data_size$F1_failure, na.rm = TRUE) < 5) {
    return(NULL)  # Skip if too few observations or failures
  }

  # Estimate LPM
  if (model_spec == "Model 3") {
    formula <- F1_failure ~ income_ratio + noncore_ratio +
      income_ratio:noncore_ratio + log_age
  } else if (model_spec == "Model 4") {
    formula <- F1_failure ~ income_ratio + noncore_ratio +
      income_ratio:noncore_ratio + log_age +
      growth_cat + gdp_growth_3years + inf_cpi_3years
  }

  model <- lm(formula, data = data_size)

  # Calculate AUC
  pred <- predict(model)
  pred <- pmax(0, pmin(1, pred))  # Truncate to [0, 1]

  actual <- data_size$F1_failure
  valid <- !is.na(actual) & !is.na(pred)

  roc_obj <- pROC::roc(actual[valid], pred[valid], direction = "<", quiet = TRUE)
  auc_value <- as.numeric(pROC::auc(roc_obj))

  # Extract coefficients
  coef_df <- broom::tidy(model) %>%
    select(term, estimate, std.error, p.value)

  return(list(
    model = model,
    auc = auc_value,
    n_obs = nrow(data_size),
    n_failures = sum(data_size$F1_failure, na.rm = TRUE),
    coefficients = coef_df
  ))
}

# Estimate for all size categories
results_by_size <- tibble()

for (size_cat in unique(data_modern$size_category)) {
  if (size_cat == "Unknown") next

  cat(sprintf("  Estimating models for: %s\n", size_cat))

  for (model_spec in c("Model 3", "Model 4")) {
    result <- estimate_by_size(data_modern, size_cat, model_spec)

    if (!is.null(result)) {
      results_by_size <- results_by_size %>%
        add_row(
          size_category = size_cat,
          model = model_spec,
          auc = result$auc,
          n_obs = result$n_obs,
          n_failures = result$n_failures
        )
    }
  }
}

cat("\n  ✓ Estimation complete\n")

# ===========================================================================
# 4. AUC COMPARISON BY SIZE
# ===========================================================================

cat("\nStep 4: Comparing AUC across size categories...\n\n")

cat("  AUC by bank size:\n\n")
print(results_by_size %>%
        arrange(size_category, model) %>%
        mutate(
          auc = sprintf("%.4f", auc),
          n_obs = format(n_obs, big.mark = ","),
          n_failures = format(n_failures, big.mark = ",")
        ))

# ===========================================================================
# 5. COEFFICIENT COMPARISON BY SIZE
# ===========================================================================

cat("\nStep 5: Comparing coefficients across size categories...\n\n")

# Extract coefficients for key variables
coef_comparison <- tibble()

for (size_cat in unique(data_modern$size_category)) {
  if (size_cat == "Unknown") next

  # Model 3 coefficients
  result <- estimate_by_size(data_modern, size_cat, "Model 3")

  if (!is.null(result)) {
    coefs <- result$coefficients %>%
      filter(term %in% c("income_ratio", "noncore_ratio",
                         "income_ratio:noncore_ratio")) %>%
      mutate(
        size_category = size_cat,
        model = "Model 3"
      )

    coef_comparison <- bind_rows(coef_comparison, coefs)
  }
}

cat("  Coefficient estimates by size (Model 3):\n\n")
print(coef_comparison %>%
        select(size_category, term, estimate, std.error, p.value) %>%
        arrange(size_category, term))

# ===========================================================================
# 6. SAVE RESULTS
# ===========================================================================

cat("\nStep 6: Saving results...\n\n")

output_dir <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/extended_analysis/outputs"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Save AUC by size
write_csv(results_by_size, file.path(output_dir, "auc_by_size.csv"))
cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "auc_by_size.csv")))

# Save coefficient comparison
write_csv(coef_comparison, file.path(output_dir, "coefficients_by_size.csv"))
cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "coefficients_by_size.csv")))

# Create forest plot data for coefficients
forest_data <- coef_comparison %>%
  filter(term != "(Intercept)") %>%
  mutate(
    ci_lower = estimate - 1.96 * std.error,
    ci_upper = estimate + 1.96 * std.error
  )

saveRDS(forest_data, file.path(output_dir, "coefficient_forest_data.rds"))
cat(sprintf("  ✓ Saved: %s\n", file.path(output_dir, "coefficient_forest_data.rds")))

# ===========================================================================
# 7. INTERPRETATION
# ===========================================================================

cat("\n")
cat("===========================================================================\n")
cat("INTERPRETATION\n")
cat("===========================================================================\n\n")

# Compare AUC across sizes
auc_range <- range(results_by_size$auc)

cat(sprintf("AUC VARIATION BY SIZE:\n"))
cat(sprintf("  Min AUC: %.4f\n", auc_range[1]))
cat(sprintf("  Max AUC: %.4f\n", auc_range[2]))
cat(sprintf("  Range: %.4f\n\n", auc_range[2] - auc_range[1]))

if ((auc_range[2] - auc_range[1]) < 0.05) {
  cat("  ✓ Models perform similarly across all size categories\n")
  cat("  Conclusion: Size-specific models not necessary\n\n")
} else {
  cat("  ⚠ Substantial variation in predictive power by size\n")
  cat("  Conclusion: Consider size-specific models or size interactions\n\n")
}

# Identify best-performing size category
best_size <- results_by_size %>%
  filter(model == "Model 3") %>%
  arrange(desc(auc)) %>%
  head(1)

cat(sprintf("BEST PREDICTION BY SIZE:\n"))
cat(sprintf("  Size category: %s\n", best_size$size_category))
cat(sprintf("  AUC: %.4f\n", best_size$auc))
cat(sprintf("  Failures: %s\n\n", format(best_size$n_failures, big.mark = ",")))

cat("===========================================================================\n")
cat(sprintf("Completed: %s\n", Sys.time()))
cat("===========================================================================\n\n")
