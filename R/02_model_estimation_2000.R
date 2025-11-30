# ===========================================================================
# Modern Period (2000+) Model Estimation
# ===========================================================================
# Purpose: Estimate LPM, Logit, and Probit models for bank failure prediction
# Models: 4 specifications (solvency, funding, interaction, full)
# Author: Claude Code
# Date: 2025-11-30
# ===========================================================================

library(tidyverse)
library(fixest)
library(sandwich)
library(lmtest)
library(pROC)

cat("\n")
cat("===========================================================================\n")
cat("MODEL ESTIMATION: MODERN PERIOD (2000-PRESENT)\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
cat("===========================================================================\n\n")

# ===========================================================================
# 1. LOAD PREPARED DATA
# ===========================================================================

cat("Step 1: Loading prepared data...\n\n")

data_path <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/data/modern_2000_regression_data.rds"

if (!file.exists(data_path)) {
  stop("ERROR: Prepared data not found. Run 01_data_prep_2000.R first.")
}

data <- readRDS(data_path)
cat(sprintf("  ✓ Data loaded: %s observations\n", format(nrow(data), big.mark=",")))

# Convert growth_cat to factor if needed
if ("growth_cat" %in% names(data) && !is.factor(data$growth_cat)) {
  data <- data %>% mutate(growth_cat = factor(growth_cat))
}

# ===========================================================================
# 2. DEFINE MODEL SPECIFICATIONS
# ===========================================================================

cat("\nStep 2: Defining model specifications...\n\n")

# Model specifications (from Correia)
model_specs <- list(
  spec1 = list(
    name = "Model 1: Solvency Only",
    formula = "F1_failure ~ income_ratio + log_age",
    desc = "Basic solvency measure (profitability)"
  ),
  spec2 = list(
    name = "Model 2: Funding Only",
    formula = "F1_failure ~ noncore_ratio + log_age",
    desc = "Basic funding fragility measure"
  ),
  spec3 = list(
    name = "Model 3: Solvency x Funding Interaction",
    formula = "F1_failure ~ noncore_ratio * income_ratio + log_age",
    desc = "Interaction between funding and solvency"
  ),
  spec4 = list(
    name = "Model 4: Full with Growth Controls",
    formula = "F1_failure ~ noncore_ratio * income_ratio + log_age + factor(growth_cat) + gdp_growth_3years + inf_cpi_3years",
    desc = "Full model with macroeconomic controls"
  )
)

cat("  Specifications defined:\n")
for (i in 1:length(model_specs)) {
  spec <- model_specs[[i]]
  cat(sprintf("    %s: %s\n", spec$name, spec$desc))
}

# ===========================================================================
# 3. ESTIMATE LINEAR PROBABILITY MODELS (LPM)
# ===========================================================================

cat("\n===========================================================================\n")
cat("ESTIMATING LINEAR PROBABILITY MODELS (LPM)\n")
cat("===========================================================================\n\n")

lpm_results <- list()

for (i in 1:length(model_specs)) {
  spec <- model_specs[[i]]
  cat(sprintf("--- %s ---\n", spec$name))

  # Fit OLS model
  fit <- lm(as.formula(spec$formula), data = data, na.action = na.omit)

  # Sample size
  n_obs <- nobs(fit)
  cat(sprintf("  Observations: %s\n", format(n_obs, big.mark=",")))

  # Driscoll-Kraay standard errors (approximated via Newey-West with lag=3)
  vcov_dk <- tryCatch({
    NeweyWest(fit, lag = 3, prewhite = FALSE)
  }, error = function(e) {
    warning("Driscoll-Kraay SE failed, using HC robust SE")
    vcovHC(fit, type = "HC1")
  })

  # Extract coefficients
  coefs <- coef(fit)
  se <- sqrt(diag(vcov_dk))
  t_stats <- coefs / se
  p_vals <- 2 * pt(-abs(t_stats), df = n_obs - length(coefs))

  # Model fit statistics
  r2 <- summary(fit)$r.squared
  adj_r2 <- summary(fit)$adj.r.squared

  # Generate predictions
  predictions <- predict(fit, type = "response")

  # Store results
  lpm_results[[i]] <- list(
    spec_name = spec$name,
    formula = spec$formula,
    n_obs = n_obs,
    coefficients = coefs,
    se = se,
    t_stat = t_stats,
    p_value = p_vals,
    r2 = r2,
    adj_r2 = adj_r2,
    predictions = predictions,
    fit = fit
  )

  cat(sprintf("  R²: %.4f (Adj R²: %.4f)\n", r2, adj_r2))
  cat(sprintf("  Key coefficients:\n"))

  # Display key coefficients
  key_vars <- c("income_ratio", "noncore_ratio", "log_age",
                "noncore_ratio:income_ratio")
  for (var in key_vars) {
    if (var %in% names(coefs)) {
      sig <- ifelse(p_vals[var] < 0.001, "***",
                    ifelse(p_vals[var] < 0.01, "**",
                           ifelse(p_vals[var] < 0.05, "*", "")))
      cat(sprintf("    %s: %.6f (SE: %.6f) %s\n",
                  var, coefs[var], se[var], sig))
    }
  }
  cat("\n")
}

cat("✓ All LPM models estimated successfully\n\n")

# ===========================================================================
# 4. ESTIMATE LOGIT MODELS
# ===========================================================================

cat("===========================================================================\n")
cat("ESTIMATING LOGIT MODELS\n")
cat("===========================================================================\n\n")

logit_results <- list()

for (i in 1:length(model_specs)) {
  spec <- model_specs[[i]]
  cat(sprintf("--- %s ---\n", spec$name))

  # Fit Logit model
  fit <- glm(as.formula(spec$formula),
             data = data,
             family = binomial(link = "logit"),
             na.action = na.omit)

  # Check convergence
  if (!fit$converged) {
    warning(sprintf("  ⚠ Model did not converge for %s", spec$name))
  }

  # Sample size
  n_obs <- nobs(fit)
  cat(sprintf("  Observations: %s\n", format(n_obs, big.mark=",")))
  cat(sprintf("  Converged: %s\n", fit$converged))

  # Robust standard errors
  vcov_robust <- vcovHC(fit, type = "HC1")

  # Extract coefficients
  coefs <- coef(fit)
  se <- sqrt(diag(vcov_robust))
  z_stats <- coefs / se
  p_vals <- 2 * pnorm(-abs(z_stats))

  # Pseudo R-squared (McFadden)
  null_dev <- fit$null.deviance
  resid_dev <- fit$deviance
  pseudo_r2 <- 1 - (resid_dev / null_dev)

  # Generate predictions (probabilities)
  predictions <- predict(fit, type = "response")

  # Store results
  logit_results[[i]] <- list(
    spec_name = spec$name,
    formula = spec$formula,
    n_obs = n_obs,
    coefficients = coefs,
    se = se,
    z_stat = z_stats,
    p_value = p_vals,
    pseudo_r2 = pseudo_r2,
    aic = AIC(fit),
    bic = BIC(fit),
    converged = fit$converged,
    predictions = predictions,
    fit = fit
  )

  cat(sprintf("  Pseudo-R²: %.4f\n", pseudo_r2))
  cat(sprintf("  AIC: %.1f, BIC: %.1f\n", AIC(fit), BIC(fit)))
  cat(sprintf("  Key coefficients:\n"))

  # Display key coefficients
  key_vars <- c("income_ratio", "noncore_ratio", "log_age",
                "noncore_ratio:income_ratio")
  for (var in key_vars) {
    if (var %in% names(coefs)) {
      sig <- ifelse(p_vals[var] < 0.001, "***",
                    ifelse(p_vals[var] < 0.01, "**",
                           ifelse(p_vals[var] < 0.05, "*", "")))
      cat(sprintf("    %s: %.6f (SE: %.6f) %s\n",
                  var, coefs[var], se[var], sig))
    }
  }
  cat("\n")
}

cat("✓ All Logit models estimated successfully\n\n")

# ===========================================================================
# 5. ESTIMATE PROBIT MODELS
# ===========================================================================

cat("===========================================================================\n")
cat("ESTIMATING PROBIT MODELS\n")
cat("===========================================================================\n\n")

probit_results <- list()

for (i in 1:length(model_specs)) {
  spec <- model_specs[[i]]
  cat(sprintf("--- %s ---\n", spec$name))

  # Fit Probit model
  fit <- glm(as.formula(spec$formula),
             data = data,
             family = binomial(link = "probit"),
             na.action = na.omit)

  # Check convergence
  if (!fit$converged) {
    warning(sprintf("  ⚠ Model did not converge for %s", spec$name))
  }

  # Sample size
  n_obs <- nobs(fit)
  cat(sprintf("  Observations: %s\n", format(n_obs, big.mark=",")))
  cat(sprintf("  Converged: %s\n", fit$converged))

  # Robust standard errors
  vcov_robust <- vcovHC(fit, type = "HC1")

  # Extract coefficients
  coefs <- coef(fit)
  se <- sqrt(diag(vcov_robust))
  z_stats <- coefs / se
  p_vals <- 2 * pnorm(-abs(z_stats))

  # Pseudo R-squared
  null_dev <- fit$null.deviance
  resid_dev <- fit$deviance
  pseudo_r2 <- 1 - (resid_dev / null_dev)

  # Generate predictions (probabilities)
  predictions <- predict(fit, type = "response")

  # Store results
  probit_results[[i]] <- list(
    spec_name = spec$name,
    formula = spec$formula,
    n_obs = n_obs,
    coefficients = coefs,
    se = se,
    z_stat = z_stats,
    p_value = p_vals,
    pseudo_r2 = pseudo_r2,
    aic = AIC(fit),
    bic = BIC(fit),
    converged = fit$converged,
    predictions = predictions,
    fit = fit
  )

  cat(sprintf("  Pseudo-R²: %.4f\n", pseudo_r2))
  cat(sprintf("  AIC: %.1f, BIC: %.1f\n", AIC(fit), BIC(fit)))
  cat(sprintf("  Key coefficients:\n"))

  # Display key coefficients
  key_vars <- c("income_ratio", "noncore_ratio", "log_age",
                "noncore_ratio:income_ratio")
  for (var in key_vars) {
    if (var %in% names(coefs)) {
      sig <- ifelse(p_vals[var] < 0.001, "***",
                    ifelse(p_vals[var] < 0.01, "**",
                           ifelse(p_vals[var] < 0.05, "*", "")))
      cat(sprintf("    %s: %.6f (SE: %.6f) %s\n",
                  var, coefs[var], se[var], sig))
    }
  }
  cat("\n")
}

cat("✓ All Probit models estimated successfully\n\n")

# ===========================================================================
# 6. SAVE MODEL RESULTS
# ===========================================================================

cat("===========================================================================\n")
cat("SAVING MODEL RESULTS\n")
cat("===========================================================================\n\n")

# Save all results
output_path <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/data/model_results_2000.rds"

results <- list(
  lpm = lpm_results,
  logit = logit_results,
  probit = probit_results,
  data = data,  # Include data for AUC calculation later
  specs = model_specs
)

saveRDS(results, output_path)
cat(sprintf("  ✓ Model results saved to: %s\n", output_path))

file_size_mb <- file.info(output_path)$size / 1024 / 1024
cat(sprintf("  File size: %.1f MB\n\n", file_size_mb))

# ===========================================================================
# 7. CREATE COEFFICIENT COMPARISON TABLE
# ===========================================================================

cat("Creating coefficient comparison tables...\n\n")

# Function to extract coefficient table
extract_coef_table <- function(results_list, model_type) {
  tables <- list()

  for (i in 1:length(results_list)) {
    res <- results_list[[i]]

    # Create data frame
    coef_df <- data.frame(
      spec = i,
      spec_name = res$spec_name,
      model_type = model_type,
      variable = names(res$coefficients),
      coefficient = res$coefficients,
      se = res$se,
      p_value = res$p_value,
      stringsAsFactors = FALSE
    )

    # Add significance stars
    coef_df$sig <- ifelse(coef_df$p_value < 0.001, "***",
                          ifelse(coef_df$p_value < 0.01, "**",
                                 ifelse(coef_df$p_value < 0.05, "*", "")))

    tables[[i]] <- coef_df
  }

  bind_rows(tables)
}

# Extract all coefficients
lpm_coefs <- extract_coef_table(lpm_results, "LPM")
logit_coefs <- extract_coef_table(logit_results, "Logit")
probit_coefs <- extract_coef_table(probit_results, "Probit")

# Combine all
all_coefs <- bind_rows(lpm_coefs, logit_coefs, probit_coefs)

# Save coefficient table
coef_path <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/outputs/tables/coefficients_all_models_2000.csv"
write.csv(all_coefs, coef_path, row.names = FALSE)
cat(sprintf("  ✓ Coefficient table saved to: %s\n\n", coef_path))

# ===========================================================================
# 8. CREATE MODEL SUMMARY TABLE
# ===========================================================================

cat("Creating model summary table...\n\n")

# Extract model fit statistics
model_summary <- data.frame(
  spec = rep(1:4, 3),
  spec_name = rep(sapply(model_specs, function(x) x$name), 3),
  model_type = rep(c("LPM", "Logit", "Probit"), each = 4),
  n_obs = c(
    sapply(lpm_results, function(x) x$n_obs),
    sapply(logit_results, function(x) x$n_obs),
    sapply(probit_results, function(x) x$n_obs)
  ),
  r2_pseudo_r2 = c(
    sapply(lpm_results, function(x) x$r2),
    sapply(logit_results, function(x) x$pseudo_r2),
    sapply(probit_results, function(x) x$pseudo_r2)
  ),
  aic = c(
    rep(NA, 4),  # LPM doesn't have AIC
    sapply(logit_results, function(x) x$aic),
    sapply(probit_results, function(x) x$aic)
  ),
  bic = c(
    rep(NA, 4),  # LPM doesn't have BIC
    sapply(logit_results, function(x) x$bic),
    sapply(probit_results, function(x) x$bic)
  ),
  stringsAsFactors = FALSE
)

summary_path <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/outputs/tables/model_summary_2000.csv"
write.csv(model_summary, summary_path, row.names = FALSE)
cat(sprintf("  ✓ Model summary table saved to: %s\n\n", summary_path))

# ===========================================================================
# COMPLETION
# ===========================================================================

cat("===========================================================================\n")
cat("MODEL ESTIMATION COMPLETE\n")
cat("===========================================================================\n")
cat(sprintf("End time: %s\n", Sys.time()))
cat(sprintf("\nModels estimated:\n"))
cat(sprintf("  - 4 LPM specifications\n"))
cat(sprintf("  - 4 Logit specifications\n"))
cat(sprintf("  - 4 Probit specifications\n"))
cat(sprintf("  - Total: 12 models\n\n"))
cat(sprintf("Next step: Run 03_auc_analysis_2000.R\n"))
cat("===========================================================================\n\n")
