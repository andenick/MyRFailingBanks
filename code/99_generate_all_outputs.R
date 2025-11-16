# ===========================================================================
# Generate All Outputs for Presentation
# ===========================================================================
# This script runs all analysis scripts and compiles outputs into
# presentation-ready PDFs and documentation
# ===========================================================================

library(here)
library(dplyr)
library(knitr)
library(rmarkdown)

# Source setup
source(here::here("code", "00_setup.R"))

cat("\n")
cat(strrep("=", 80), "\n")
cat("GENERATING ALL OUTPUTS FOR PRESENTATION\n")
cat(strrep("=", 80), "\n\n")

# --------------------------------------------------------------------------
# PART 1: Run all analysis scripts to generate figures and tables
# --------------------------------------------------------------------------

cat("PART 1: Running Analysis Scripts\n")
cat(strrep("-", 80), "\n\n")

analysis_scripts <- c(
  "22_descriptives_table.R",
  "32_prob_of_failure_cross_section.R",
  "33_coefplots_historical.R",
  "34_coefplots_modern_era.R",
  "35_conditional_prob_failure.R",
  "51_auc.R",
  "52_auc_glm.R",
  "53_auc_by_size.R",
  "54_auc_tpr_fpr.R",
  "55_pr_auc.R"
)

results <- list()

for (script in analysis_scripts) {
  cat(sprintf("Running %s...\n", script))

  result <- tryCatch({
    source(file.path("code", script), echo = FALSE)
    list(status = "SUCCESS", error = NULL)
  }, error = function(e) {
    list(status = "FAILED", error = conditionMessage(e))
  })

  results[[script]] <- result

  if (result$status == "SUCCESS") {
    cat(sprintf("  ✓ %s completed\n\n", script))
  } else {
    cat(sprintf("  ✗ %s FAILED: %s\n\n", script, result$error))
  }
}

# --------------------------------------------------------------------------
# PART 2: Generate summary statistics table
# --------------------------------------------------------------------------

cat("\nPART 2: Generating Summary Statistics\n")
cat(strrep("-", 80), "\n\n")

combined_data <- readRDS(file.path(dataclean_dir, "combined-data.rds"))
temp_reg_data <- readRDS(file.path(dataclean_dir, "temp_reg_data.rds"))

# Calculate comprehensive summary stats
summary_stats <- combined_data %>%
  summarize(
    total_obs = n(),
    unique_banks = n_distinct(bank_id),
    years_covered = n_distinct(year),
    min_year = min(year, na.rm = TRUE),
    max_year = max(year, na.rm = TRUE),
    total_failures = sum(failed_bank, na.rm = TRUE),
    failure_rate = mean(failed_bank, na.rm = TRUE) * 100
  )

cat("Dataset Summary:\n")
cat(sprintf("  Total observations: %s\n", format(summary_stats$total_obs, big.mark = ",")))
cat(sprintf("  Unique banks: %s\n", format(summary_stats$unique_banks, big.mark = ",")))
cat(sprintf("  Years covered: %d (%d-%d)\n",
            summary_stats$years_covered,
            summary_stats$min_year,
            summary_stats$max_year))
cat(sprintf("  Total failures: %s\n", format(summary_stats$total_failures, big.mark = ",")))
cat(sprintf("  Overall failure rate: %.2f%%\n\n", summary_stats$failure_rate))

# Banks by era
banks_by_era <- combined_data %>%
  mutate(
    era = case_when(
      year < 1900 ~ "Early National (1863-1899)",
      year >= 1900 & year < 1920 ~ "Free Banking (1900-1919)",
      year >= 1920 & year < 1934 ~ "Great Depression (1920-1933)",
      year >= 1934 & year < 1980 ~ "Early FDIC (1934-1979)",
      year >= 1980 & year < 1993 ~ "S&L Crisis (1980-1992)",
      year >= 1993 & year < 2008 ~ "Modern Stable (1993-2007)",
      year >= 2008 & year < 2013 ~ "Financial Crisis (2008-2012)",
      year >= 2013 ~ "Post-Crisis (2013-2023)"
    )
  ) %>%
  group_by(era) %>%
  summarize(
    n_obs = n(),
    n_banks = n_distinct(bank_id),
    n_failures = sum(failed_bank, na.rm = TRUE),
    failure_rate = mean(failed_bank, na.rm = TRUE) * 100,
    .groups = "drop"
  )

cat("Banks and Failures by Era:\n")
print(banks_by_era)
cat("\n")

# Save summary stats
saveRDS(summary_stats, file.path(output_dir, "Tables", "summary_statistics.rds"))
saveRDS(banks_by_era, file.path(output_dir, "Tables", "banks_by_era.rds"))

