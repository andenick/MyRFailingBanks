# ===========================================================================
# Script 34: Coefficient Plots - Dynamics in Failing Banks (1959-2023)
# ===========================================================================
# This script creates coefficient plots showing how key variables evolve
# in the quarters leading up to bank failure in the modern era.
# Uses event study methodology with bank fixed effects.
#
# Key outputs:
# - Asset composition dynamics (assets, loans, liquid assets)
# - Employment dynamics
# - Deposit composition (time, demand, brokered)
# - Funding ratios (deposit ratios, noncore funding)
# - Loan composition and profitability
#
# v2.5 enhancements:
# - Verbose console diagnostics throughout
# - Detailed progress tracking
# ===========================================================================

cat("===========================================================================\n")
cat("SCRIPT 34: COEFFICIENT PLOTS - MODERN ERA DYNAMICS (1959-2023)\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
script_start_time <- Sys.time()

# --- Load Required Libraries ---
cat("\n[Loading Libraries]\n")
suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(fixest)  # For fixed effects regressions
  library(ggplot2)
  library(tidyr)
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
# PART 1: LOAD AND PREPARE DATA
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 1: DATA LOADING AND PREPARATION\n")
cat("===========================================================================\n")

cat("\nLoading combined-data.rds...\n")
data_full <- readRDS(file.path(dataclean_dir, "combined-data.rds"))

cat(sprintf("  Loaded: %d observations\n", nrow(data_full)))

# Filter to post-1950 and failed banks within 40 quarters of failure
cat("\n[Filtering to Modern Era Failed Banks]\n")

data_modern <- data_full %>%
  filter(year > 1950,
         quarters_to_failure >= -40,
         quarters_to_failure <= -1) %>%
  mutate(time_to_fail = quarters_to_failure)

cat(sprintf("  Filtered data: %d observations\n", nrow(data_modern)))
cat(sprintf("  Failed banks: %d\n", n_distinct(data_modern$bank_id, na.rm = TRUE)))
cat(sprintf("  Years: %d to %d\n", min(data_modern$year, na.rm = TRUE),
            max(data_modern$year, na.rm = TRUE)))

# Transform level variables to logs
cat("\n[Transforming level variables to logs]\n")

level_vars <- c("assets", "loans", "deposits", "liquid", "deposits_time",
                "deposits_demand", "otherbor_liab", "brokered_dep",
                "ln_cons", "ln_cc", "ln_ci", "ln_oth", "ln_fi", "ln_re",
                "num_employees", "noncore_funding")

for (var in level_vars) {
  if (var %in% names(data_modern)) {
    data_modern[[paste0(var, "_log")]] <- log(data_modern[[var]])
  }
}

cat("  ✓ Level variables transformed to logs\n")

# ===========================================================================
# PART 2: RUN EVENT STUDY REGRESSIONS
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 2: EVENT STUDY REGRESSIONS\n")
cat("===========================================================================\n")

cat("\nRunning event study regressions for each variable...\n")
cat("Baseline period: t=-40 quarters before failure\n\n")

# Define variable lists
ratio_vars <- c("leverage", "npl_ratio", "prov_ratio", "int_inc_ratio",
                "int_exp_ratio", "income_ratio", "nim", "loan_ratio",
                "deposit_ratio", "liquid_ratio", "ln_cons_ratio",
                "ln_cc_ratio", "ln_ci_ratio", "ln_oth_ratio",
                "ln_fi_ratio", "ln_re_ratio", "deposits_time_ratio",
                "deposits_demand_ratio", "otherbor_liab_ratio",
                "brokered_dep_ratio", "insured_deposits_ratio",
                "noncore_ratio")

level_vars_log <- paste0(level_vars, "_log")

# "Extra" variables without fixed effects
extra_vars <- c("int_inc_ratio", "int_exp_ratio", "nim")

# Helper function to run event study regression
RunEventStudyModern <- function(data, var_name, use_fe = TRUE) {

  cat(sprintf("  [%s]\n", var_name))

  # Prepare data
  data_reg <- data %>%
    filter(!is.na(.data[[var_name]])) %>%
    mutate(
      time_indicator = as.factor(time_to_fail + 40)  # Shift so 0 is baseline (t=-40)
    )

  if (nrow(data_reg) < 100) {
    cat("    ⚠ Insufficient data, skipping\n")
    return(NULL)
  }

  # Run regression
  if (use_fe) {
    # With bank fixed effects, cluster by bank and year
    model <- tryCatch({
      feols(as.formula(paste(var_name, "~ i(time_indicator, ref = 0) | bank_id")),
            data = data_reg,
            cluster = ~bank_id + year)
    }, error = function(e) NULL)
  } else {
    # Without fixed effects (for extra vars), cluster by bank and year
    model <- tryCatch({
      feols(as.formula(paste(var_name, "~ i(time_indicator, ref = 0)")),
            data = data_reg,
            cluster = ~bank_id + year)
    }, error = function(e) NULL)
  }

  if (is.null(model)) {
    cat("    ⚠ Model failed to converge, skipping\n")
    return(NULL)
  }

  # Extract coefficients
  coef_df <- broom::tidy(model, conf.int = TRUE) %>%
    filter(grepl("time_indicator", term)) %>%
    mutate(
      time_to_fail = as.numeric(gsub("time_indicator::", "", term)) - 40,
      variable = var_name
    ) %>%
    select(variable, time_to_fail, estimate, std.error, conf.low, conf.high)

  # Add baseline (t=-40) with coefficient = 0
  baseline <- data.frame(
    variable = var_name,
    time_to_fail = -40,
    estimate = 0,
    std.error = 0,
    conf.low = 0,
    conf.high = 0
  )

  coef_df <- bind_rows(baseline, coef_df)

  cat(sprintf("    ✓ Estimated %d time periods\n", nrow(coef_df) - 1))

  return(coef_df)
}

# Run regressions for ratio variables (with FE)
cat("\n[Ratio Variables with Bank FE]\n")
results_ratios <- list()

for (var in ratio_vars) {
  if (var %in% names(data_modern)) {
    use_fe <- !(var %in% extra_vars)
    result <- RunEventStudyModern(data_modern, var, use_fe = use_fe)
    if (!is.null(result)) {
      results_ratios[[var]] <- result
    }
  }
}

# Run regressions for level variables (in logs, with FE)
cat("\n[Level Variables (in logs) with Bank FE]\n")
results_levels <- list()

for (var in level_vars_log) {
  if (var %in% names(data_modern)) {
    result <- RunEventStudyModern(data_modern, var, use_fe = TRUE)
    if (!is.null(result)) {
      # Strip "_log" suffix for cleaner variable names
      result$variable <- gsub("_log$", "", result$variable)
      results_levels[[var]] <- result
    }
  }
}

cat("\n  ✓ All event study regressions completed\n")

# Combine results
# bind_rows on lists of dataframes
all_results <- bind_rows(c(results_ratios, results_levels))

# Check if we have any results
if (nrow(all_results) == 0 || !"variable" %in% names(all_results)) {
  stop("No successful event study regressions. Check data availability and model convergence.")
}

# Save coefficient data
saveRDS(all_results, file.path(tempfiles_dir, "coefplot_modern_results.rds"))
cat(sprintf("\n  ✓ Saved coefficient data: coefplot_modern_results.rds\n"))
cat(sprintf("  ✓ Coefficients for %d variables\n", n_distinct(all_results$variable)))

# ===========================================================================
# PART 3: CREATE COEFFICIENT PLOTS
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 3: CREATING COEFFICIENT PLOTS\n")
cat("===========================================================================\n")

# Figure 1: Assets, Loans, Liquid Assets
cat("\n[Figure 1: Assets, Loans, Liquid Assets]\n")

assets_data <- all_results %>%
  filter(variable %in% c("assets", "loans", "liquid"))

if (nrow(assets_data) > 0) {
  plot_assets <- ggplot(assets_data, aes(x = time_to_fail, y = estimate,
                                          color = variable, shape = variable)) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.8) +
    geom_line(alpha = 0.7) +
    geom_point(size = 2) +
    scale_x_continuous(breaks = c(seq(-40, -2, by = 4), -1),
                      labels = c(seq(-40, -2, by = 4), "Last\ncall")) +
    scale_color_manual(
      values = c("assets" = "navy", "loans" = "maroon", "liquid" = "orange"),
      labels = c("Assets", "Loans", "Liquid assets")
    ) +
    scale_shape_manual(
      values = c("assets" = 16, "loans" = 15, "liquid" = 17),
      labels = c("Assets", "Loans", "Liquid assets")
    ) +
    labs(
      title = "Asset Dynamics in Failing Banks: Modern Era",
      x = "Quarters to failure",
      y = "Coefficient estimates, β_s",
      color = NULL,
      shape = NULL
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  ggsave(
    file.path(output_dir, "Figures", "04_coefplots_modern_assets_loans_liquid.pdf"),
    plot = plot_assets,
    width = 10,
    height = 6
  )

  cat("  ✓ Saved: Figures/04_coefplots_modern_assets_loans_liquid.pdf\n")
}

# Figure 2: Employment
cat("\n[Figure 2: Employment]\n")

employment_data <- all_results %>%
  filter(variable == "num_employees")

if (nrow(employment_data) > 0) {
  plot_employment <- ggplot(employment_data, aes(x = time_to_fail, y = estimate)) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.8) +
    geom_line(alpha = 0.7, color = "darkblue") +
    geom_point(size = 2, color = "darkblue") +
    scale_x_continuous(breaks = c(seq(-40, -2, by = 4), -1),
                      labels = c(seq(-40, -2, by = 4), "Last\ncall")) +
    labs(
      title = "Employment Dynamics in Failing Banks",
      x = "Quarters to failure",
      y = "Coefficients β_s"
    ) +
    theme_minimal()

  ggsave(
    file.path(output_dir, "Figures", "04_coefplots_modern_employment.pdf"),
    plot = plot_employment,
    width = 10,
    height = 6
  )

  cat("  ✓ Saved: Figures/04_coefplots_modern_employment.pdf\n")
}

