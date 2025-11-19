# ===========================================================================
# MASTER SCRIPT - Failing Banks R Replication
# ===========================================================================
# R translation of Stata 00_master.do from QJE replication kit
# Version 11.1 Definitive - Executes all 31 analysis scripts in sequence
# ===========================================================================

library(here)

cat("===========================================================================\n")
cat("FAILING BANKS R REPLICATION v11.1 DEFINITIVE\n")
cat("R Translation of Stata QJE Replication Kit\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
cat(sprintf("Working directory: %s\n", here::here()))
cat("===========================================================================\n\n")

master_start_time <- Sys.time()

# ===========================================================================
# LOAD SETUP (Stata equivalent: do common.do)
# ===========================================================================

cat("Loading setup script (00_setup.R)...\n")
source(here::here("code", "00_setup.R"))

# ===========================================================================
# DEFINE ALL SCRIPTS (Matching Stata 00_master.do exactly)
# ===========================================================================

all_scripts <- c(
    # Data Import (Scripts 01-03)
    "01_import_GDP.R",
    "02_import_GFD_CPI.R",
    "03_import_GFD_Yields.R",

    # Data Processing (Scripts 04-08)
    "04_create-historical-dataset.R",
    "05_create-modern-dataset.R",
    "06_create-outflows-receivership-data.R",
    "07_combine-historical-modern-datasets-panel.R",
    "08_data_for_coefplots.R",

    # Descriptive Statistics (Scripts 21-22)
    "21_descriptives_failures_time_series.R",
    "22_descriptives_table.R",

    # Section 4: Basic Facts About Bank Failures (Scripts 31-35)
    "31_coefplots_combined.R",
    "32_prob_of_failure_cross_section.R",
    "33_coefplots_historical.R",
    "34_coefplots_modern_era.R",
    "35_conditional_prob_failure.R",

    # Section 5: Predictability of Bank Failures (Scripts 51-55)
    "51_auc.R",
    "52_auc_glm.R",
    "53_auc_by_size.R",
    "54_auc_tpr_fpr.R",
    "55_pr_auc.R",

    # Section 6: Bank Runs (Scripts 61-62)
    "61_deposits_assets_before_failure.R",
    "62_predicted_probability_of_failure.R",

    # Section 7: Aggregate Waves of Bank Failures (Script 71)
    "71_banks_at_risk.R",

    # Section 8: Recovery Rates (Scripts 81-87)
    "81_recovery_rates.R",
    "82_predicting_recovery_rates.R",
    "83_rho_v.R",
    "84_recovery_and_deposit_outflows.R",
    "85_causes_of_failure.R",
    "86_receivership_length.R",
    "87_depositor_recovery_rates_dynamics.R",

    # Appendix (Script 99)
    "99_failures_rates_appendix.R"
)

cat(sprintf("\nTotal scripts to execute: %d\n\n", length(all_scripts)))

# ===========================================================================
# EXECUTE ALL SCRIPTS SEQUENTIALLY
# ===========================================================================

cat("===========================================================================\n")
cat("EXECUTING SCRIPTS\n")
cat("===========================================================================\n\n")

script_counter <- 0
successful_scripts <- 0
failed_scripts <- 0

for (script_name in all_scripts) {
    script_counter <- script_counter + 1

    cat(sprintf("\n[%d/%d] Running: %s\n",
                script_counter, length(all_scripts), script_name))
    cat(strrep("-", 75), "\n")

    script_path <- here::here("code", script_name)

    # Check if script exists
    if (!file.exists(script_path)) {
        cat(sprintf("ERROR: Script file not found: %s\n", script_path))
        failed_scripts <- failed_scripts + 1
        next
    }

    # Time the execution
    script_start <- Sys.time()

    # Run the script
    script_success <- tryCatch({
        source(script_path, echo = FALSE)
        TRUE
    }, error = function(e) {
        error_msg <- as.character(e$message)
        cat(sprintf("\nERROR in %s: %s\n", script_name, error_msg))

        # For critical data processing scripts (01-08), stop execution
        script_num <- as.numeric(substr(script_name, 1, 2))
        if (!is.na(script_num) && script_num <= 8) {
            cat("\nCRITICAL ERROR: Data processing failed. Stopping execution.\n")
            stop(sprintf("Critical failure in %s: %s", script_name, error_msg))
        }

        FALSE
    })

    # Calculate runtime
    script_end <- Sys.time()
    runtime_mins <- as.numeric(difftime(script_end, script_start, units = "mins"))

    if (script_success) {
        cat(sprintf("\n✓ SUCCESS: %s (%.1f minutes)\n", script_name, runtime_mins))
        successful_scripts <- successful_scripts + 1
    } else {
        cat(sprintf("\n✗ FAILED: %s\n", script_name))
        failed_scripts <- failed_scripts + 1
    }

    # Clean up memory
    gc(verbose = FALSE)
}

# ===========================================================================
# FINAL SUMMARY
# ===========================================================================

cat("\n===========================================================================\n")
cat("EXECUTION COMPLETE\n")
cat("===========================================================================\n\n")

# Calculate total runtime
master_end <- Sys.time()
total_runtime_hours <- as.numeric(difftime(master_end, master_start_time, units = "hours"))

cat(sprintf("Total runtime: %.2f hours (%.0f minutes)\n",
            total_runtime_hours, total_runtime_hours * 60))
cat(sprintf("Scripts successful: %d/%d (%.1f%%)\n",
            successful_scripts, length(all_scripts),
            100 * successful_scripts / length(all_scripts)))
cat(sprintf("Scripts failed: %d/%d\n", failed_scripts, length(all_scripts)))

if (successful_scripts == length(all_scripts)) {
    cat("\n🎉 CONGRATULATIONS! All scripts completed successfully!\n")
    cat("The replication is complete.\n")
} else if (failed_scripts > 0) {
    cat(sprintf("\n⚠ WARNING: %d scripts failed. Review the output above for details.\n",
                failed_scripts))
}

cat("\n===========================================================================\n")
cat("END OF EXECUTION\n")
cat("===========================================================================\n")
