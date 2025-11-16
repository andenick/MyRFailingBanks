# SETUP SCRIPT - Failing Banks R Replication Package (Stata-Style)
# ===========================================================================
# Replicates: common.do from QJE Stata replication kit
# ===========================================================================

# This script is sourced by 00_master.R and sets up the environment.
# It relies on the 'here' package to define paths relative to the project root.

# Load packages
suppressPackageStartupMessages({
    library(tidyverse)
    library(haven)
    library(fixest)
    library(lubridate)
    library(scales)
    library(readxl)
    library(here)
})

# Define paths using here::here() - matches Stata common.do structure
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

# Display setup information
cat(
    strrep("=", 75), "\n",
    "Failing Banks R Replication - Setup Complete\n",
    strrep("=", 75), "\n",
    sprintf("Project Root: %s\n", base_dir),
    sprintf("Sources:      %s\n", sources_dir),
    sprintf("Data Clean:   %s\n", dataclean_dir),
    sprintf("Output:       %s\n", output_dir),
    sprintf("Temp Files:   %s\n", tempfiles_dir),
    strrep("=", 75), "\n"
)

# Index expansion option
run_index_expansion <- TRUE  # Set to FALSE to skip index expansion
# Helper functions
print_section <- function(text) {
    cat("\n", strrep("=", 75), "\n", text, "\n", strrep("=", 75), "\n\n", sep = "")
}

# Clean data for Stata export
# Converts haven_labelled variables and ensures compatibility with .dta format
clean_for_stata <- function(df) {
    df %>%
        mutate(across(where(haven::is.labelled), haven::as_factor)) %>%
        mutate(across(where(is.factor), ~as.numeric(as.factor(.))))
}
