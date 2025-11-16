# ===========================================================================
# Script 71: Banks at Risk - Aggregate Failure Prediction
# ===========================================================================
# This script analyzes aggregate failure rates using out-of-sample predictions
# from LPM models. Creates scatter plots comparing predicted vs. actual
# failure rates over time.
#
# Key outputs:
# - Aggregate time series of predicted vs. actual failure rates
# - Scatter plots for full sample and by era
# - Regression tables of actual on predicted failure rates
#
# v2.5 enhancements:
# - Verbose console diagnostics throughout
# - Detailed progress tracking
# ===========================================================================

cat("===========================================================================\n")
cat("SCRIPT 71: BANKS AT RISK - AGGREGATE FAILURE PREDICTION\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
script_start_time <- Sys.time()

# --- Load Required Libraries ---
cat("\n[Loading Libraries]\n")
suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(ggplot2)
  library(haven)
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
# PART 1: LOAD AND PREPARE PREDICTIONS
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 1: LOADING PREDICTION DATA\n")
cat("===========================================================================\n")

# Load predictions for Models 1-4
cat("\n[Loading LPM Model Predictions]\n")

models_to_load <- 1:4
time_series_data <- list()

for (i in models_to_load) {
  cat(sprintf("  Loading Model %d...\n", i))

  # Historical predictions
  hist_file <- file.path(tempfiles_dir, sprintf("PV_LPM_%d_1863_1934.rds", i))
  # Modern predictions
  mod_file <- file.path(tempfiles_dir, sprintf("PV_LPM_%d_1959_2024.rds", i))

  if (file.exists(hist_file) && file.exists(mod_file)) {
    hist_pred <- readRDS(hist_file)
    hist_pred <- hist_pred %>%
      rename(p_oos_F1_failure = pred_oos,
             p_F1_failure = pred_insample,
             F1_failure = outcome)
    mod_pred <- readRDS(mod_file)

    mod_pred <- mod_pred %>%
      rename(p_oos_F1_failure = pred_oos,
             p_F1_failure = pred_insample,
             F1_failure = outcome)


    # Combine
    combined_pred <- bind_rows(hist_pred, mod_pred) %>%
      filter(!is.na(p_oos_F1_failure))

    cat(sprintf("    Combined: %d observations\n", nrow(combined_pred)))

    # Aggregate to year level
    year_agg <- combined_pred %>%
      group_by(year) %>%
      summarise(
        failure_rate = mean(F1_failure, na.rm = TRUE),
        pred_insample = mean(p_F1_failure, na.rm = TRUE),
        pred_oos = mean(p_oos_F1_failure, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      mutate(
        # Adjust year to t+1 (predicting next year)
        year = year + 1,
        # Convert to percentages
        failure_rate = failure_rate * 100,
        pred_insample = pred_insample * 100,
        pred_oos = pred_oos * 100,
        model_id = i
      )

    time_series_data[[i]] <- year_agg

    cat(sprintf("    Aggregated to %d years\n", nrow(year_agg)))

  } else {
    cat(sprintf("    ⚠ WARNING: Prediction files not found for Model %d\n", i))
  }
}

# Focus on Model 4 for main analysis (baseline model)
if (length(time_series_data) >= 4) {
  data_ts <- time_series_data[[4]]
  cat(sprintf("\n  Using Model 4 for analysis: %d years\n", nrow(data_ts)))
} else {
  cat("\n  ⚠ ERROR: Model 4 predictions not available\n")
  cat("  Exiting script\n")
  quit(save = "no")
}

# ===========================================================================
# PART 2: CREATE ERA INDICATORS
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 2: CREATING ERA INDICATORS\n")
cat("===========================================================================\n")

data_ts <- data_ts %>%
  mutate(
    era = case_when(
      year <= 1904 ~ "National Banking Era (1863-1904)",
      year >= 1905 & year <= 1928 ~ "Early Fed (1914-1928)",
      year >= 1929 & year <= 1935 ~ "Great Depression (1929-1935)",
      year >= 1959 ~ "Modern Era (1959-2024)",
      TRUE ~ NA_character_
    ),
    era_num = case_when(
      year <= 1904 ~ 1,
      year >= 1905 & year <= 1928 ~ 2,
      year >= 1929 & year <= 1935 ~ 3,
      year >= 1959 ~ 4,
      TRUE ~ NA_real_
    ),
    # Label specific crisis years
    year_label = case_when(
      year %in% c(2007:2012, 1929:1935, 1890:1896, 1924:1930, 1907, 1982:1990) ~ as.character(year),
      TRUE ~ NA_character_
    )
  )

cat("  ✓ Era indicators created\n")

# ===========================================================================
# PART 3: MAIN SCATTER PLOT - PREDICTED VS. ACTUAL
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 3: MAIN SCATTER PLOT - PREDICTED VS. ACTUAL FAILURE RATES\n")
cat("===========================================================================\n")

cat("\n[Creating Full Sample Scatter Plot]\n")

# Add linear fit lines
fit_full <- lm(failure_rate ~ pred_oos, data = data_ts)
fit_no_gd <- lm(failure_rate ~ pred_oos, data = data_ts %>% filter(!(year >= 1929 & year <= 1934)))

plot_main <- ggplot(data_ts, aes(x = pred_oos, y = failure_rate)) +
  geom_point(aes(color = era, shape = era), size = 2, alpha = 0.7) +
  geom_text(aes(label = year_label), size = 2.5, hjust = -0.2, vjust = -0.2, na.rm = TRUE) +
  geom_abline(slope = coef(fit_full)[2], intercept = coef(fit_full)[1],
              color = "navy", linewidth = 0.8, linetype = "solid") +
  geom_abline(slope = coef(fit_no_gd)[2], intercept = coef(fit_no_gd)[1],
              color = "navy", linewidth = 0.8, linetype = "dashed", alpha = 0.5) +
  scale_color_manual(
    values = c("National Banking Era (1863-1904)" = "red",
               "Early Fed (1914-1928)" = "navy",
               "Great Depression (1929-1935)" = "black",
               "Modern Era (1959-2024)" = "lightblue")
  ) +
  scale_shape_manual(
    values = c("National Banking Era (1863-1904)" = 17,
               "Early Fed (1914-1928)" = 15,
               "Great Depression (1929-1935)" = 16,
               "Modern Era (1959-2024)" = 3)
  ) +
  labs(
    title = "Aggregate Predicted vs. Actual Failure Rates",
    x = "Predicted failure rate (out-of-sample, %)",
    y = "Realized failure rate (%)",
    color = NULL,
    shape = NULL
  ) +
  theme_minimal() +
  theme(legend.position = "bottom", legend.direction = "vertical")

ggsave(
  file.path(output_dir, "Figures", "06_aggregate_predicted_actual.pdf"),
  plot = plot_main,
  width = 10,
  height = 8
)

cat("  ✓ Saved: Figures/06_aggregate_predicted_actual.pdf\n")

# ===========================================================================
# PART 4: SCATTER PLOTS BY ERA
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 4: SCATTER PLOTS BY ERA\n")
cat("===========================================================================\n")

cat("\n[Creating Era-Specific Plots]\n")

# Define eras for separate plots
era_list <- list(
  list(name = "National Banking Era (1863-1905)", years = c(NA, 1905)),
  list(name = "Early Fed (1917-1928)", years = c(1905, 1928)),
  list(name = "Great Depression (1929-1935)", years = c(1929, 1935)),
  list(name = "Modern Era (1959-2024)", years = c(1945, NA))
)

era_plots <- list()

for (i in seq_along(era_list)) {
  era_info <- era_list[[i]]

  data_era <- data_ts %>%
    filter((is.na(era_info$years[1]) | year >= era_info$years[1]) &
           (is.na(era_info$years[2]) | year <= era_info$years[2]))

  if (nrow(data_era) > 0) {
    p <- ggplot(data_era, aes(x = pred_oos, y = failure_rate)) +
      geom_point(size = 2, color = "darkblue") +
      geom_text(aes(label = year), size = 2.5, hjust = -0.2, vjust = -0.2) +
      labs(
        title = era_info$name,
        x = "Predicted failure rate (out-of-sample, %)",
        y = "Realized failure rate (%)"
      ) +
      theme_minimal()

    era_plots[[i]] <- p
  }
}

# Combine plots
if (length(era_plots) == 4) {
  combined_plot <- cowplot::plot_grid(
    era_plots[[1]], era_plots[[2]], era_plots[[3]], era_plots[[4]],
    nrow = 2, ncol = 2
  )

  ggsave(
    file.path(output_dir, "Figures", "06_aggregate_predicted_actual_by_era.pdf"),
    plot = combined_plot,
    width = 12,
    height = 10
  )

  cat("  ✓ Saved: Figures/06_aggregate_predicted_actual_by_era.pdf\n")
} else {
  # If cowplot not available, save individually
  for (i in seq_along(era_plots)) {
    ggsave(
      file.path(output_dir, "Figures", sprintf("06_aggregate_predicted_actual_era_%d.pdf", i)),
      plot = era_plots[[i]],
      width = 6,
      height = 5
    )
  }
  cat(sprintf("  ✓ Saved %d individual era plots\n", length(era_plots)))
}

# ===========================================================================
# PART 5: REGRESSION ANALYSIS
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 5: REGRESSION ANALYSIS\n")
cat("===========================================================================\n")

cat("\n[Running Regressions: Actual on Predicted]\n")

# Full sample
reg_full <- lm(failure_rate ~ pred_oos, data = data_ts)

# Excluding Great Depression
reg_no_gd <- lm(failure_rate ~ pred_oos,
                data = data_ts %>% filter(!(year >= 1929 & year <= 1934)))

# Pre-1935
reg_pre1935 <- lm(failure_rate ~ pred_oos,
                  data = data_ts %>% filter(year <= 1935))

# Post-1959
reg_post1959 <- lm(failure_rate ~ pred_oos,
                   data = data_ts %>% filter(year >= 1959))

cat("\n  Full sample:\n")
cat(sprintf("    Coefficient: %.3f\n", coef(reg_full)[2]))
cat(sprintf("    R-squared: %.3f\n", summary(reg_full)$r.squared))

cat("\n  Excluding Great Depression:\n")
cat(sprintf("    Coefficient: %.3f\n", coef(reg_no_gd)[2]))
cat(sprintf("    R-squared: %.3f\n", summary(reg_no_gd)$r.squared))

# Save regression results
reg_results <- data.frame(
  Sample = c("Full sample", "Excl. Great Depression", "Pre-1935", "Post-1959"),
  Coefficient = c(coef(reg_full)[2], coef(reg_no_gd)[2],
                  coef(reg_pre1935)[2], coef(reg_post1959)[2]),
  R_squared = c(summary(reg_full)$r.squared, summary(reg_no_gd)$r.squared,
                summary(reg_pre1935)$r.squared, summary(reg_post1959)$r.squared),
  N = c(nobs(reg_full), nobs(reg_no_gd), nobs(reg_pre1935), nobs(reg_post1959))
)

print(reg_results)

saveRDS(reg_results, file.path(tempfiles_dir, "banks_at_risk_regressions.rds"))
write_dta(reg_results, file.path(tempfiles_dir, "banks_at_risk_regressions.dta"))

cat("\n  ✓ Saved: banks_at_risk_regressions.rds/.dta\n")

# ===========================================================================
# PART 6: FINAL SUMMARY AND COMPLETION
# ===========================================================================

cat("\n===========================================================================\n")
cat("FINAL SUMMARY\n")
cat("===========================================================================\n")

script_end_time <- Sys.time()
script_duration <- as.numeric(difftime(script_end_time, script_start_time,
                                      units = "mins"))

cat("\n[Key Results]\n")
cat(sprintf("  Years analyzed: %d\n", nrow(data_ts)))
cat(sprintf("  Full sample R²: %.3f\n", summary(reg_full)$r.squared))
cat(sprintf("  Slope coefficient: %.3f\n", coef(reg_full)[2]))

cat("\n[Figures Created]\n")
cat("  ✓ Aggregate predicted vs. actual (full sample)\n")
cat("  ✓ By-era scatter plots\n")

cat("\n===========================================================================\n")
cat("SCRIPT 71 COMPLETED SUCCESSFULLY\n")
cat(sprintf("  End time: %s\n", Sys.time()))
cat(sprintf("  Runtime: %.1f minutes\n", script_duration))
cat("===========================================================================\n")