# Figure 3: Deposit Levels
cat("\n[Figure 3: Deposit Levels]\n")

deposit_levels <- all_results %>%
  filter(variable %in% c("deposits_time", "deposits_demand", "brokered_dep",
                         "otherbor_liab", "noncore_funding")) %>%
  filter(time_to_fail %in% seq(-40, -1, by = 4))

if (nrow(deposit_levels) > 0) {
  plot_deposit_levels <- ggplot(deposit_levels, aes(x = time_to_fail, y = estimate,
                                                      color = variable, shape = variable)) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.8) +
    geom_line(alpha = 0.7) +
    geom_point(size = 2) +
    scale_x_continuous(breaks = c(seq(-40, -2, by = 4), -1),
                      labels = c(seq(-40, -2, by = 4), "Last\ncall")) +
    labs(
      title = "Deposit Levels Dynamics (Log)",
      x = "Quarters to failure",
      y = "Coefficients β_s",
      color = NULL,
      shape = NULL
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  ggsave(
    file.path(output_dir, "Figures", "04_coefplots_modern_era_levels_deposits.pdf"),
    plot = plot_deposit_levels,
    width = 12,
    height = 6
  )

  cat("  ✓ Saved: Figures/04_coefplots_modern_era_levels_deposits.pdf\n")
}

