# ===========================================================================
source(here::here("code", "00_helper_functions.R"))
# Failure Rates Appendix Table - FIXED VERSION
# ===========================================================================

library(here)
library(dplyr)
source(here::here("code", "00_setup.R"))

print_section("Creating Failure Rates Appendix Table")

# Check if panel_data_final.rds exists, otherwise use combined-data.dta
panel_file <- file.path(dataclean_dir, "panel_data_final.rds")
if (!file.exists(panel_file)) {
  cat("panel_data_final.rds not found, loading from dataclean/combined-data.rds...\n")
  panel_data <- readRDS(here::here("dataclean", "combined-data.rds"))
} else {
  cat("Loading panel data...\n")
  panel_data <- readRDS(panel_file)
}

# Calculate failure rates by year
cat("Calculating failure rates by year...\n")
failure_rates <- panel_data %>%
  group_by(year) %>%
  summarise(
    n_banks = n_distinct(bank_id),
    n_observations = n(),
    n_failures = sum(failed_bank, na.rm = TRUE),
    failure_rate = (n_failures / n_observations) * 100,
    .groups = "drop"
  ) %>%
  arrange(year)

# Create LaTeX table
cat("Creating LaTeX table...\n")
failure_rates_table <- paste0(
  "\\begin{table}[htbp]\n",
  "\\centering\n",
  "\\caption{Annual Bank Failure Rates}\n",
  "\\begin{tabular}{rrrrr}\n",
  "\\hline\\hline\n",
  "Year & Banks & Observations & Failures & Rate (\\%) \\\\\\\\\n",
  "\\hline\n"
)

# Add data rows (sample every 5 years to keep table manageable)
sample_years <- failure_rates %>%
  filter(year %% 5 == 0 | year == min(year) | year == max(year))

for (i in 1:nrow(sample_years)) {
  row <- sample_years[i, ]
  failure_rates_table <- paste0(
    failure_rates_table,
    sprintf(
      "%d & %d & %d & %d & %.2f \\\\\\\\\n",
      row$year,
      row$n_banks,
      row$n_observations,
      row$n_failures,
      row$failure_rate
    )
  )
}

failure_rates_table <- paste0(
  failure_rates_table,
  "\\hline\\hline\n",
  "\\end{tabular}\n",
  "\\end{table}\n"
)

# Save table
output_file <- file.path(tables_dir, "appendix_failure_rates.tex")
cat(failure_rates_table, file = output_file)
cat(sprintf("✓ Table saved to: %s\n", output_file))

# Print summary
cat("\nFailure rates summary:\n")
cat(sprintf("  Years covered: %d to %d\n", min(failure_rates$year), max(failure_rates$year)))
cat(sprintf("  Total years: %d\n", nrow(failure_rates)))
cat(sprintf("  Mean failure rate: %.2f%%\n", mean(failure_rates$failure_rate, na.rm = TRUE)))
cat(sprintf("  Max failure rate: %.2f%% (year %d)\n",
            max(failure_rates$failure_rate, na.rm = TRUE),
            failure_rates$year[which.max(failure_rates$failure_rate)]))

print_complete("99_failures_rates_appendix_FIXED.R")
