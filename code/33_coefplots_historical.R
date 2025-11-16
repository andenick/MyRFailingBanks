# ===========================================================================
# Script 33: Coefficient Plots - Dynamics in Failing Banks (1863-1935)
# ===========================================================================
# This script creates coefficient plots showing how key variables evolve
# in the years leading up to bank failure. Uses event study methodology
# with bank fixed effects.
#
# Key outputs:
# - Solvency dynamics (surplus ratio, OREO ratio, profit shortfall)
# - Funding dynamics (deposits, time/demand deposits, noncore funding)
# - Asset composition (loans, liquid assets)
# - Balance sheet levels (assets, deposits, equity)
#
# v2.5 enhancements:
# - Verbose console diagnostics throughout
# - Detailed progress tracking
# ===========================================================================

cat("===========================================================================\n")
cat("SCRIPT 33: COEFFICIENT PLOTS - HISTORICAL DYNAMICS (1863-1935)\n")
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

# Filter to pre-1935 and failed banks within 10 years of failure
cat("\n[Filtering to Historical Failed Banks]\n")

data_hist <- data_full %>%
  filter(year < 1935,
         time_to_fail >= -10,
         time_to_fail <= 0)

cat(sprintf("  Filtered data: %d observations\n", nrow(data_hist)))
cat(sprintf("  Failed banks: %d\n", n_distinct(data_hist$bank_id, na.rm = TRUE)))
cat(sprintf("  Years: %d to %d\n", min(data_hist$year, na.rm = TRUE),
            max(data_hist$year, na.rm = TRUE)))

# Replace variables that were not reported in certain periods
cat("\n[Adjusting for reporting periods]\n")

data_hist <- data_hist %>%
  mutate(
    oreo_ratio = ifelse(year > 1904, NA, oreo_ratio),
    profits_ratio = ifelse(year >= 1905 & year <= 1928, NA, profits_ratio),
    profit_shortfall = ifelse(year >= 1905 & year <= 1928, NA, profit_shortfall),
    time_ratio = ifelse(final_year < 1915 | final_year > 1928, NA, time_ratio),
    demand_ratio = ifelse(final_year < 1915 | final_year > 1928, NA, demand_ratio),
    emergency_borrowing = ifelse(final_year >= 1905 & final_year <= 1928, NA, emergency_borrowing),
    time_deposits = ifelse(final_year < 1915 | final_year > 1928, NA, time_deposits),
    demand_deposits = ifelse(final_year < 1915 | final_year > 1928, NA, demand_deposits)
  )

cat("  ✓ Reporting period adjustments applied\n")

# ===========================================================================
# PART 2: RUN EVENT STUDY REGRESSIONS
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 2: EVENT STUDY REGRESSIONS\n")
cat("===========================================================================\n")

cat("\nRunning event study regressions for each variable...\n")
cat("This estimates how each variable evolves relative to baseline (t=-10)\n\n")

# Define variable lists
ratio_vars <- c("oreo_ratio", "surplus_ratio", "profits_ratio", "profit_shortfall",
                "deposit_ratio", "time_ratio", "demand_ratio", "leverage",
                "noncore_ratio", "emergency_borrowing")

level_vars <- c("assets", "liquid", "loans", "interbank", "deposits",
                "emergency", "equity", "time_deposits", "demand_deposits",
                "res_funding")