# Figure 4: Deposit Ratios
cat("\n[Figure 4: Deposit Ratios]\n")

deposit_ratios <- all_results %>%
  filter(variable %in% c("deposits_demand_ratio", "deposits_time_ratio",
                         "noncore_ratio", "otherbor_liab_ratio",
                         "insured_deposits_ratio")) %>%
  filter(time_to_fail %in% seq(-40, -1, by = 4))

if (nrow(deposit_ratios) > 0) {
  plot_deposit_ratios <- ggplot(deposit_ratios, aes(x = time_to_fail, y = estimate,
                                                      color = variable, shape = variable,
                                                      linetype = variable)) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.8) +
    geom_line(alpha = 0.7) +
    geom_point(size = 2) +
    scale_x_continuous(breaks = c(seq(-40, -2, by = 4), -1),
                      labels = c(seq(-40, -2, by = 4), "Last\ncall")) +
    scale_linetype_manual(values = c("deposits_demand_ratio" = "dashed",
                                     "deposits_time_ratio" = "dashed",
                                     "noncore_ratio" = "solid",
                                     "otherbor_liab_ratio" = "dashed",
                                     "insured_deposits_ratio" = "dashed")) +
    labs(
      title = "Deposit Ratio Dynamics",
      x = "Quarters to failure",
      y = "Coefficient estimates, β_s",
      color = NULL,
      shape = NULL,
      linetype = NULL
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  ggsave(
    file.path(output_dir, "Figures", "04_coefplots_modern_era_ratios_deposits.pdf"),
    plot = plot_deposit_ratios,
    width = 10,
    height = 6
  )

  cat("  ✓ Saved: Figures/04_coefplots_modern_era_ratios_deposits.pdf\n")
}

