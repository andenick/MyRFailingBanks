# ===========================================================================
# SETUP SCRIPT - Failing Banks R Replication
# ===========================================================================
# R translation of Stata common.do from QJE replication kit
# Version 11.1 Definitive - Stata-Faithful Replication
# ===========================================================================

# Load required packages
suppressPackageStartupMessages({
    library(tidyverse)
    library(haven)
    library(fixest)
    library(lubridate)
    library(scales)
    library(readxl)
    library(here)
    library(pROC)          # For AUC analysis
    library(sandwich)      # For robust standard errors
    library(lmtest)        # For coefficient tests
})

# ===========================================================================
# DEFINE PATHS (Matching Stata common.do)
# ===========================================================================
# Stata equivalent:
#   global sources "$root/sources"
#   global data    "$root/dataclean"
#   global temp    "$root/tempfiles"
#   global figures "$output/figures"
#   global tables  "$output/tables"

sources_dir <- here::here("sources")
dataclean_dir <- here::here("dataclean")
output_dir <- here::here("output")
tempfiles_dir <- here::here("tempfiles")

# Compatibility aliases
base_dir <- here::here()
data_dir <- dataclean_dir
temp_dir <- tempfiles_dir

# Output subdirectories
figures_dir <- file.path(output_dir, "figures")
tables_dir <- file.path(output_dir, "tables")

# Create directories if they don't exist
dir.create(sources_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(dataclean_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tempfiles_dir, recursive = TRUE, showWarnings = FALSE)

# PATHS list for convenient access
PATHS <- list(
    root = base_dir,
    sources = sources_dir,
    dataclean = dataclean_dir,
    data = dataclean_dir,
    output = output_dir,
    figures = figures_dir,
    tables = tables_dir,
    tempfiles = tempfiles_dir,
    temp = tempfiles_dir
)

# ===========================================================================
# HELPER FUNCTIONS
# ===========================================================================

# Print formatted section headers
print_section <- function(text) {
    cat("\n", strrep("=", 75), "\n", text, "\n", strrep("=", 75), "\n\n", sep = "")
}

print_header <- function(text) {
    cat(sprintf("\n%s\n", text))
}

print_complete <- function(script_name) {
    cat(sprintf("\n%s completed successfully\n", script_name))
}

# Safe max function - handles all-NA case (critical v6.0 fix)
# R's max() returns -Inf for all-NA inputs, Stata returns missing
# This wrapper ensures consistent behavior
safe_max <- function(x, na.rm = TRUE) {
    if (all(is.na(x))) {
        return(NA_real_)
    } else {
        return(max(x, na.rm = na.rm))
    }
}

# Clean data for Stata export
# Converts haven_labelled variables and ensures compatibility with .dta format
clean_for_stata <- function(df) {
    df %>%
        mutate(across(where(haven::is.labelled), haven::as_factor)) %>%
        mutate(across(where(is.factor), ~as.numeric(as.factor(.))))
}

# ===========================================================================
# DISPLAY SETUP INFORMATION
# ===========================================================================

cat(
    strrep("=", 75), "\n",
    "Failing Banks R Replication v9.0 - Setup Complete\n",
    "R translation of Stata QJE Replication Kit\n",
    strrep("=", 75), "\n",
    sprintf("Project Root: %s\n", base_dir),
    sprintf("Sources:      %s\n", sources_dir),
    sprintf("Data Clean:   %s\n", dataclean_dir),
    sprintf("Output:       %s\n", output_dir),
    sprintf("Temp Files:   %s\n", tempfiles_dir),
    strrep("=", 75), "\n"
)

# Configuration options
run_index_expansion <- TRUE  # Set to FALSE to skip index expansion

message("Setup complete. Ready to execute analysis scripts.")