# Helper function to run event study regression
RunEventStudy <- function(data, var_name, use_levels = FALSE) {

  cat(sprintf("  [%s]\n", var_name))

  # Prepare data
  data_reg <- data %>%
    filter(!is.na(.data[[var_name]])) %>%
    mutate(
      time_indicator = as.factor(time_to_fail + 10),  # Shift so 0 is baseline (t=-10)
      var_value = if (use_levels) log(.data[[var_name]]) else .data[[var_name]]
    )

  if (nrow(data_reg) < 50) {
    cat("    ⚠ Insufficient data, skipping\n")
    return(NULL)
  }

  # Run regression with bank fixed effects
  # Cluster by bank_id (and year for ratios)
  if (use_levels) {
    # Levels: cluster by bank only
    model <- tryCatch({
      feols(var_value ~ i(time_indicator, ref = 0) | bank_id,
            data = data_reg,
            cluster = ~bank_id)
    }, error = function(e) NULL)
  } else {
    # Ratios: cluster by bank and year
    model <- tryCatch({
      feols(var_value ~ i(time_indicator, ref = 0) | bank_id,
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
      time_to_fail = as.numeric(gsub("time_indicator::", "", term)) - 10,
      variable = var_name
    ) %>%
    select(variable, time_to_fail, estimate, std.error, conf.low, conf.high)

  # Add baseline (t=-10) with coefficient = 0
  baseline <- data.frame(
    variable = var_name,
    time_to_fail = -10,
    estimate = 0,
    std.error = 0,
    conf.low = 0,
    conf.high = 0
  )

  coef_df <- bind_rows(baseline, coef_df)

  cat(sprintf("    ✓ Estimated %d time periods\n", nrow(coef_df) - 1))

  return(coef_df)
}

# Run regressions for ratio variables
cat("\n[Ratio Variables]\n")
results_ratios <- list()

for (var in ratio_vars) {
  result <- RunEventStudy(data_hist, var, use_levels = FALSE)
  if (!is.null(result)) {
    results_ratios[[var]] <- result
  }
}

# Run regressions for level variables (in logs)
cat("\n[Level Variables (in logs)]\n")
results_levels <- list()

for (var in level_vars) {
  result <- RunEventStudy(data_hist, var, use_levels = TRUE)
  if (!is.null(result)) {
    results_levels[[var]] <- result
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
saveRDS(all_results, file.path(tempfiles_dir, "coefplot_historical_results.rds"))
cat(sprintf("\n  ✓ Saved coefficient data: coefplot_historical_results.rds\n"))
cat(sprintf("  ✓ Coefficients for %d variables\n", n_distinct(all_results$variable)))

# ===========================================================================
# PART 3: CREATE COEFFICIENT PLOTS
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 3: CREATING COEFFICIENT PLOTS\n")
cat("===========================================================================\n")

# Figure 1: Solvency Dynamics (Surplus ratio, OREO ratio, Profit shortfall)
cat("\n[Figure 1: Solvency Dynamics]\n")

solvency_data <- all_results %>%
  filter(variable %in% c("surplus_ratio", "oreo_ratio", "profit_shortfall"))

if (nrow(solvency_data) > 0) {
  plot_solvency <- ggplot(solvency_data, aes(x = time_to_fail, y = estimate,
                                              color = variable, shape = variable)) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.8) +
    geom_line(alpha = 0.7) +
    geom_point(size = 2) +
    geom_errorbar(aes(ymin = conf.low, ymax = conf.high), width = 0.2, alpha = 0.5) +
    scale_x_continuous(breaks = -10:-1, labels = c(-10:-2, "Last\ncall")) +
    scale_color_manual(
      values = c("surplus_ratio" = "red", "oreo_ratio" = "navy",
                 "profit_shortfall" = "darkgreen"),
      labels = c("Surplus profits / equity",
                 "Non-performing loans / loans (1889-1904)",
                 "Profit shortfall")
    ) +
    scale_shape_manual(
      values = c("surplus_ratio" = 16, "oreo_ratio" = 15, "profit_shortfall" = 17),
      labels = c("Surplus profits / equity",
                 "Non-performing loans / loans (1889-1904)",
                 "Profit shortfall")
    ) +
    labs(
      title = "Solvency Dynamics in Failing Banks: 1863-1934",
      x = "Years to failure",
      y = "Coefficient β_s",
      color = NULL,
      shape = NULL
    ) +
    theme_minimal() +
    theme(legend.position = "bottom", legend.direction = "vertical")

  ggsave(
    file.path(output_dir, "Figures", "04_coefplots_pre_FDIC_ratio_equity.pdf"),
    plot = plot_solvency,
    width = 10,
    height = 6
  )

  cat("  ✓ Saved: Figures/04_coefplots_pre_FDIC_ratio_equity.pdf\n")
}

# Figure 2: Funding Dynamics
cat("\n[Figure 2: Funding Dynamics]\n")

funding_data <- all_results %>%
  filter(variable %in% c("demand_ratio", "time_ratio", "noncore_ratio",
                         "deposit_ratio", "emergency_borrowing"))

if (nrow(funding_data) > 0) {
  plot_funding <- ggplot(funding_data, aes(x = time_to_fail, y = estimate,
                                            color = variable, shape = variable)) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.8) +
    geom_line(alpha = 0.7) +
    geom_point(size = 2) +
    scale_x_continuous(breaks = -10:-1, labels = c(-10:-2, "Last\ncall")) +
    scale_color_manual(
      values = c("demand_ratio" = "blue", "time_ratio" = "purple",
                 "noncore_ratio" = "darkred", "deposit_ratio" = "orange",
                 "emergency_borrowing" = "darkgreen"),
      labels = c("Demand deposits/assets (1915-1928)",
                 "Time deposits/assets (1915-1928)",
                 "Noncore funding/assets (1865-1934)",
                 "Deposits/assets (1865-1934)",
                 "Emergency borrowing")
    ) +
    scale_shape_manual(
      values = c("demand_ratio" = 16, "time_ratio" = 17,
                 "noncore_ratio" = 15, "deposit_ratio" = 18,
                 "emergency_borrowing" = 4),
      labels = c("Demand deposits/assets (1915-1928)",
                 "Time deposits/assets (1915-1928)",
                 "Noncore funding/assets (1865-1934)",
                 "Deposits/assets (1865-1934)",
                 "Emergency borrowing")
    ) +
    labs(
      title = "Funding Dynamics in Failing Banks: 1865-1934",
      x = "Years to failure",
      y = "Coefficient estimates, β_s",
      color = NULL,
      shape = NULL
    ) +
    theme_minimal() +
    theme(legend.position = "bottom", legend.direction = "vertical")

  ggsave(
    file.path(output_dir, "Figures", "04_coefplots_funding_preFDIC.pdf"),
    plot = plot_funding,
    width = 10,
    height = 6
  )

  cat("  ✓ Saved: Figures/04_coefplots_funding_preFDIC.pdf\n")
}

# Figure 3: Balance Sheet Levels - Funding
cat("\n[Figure 3: Balance Sheet Levels - Funding]\n")

levels_funding <- all_results %>%
  filter(variable %in% c("assets", "deposits", "res_funding",
                         "demand_deposits", "time_deposits"))

if (nrow(levels_funding) > 0) {
  plot_levels_funding <- ggplot(levels_funding, aes(x = time_to_fail, y = estimate,
                                                      color = variable, shape = variable)) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.8) +
    geom_line(alpha = 0.7) +
    geom_point(size = 2) +
    scale_x_continuous(breaks = -10:-1, labels = c(-10:-2, "Last\ncall")) +
    labs(
      title = "Balance Sheet Levels - Funding (Log)",
      x = "Years to Failure",
      y = "Coefficients β_s",
      color = NULL,
      shape = NULL
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  ggsave(
    file.path(output_dir, "Figures", "04_coefplots_historical_levels_funding.pdf"),
    plot = plot_levels_funding,
    width = 12,
    height = 6
  )

  cat("  ✓ Saved: Figures/04_coefplots_historical_levels_funding.pdf\n")
}

# Figure 4: Balance Sheet Levels - Assets
cat("\n[Figure 4: Balance Sheet Levels - Assets]\n")

levels_assets <- all_results %>%
  filter(variable %in% c("assets", "loans", "liquid"))

if (nrow(levels_assets) > 0) {
  plot_levels_assets <- ggplot(levels_assets, aes(x = time_to_fail, y = estimate,
                                                    color = variable, shape = variable)) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.8) +
    geom_line(alpha = 0.7) +
    geom_point(size = 2) +
    scale_x_continuous(breaks = -10:-1, labels = c(-10:-2, "Last\ncall")) +
    labs(
      title = "Balance Sheet Levels - Assets (Log)",
      x = "Years to Failure",
      y = "Coefficients β_s",
      color = NULL,
      shape = NULL
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  ggsave(
    file.path(output_dir, "Figures", "04_coefplots_historical_levels_assets.pdf"),
    plot = plot_levels_assets,
    width = 10,
    height = 6
  )

  cat("  ✓ Saved: Figures/04_coefplots_historical_levels_assets.pdf\n")
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
cat("  ✓ Solvency dynamics\n")
cat("  ✓ Funding dynamics\n")
cat("  ✓ Balance sheet levels - funding\n")
cat("  ✓ Balance sheet levels - assets\n")
cat("\n  Total: 4 figures\n")

cat("\n===========================================================================\n")
cat("SCRIPT 33 COMPLETED SUCCESSFULLY\n")
cat(sprintf("  End time: %s\n", Sys.time()))
cat(sprintf("  Runtime: %.1f minutes\n", script_duration))
cat("===========================================================================\n")