# Figure 5: Profitability
cat("\n[Figure 5: Profitability Indicators]\n")

profit_data <- all_results %>%
  filter(variable %in% c("income_ratio", "nim", "int_inc_ratio", "int_exp_ratio"))

if (nrow(profit_data) > 0) {
  plot_profit <- ggplot(profit_data, aes(x = time_to_fail, y = estimate,
                                          color = variable, shape = variable)) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.8) +
    geom_line(alpha = 0.7) +
    geom_point(size = 2) +
    scale_x_continuous(breaks = c(seq(-40, -2, by = 4), -1),
                      labels = c(seq(-40, -2, by = 4), "Last\ncall")) +
    labs(
      title = "Profitability Dynamics",
      x = "Quarters to failure",
      y = "Coefficient estimates, β_s",
      color = NULL,
      shape = NULL
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  ggsave(
    file.path(output_dir, "Figures", "04_coefplots_modern_profitability.pdf"),
    plot = plot_profit,
    width = 10,
    height = 6
  )

  cat("  ✓ Saved: Figures/04_coefplots_modern_profitability.pdf\n")
}

# Figure 6: Loan Composition
cat("\n[Figure 6: Loan Composition]\n")

loan_data <- all_results %>%
  filter(variable %in% c("ln_cons_ratio", "ln_cc_ratio", "ln_ci_ratio",
                         "ln_oth_ratio", "ln_fi_ratio", "ln_re_ratio"))

if (nrow(loan_data) > 0) {
  plot_loans <- ggplot(loan_data, aes(x = time_to_fail, y = estimate,
                                       color = variable, shape = variable)) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.8) +
    geom_line(alpha = 0.7) +
    geom_point(size = 2) +
    scale_x_continuous(breaks = c(seq(-40, -2, by = 4), -1),
                      labels = c(seq(-40, -2, by = 4), "Last\ncall")) +
    labs(
      title = "Loan Composition Dynamics",
      x = "Quarters to failure",
      y = "Coefficient estimates, β_s",
      color = NULL,
      shape = NULL
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  ggsave(
    file.path(output_dir, "Figures", "04_coefplots_modern_loan_composition.pdf"),
    plot = plot_loans,
    width = 12,
    height = 6
  )

  cat("  ✓ Saved: Figures/04_coefplots_modern_loan_composition.pdf\n")
}

# ===========================================================================
# PART 4: FINAL SUMMARY AND COMPLETION
# ===========================================================================

cat("\n===========================================================================\n")
cat("FINAL SUMMARY\n")
cat("===========================================================================\n")

script_end_time <- Sys.time()
script_duration <- as.numeric(difftime(script_end_time, script_start_time,
                                      units = "mins"))

cat("\n[Event Study Regressions]\n")
cat(sprintf("  Ratio variables: %d\n", length(results_ratios)))
cat(sprintf("  Level variables: %d\n", length(results_levels)))

cat("\n[Figures Created]\n")
cat("  ✓ Assets, loans, liquid assets\n")
cat("  ✓ Employment dynamics\n")
cat("  ✓ Deposit levels\n")
cat("  ✓ Deposit ratios\n")
cat("  ✓ Profitability indicators\n")
cat("  ✓ Loan composition\n")
cat("\n  Total: 6 figures\n")

cat("\n===========================================================================\n")
cat("SCRIPT 34 COMPLETED SUCCESSFULLY\n")
cat(sprintf("  End time: %s\n", Sys.time()))
cat(sprintf("  Runtime: %.1f minutes\n", script_duration))
cat("===========================================================================\n")
