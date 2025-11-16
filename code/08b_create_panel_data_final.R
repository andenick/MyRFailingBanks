# ===========================================================================
# Script 08b: Create panel_data_final.rds and data_for_coefplots.rds
# ===========================================================================
# These files are required by Script 31 (coefplots_combined.R)
#
# panel_data_final.rds: Full combined dataset (alias of combined-data.rds)
# data_for_coefplots.rds: Summary statistics for plotting
# ===========================================================================

library(dplyr)
library(here)

# Source setup
source(here::here("code", "00_setup.R"))

cat("\n=== Creating panel_data_final and data_for_coefplots ===\n\n")

# --------------------------------------------------------------------------
# 1. Create panel_data_final.rds (alias of combined-data.rds)
# --------------------------------------------------------------------------

cat("[1/2] Creating panel_data_final.rds...\n")

# Load combined data
combined_data <- readRDS(file.path(dataclean_dir, "combined-data.rds"))
cat(sprintf("  Loaded: %s observations\n", format(nrow(combined_data), big.mark=",")))

# Save as panel_data_final (it's the same file, just different name for Script 31)
saveRDS(combined_data, file.path(dataclean_dir, "panel_data_final.rds"))
cat(sprintf("  ✓ Saved: dataclean/panel_data_final.rds\n"))
cat(sprintf("    %d rows x %d columns\n\n", nrow(combined_data), ncol(combined_data)))

# --------------------------------------------------------------------------
# 2. Create data_for_coefplots.rds (summary statistics by year)
# --------------------------------------------------------------------------

cat("[2/2] Creating data_for_coefplots.rds...\n")

# Determine which failure variable to use
failure_vars <- c("failed_bank", "fails_in_t", "failure")
available_failure_vars <- failure_vars[failure_vars %in% names(combined_data)]

if (length(available_failure_vars) == 0) {
  stop("No failure variables found in combined_data")
}

failure_var <- available_failure_vars[1]
cat(sprintf("  Using failure variable: %s\n", failure_var))

# Create summary statistics by year for coefplot script
data_for_coefplots <- combined_data %>%
  filter(!is.na(.data[[failure_var]])) %>%
  group_by(year) %>%
  summarize(
    failure_rate = as.numeric(mean(.data[[failure_var]], na.rm = TRUE) * 100),
    n_failed = sum(.data[[failure_var]], na.rm = TRUE),
    n_banks = as.integer(n()),
    .groups = "drop"
  ) %>%
  ungroup() %>%
  filter(year >= 1863, year <= 2023)  # Full historical range

cat(sprintf("  Created summary for %d years (%d-%d)\n",
            nrow(data_for_coefplots),
            min(data_for_coefplots$year),
            max(data_for_coefplots$year)))

# Save
saveRDS(data_for_coefplots, file.path(dataclean_dir, "data_for_coefplots.rds"))
cat(sprintf("  ✓ Saved: dataclean/data_for_coefplots.rds\n"))
cat(sprintf("    %d years of summary statistics\n\n", nrow(data_for_coefplots)))

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------

cat("=== Summary ===\n")
cat("✓ panel_data_final.rds created\n")
cat("✓ data_for_coefplots.rds created\n")
cat("\nScript 31 (coefplots_combined.R) can now run successfully!\n")
cat("\n08b_create_panel_data_final.R completed successfully\n")
