# ===========================================================================
# Master Script - R Replication of Failing Banks Analysis
# ===========================================================================
# Replicates: 00_master.do from Stata QJE replication kit
# Executes all 31 core scripts in exact order matching Stata
# ===========================================================================

# CRITICAL: Load here package first
library(here)

cat("===========================================================================\n")
cat("FAILING BANKS R REPLICATION - AUTOMATIC EXECUTION (NO PROMPTS)\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
cat("This script will run completely automatically - no user input required.\n")
cat("Monitor progress in logs/progress.csv\n")
cat("===========================================================================\n\n")

master_start_time <- Sys.time()

# ===========================================================================
# 0. SETUP LOGGING
# ===========================================================================

# Create logs directory using here
log_dir <- here::here("logs")
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)

# Master log file
master_log <- file.path(log_dir, paste0("master_log_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".txt"))
progress_file <- file.path(log_dir, "progress.csv")

cat(sprintf("Log directory: %s\n", log_dir))
cat(sprintf("Progress file: %s\n\n", progress_file))

# Initialize or load progress tracking
if (file.exists(progress_file)) {
    cat("Found existing progress file - will resume from last successful script.\n")
    progress_df <- read.csv(progress_file, stringsAsFactors = FALSE)
    completed_scripts <- unique(progress_df$script[progress_df$status == "SUCCESS"])
    cat(sprintf("Scripts already completed: %d\n\n", length(completed_scripts)))
} else {
    cat("Creating new progress file.\n\n")
    progress_df <- data.frame(
        script = character(),
        status = character(),
        runtime = numeric(),
        memory_mb = numeric(),
        error_msg = character(),
        timestamp = character(),
        stringsAsFactors = FALSE
    )
    write.csv(progress_df, progress_file, row.names = FALSE)
    completed_scripts <- character()
}

# Function to log progress
log_message <- function(msg) {
    cat(msg)
    cat(msg, file = master_log, append = TRUE)
}

# Function to update progress
update_progress <- function(script_name, status, runtime = NA, memory = NA, error_msg = "") {
    new_row <- data.frame(
        script = script_name,
        status = status,
        runtime = runtime,
        memory_mb = memory,
        error_msg = error_msg,
        timestamp = as.character(Sys.time()),
        stringsAsFactors = FALSE
    )

    # Read current progress (in case another process updated it)
    if (file.exists(progress_file)) {
        progress_df <- read.csv(progress_file, stringsAsFactors = FALSE)
    }

    # Add new row
    progress_df <- rbind(progress_df, new_row)

    # Save
    write.csv(progress_df, progress_file, row.names = FALSE)
}

# ===========================================================================
# 1. LOAD PACKAGES AND SOURCE SETUP
# ===========================================================================

log_message("===========================================================================\n")
log_message("SECTION 1: PACKAGE SETUP\n")
log_message("===========================================================================\n\n")

# Required packages (here already loaded)
required_packages <- c("tidyverse", "haven", "fixest",
                      "lubridate", "scales", "readxl")

log_message("Loading required packages...\n")
for (pkg in required_packages) {
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
        log_message(sprintf("Installing %s...\n", pkg))
        install.packages(pkg, quiet = TRUE)
        library(pkg, character.only = TRUE, quietly = TRUE)
    }
}
log_message("All packages loaded.\n\n")

# Source setup script
log_message("Sourcing setup script...\n")
source(here::here("code", "00_setup.R"))
log_message("Setup complete.\n\n")

# ===========================================================================
# 2. DEFINE SCRIPTS TO RUN
# ===========================================================================

log_message("===========================================================================\n")
log_message("SECTION 2: SCRIPT DEFINITIONS\n")
log_message("===========================================================================\n\n")

# Define all scripts in execution order
all_scripts <- c(
    # Data import and processing (01-08)
    "01_import_GDP.R",
    "02_import_GFD_CPI.R",
    "03_import_GFD_Yields.R",
    "04_create-historical-dataset.R",
    "05_create-modern-dataset.R",
    "06_create-outflows-receivership-data.R",
    "07_combine-historical-modern-datasets-panel.R",
    "08_data_for_coefplots.R",

    # Descriptive statistics (21-35)
    "21_descriptives_failures_time_series.R",
    "22_descriptives_table.R",
    "31_coefplots_combined.R",
    "32_prob_of_failure_cross_section.R",
    "33_coefplots_historical.R",
    "34_coefplots_modern_era.R",
    "35_conditional_prob_failure.R",

    # AUC analysis (51-55)
    "51_auc.R",
    "52_auc_glm.R",
    "53_auc_by_size.R",
    "54_auc_tpr_fpr.R",
    "55_pr_auc.R",

    # Additional analyses (61-87)
    "61_deposits_assets_before_failure.R",
    "62_predicted_probability_of_failure.R",
    "71_banks_at_risk.R",
    "81_recovery_rates.R",
    "82_predicting_recovery_rates.R",
    "83_rho_v.R",
    "84_recovery_and_deposit_outflows.R",
    "85_causes_of_failure.R",
    "86_receivership_length.R",
    "87_depositor_recovery_rates_dynamics.R",

    # Export
    "99_failures_rates_appendix.R"
)

log_message(sprintf("Total scripts to run: %d\n", length(all_scripts)))

# Determine which scripts to run
scripts_to_run <- setdiff(all_scripts, completed_scripts)
log_message(sprintf("Scripts remaining: %d\n\n", length(scripts_to_run)))

if (length(scripts_to_run) == 0) {
    log_message("All scripts have already been completed successfully!\n")
    log_message("===========================================================================\n")
    quit(save = "no")
}

# ===========================================================================
# 3. RUN SCRIPTS
# ===========================================================================

log_message("===========================================================================\n")
log_message("SECTION 3: EXECUTING SCRIPTS\n")
log_message("===========================================================================\n\n")

# Counter for display
script_counter <- length(completed_scripts)

for (script_name in scripts_to_run) {
    script_counter <- script_counter + 1

    log_message(sprintf("\n[%d/%d] Running: %s\n",
                       script_counter, length(all_scripts), script_name))
    log_message(strrep("-", 50))
    log_message("\n")

    script_path <- here::here("code", script_name)

    # Check if script exists
    if (!file.exists(script_path)) {
        log_message(sprintf("ERROR: Script file not found: %s\n", script_path))
        update_progress(script_name, "NOT_FOUND", 0, 0, "File not found")
        next
    }

    # Capture memory before
    gc()
    mem_before <- sum(gc()[, 2])

    # Time the execution
    script_start <- Sys.time()

    # Run the script
    script_success <- tryCatch({
        source(script_path, echo = FALSE)
        TRUE
    }, error = function(e) {
        error_msg <- as.character(e$message)
        log_message(sprintf("\nERROR in %s: %s\n", script_name, error_msg))

        # Save to progress
        runtime_mins <- as.numeric(difftime(Sys.time(), script_start, units = "mins"))
        gc()
        mem_used <- sum(gc()[, 2]) - mem_before
        update_progress(script_name, "FAILED", runtime_mins, mem_used,
                       substr(error_msg, 1, 500))

        # For critical scripts (01-08), stop execution
        script_num <- as.numeric(substr(script_name, 1, 2))
        if (!is.na(script_num) && script_num <= 8) {
            log_message("\nCRITICAL ERROR: Data processing script failed. Stopping execution.\n")
            log_message("Please fix the error and re-run the master script.\n")
            stop(sprintf("Critical failure in %s", script_name))
        }

        FALSE
    })

    # Calculate runtime and memory
    script_end <- Sys.time()
    runtime_mins <- as.numeric(difftime(script_end, script_start, units = "mins"))
    gc()
    mem_after <- sum(gc()[, 2])
    mem_used <- mem_after - mem_before

    if (script_success) {
        log_message(sprintf("\n✓ SUCCESS: %s (%.1f min, %.1f MB)\n",
                           script_name, runtime_mins, mem_used))
        update_progress(script_name, "SUCCESS", runtime_mins, mem_used, "")
    } else {
        log_message(sprintf("\n✗ FAILED: %s - continuing with next script\n", script_name))
    }

    # Clean up memory
    gc()
}

# ===========================================================================
# 4. FINAL SUMMARY
# ===========================================================================

log_message("\n===========================================================================\n")
log_message("EXECUTION COMPLETE\n")
log_message("===========================================================================\n\n")

# Calculate total runtime
master_end <- Sys.time()
total_runtime_hours <- as.numeric(difftime(master_end, master_start_time, units = "hours"))

# Read final progress
final_progress <- read.csv(progress_file, stringsAsFactors = FALSE)

# Summary statistics
n_success <- sum(final_progress$status == "SUCCESS")
n_failed <- sum(final_progress$status == "FAILED")
n_total <- length(all_scripts)

log_message(sprintf("Total runtime: %.2f hours\n", total_runtime_hours))
log_message(sprintf("Scripts successful: %d/%d (%.1f%%)\n",
                   n_success, n_total, 100 * n_success / n_total))
log_message(sprintf("Scripts failed: %d/%d\n", n_failed, n_total))

if (n_failed > 0) {
    log_message("\nFailed scripts:\n")
    failed <- final_progress[final_progress$status == "FAILED", ]
    for (i in 1:nrow(failed)) {
        log_message(sprintf("  - %s: %s\n",
                           failed$script[i],
                           substr(failed$error_msg[i], 1, 60)))
    }
}

log_message(sprintf("\nProgress saved to: %s\n", progress_file))
log_message(sprintf("Log saved to: %s\n", master_log))

if (n_success == n_total) {
    log_message("\n🎉 CONGRATULATIONS! All scripts completed successfully!\n")
    log_message("The replication is complete.\n")
} else if (n_failed > 0) {
    log_message(sprintf("\n⚠ WARNING: %d scripts failed. Review the progress file for details.\n",
                       n_failed))
    log_message("You can re-run this master script to retry the failed scripts.\n")
}

log_message("\n===========================================================================\n")
log_message("END OF EXECUTION\n")
log_message("===========================================================================\n")

cat("\n✓ Master script execution complete.\n")
cat(sprintf("Check logs at: %s\n", log_dir))