# --------------------------------------------------------------------------
# PART 3: Generate unique banks by year
# --------------------------------------------------------------------------

cat("\nPART 3: Analyzing Banks by Year\n")
cat(strrep("-", 80), "\n\n")

banks_by_year <- combined_data %>%
  group_by(year) %>%
  summarize(
    n_banks = n_distinct(bank_id),
    n_failures = sum(failed_bank, na.rm = TRUE),
    failure_rate = mean(failed_bank, na.rm = TRUE) * 100,
    .groups = "drop"
  )

cat(sprintf("Calculated banks by year for %d years\n", nrow(banks_by_year)))
cat(sprintf("  Peak year: %d with %s banks\n",
            banks_by_year$year[which.max(banks_by_year$n_banks)],
            format(max(banks_by_year$n_banks), big.mark = ",")))
cat(sprintf("  Recent (2023): %s banks\n\n",
            format(banks_by_year$n_banks[banks_by_year$year == max(banks_by_year$year)], big.mark = ",")))

saveRDS(banks_by_year, file.path(output_dir, "Tables", "banks_by_year.rds"))

# --------------------------------------------------------------------------
# PART 4: Generate data dictionary
# --------------------------------------------------------------------------

cat("\nPART 4: Creating Data Dictionary\n")
cat(strrep("-", 80), "\n\n")

# Get column information
col_info <- data.frame(
  column_name = names(combined_data),
  type = sapply(combined_data, function(x) class(x)[1]),
  n_missing = sapply(combined_data, function(x) sum(is.na(x))),
  pct_missing = sapply(combined_data, function(x) mean(is.na(x)) * 100),
  stringsAsFactors = FALSE
)

# Add descriptions (manually categorize)
col_info <- col_info %>%
  mutate(
    category = case_when(
      column_name %in% c("bank_id", "id_fdic_cert", "year", "quarter", "call_date", "state") ~ "Identifiers",
      grepl("^assets|^deposits|^loans|^equity|^cash", column_name) ~ "Balance Sheet",
      grepl("ratio$|^roe$|^roa$", column_name) ~ "Financial Ratios",
      grepl("failure|failed", column_name) ~ "Failure Variables",
      grepl("growth", column_name) ~ "Growth Variables",
      grepl("deposit_|noncore_|funding", column_name) ~ "Funding Structure",
      grepl("npl|oreo|provision|charge", column_name) ~ "Credit Quality",
      grepl("income|profit|margin", column_name) ~ "Profitability",
      grepl("size|age|novo", column_name) ~ "Bank Characteristics",
      grepl("gdp|cpi|crisis|rate", column_name) ~ "Macroeconomic",
      grepl("state|region|msa", column_name) ~ "Geographic",
      TRUE ~ "Other"
    )
  ) %>%
  arrange(category, column_name)

cat(sprintf("Created data dictionary for %d variables\n", nrow(col_info)))
cat("\nVariables by category:\n")
print(table(col_info$category))
cat("\n")

saveRDS(col_info, file.path(output_dir, "Tables", "data_dictionary.rds"))
write.csv(col_info, file.path(output_dir, "Tables", "data_dictionary.csv"), row.names = FALSE)

# --------------------------------------------------------------------------
# PART 5: Compile execution summary
# --------------------------------------------------------------------------

cat("\nPART 5: Execution Summary\n")
cat(strrep("-", 80), "\n\n")

success_count <- sum(sapply(results, function(x) x$status == "SUCCESS"))
total_count <- length(results)

cat(sprintf("Scripts executed: %d/%d successful (%.1f%%)\n",
            success_count, total_count, 100 * success_count / total_count))

if (success_count < total_count) {
  cat("\nFailed scripts:\n")
  for (script in names(results)) {
    if (results[[script]]$status == "FAILED") {
      cat(sprintf("  - %s: %s\n", script, results[[script]]$error))
    }
  }
}

cat("\n")
cat(strrep("=", 80), "\n")
cat("OUTPUT GENERATION COMPLETE\n")
cat(strrep("=", 80), "\n\n")

cat("Generated files:\n")
cat("  - All figures in output/Figures/\n")
cat("  - All tables in output/Tables/\n")
cat("  - Summary statistics: output/Tables/summary_statistics.rds\n")
cat("  - Banks by year: output/Tables/banks_by_year.rds\n")
cat("  - Data dictionary: output/Tables/data_dictionary.csv\n")
cat("\nNext: Review DATA_DOCUMENTATION.md for comprehensive analysis\n")
