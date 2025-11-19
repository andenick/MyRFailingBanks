# ==============================================================================
# Extract Stata Baseline from Log File
#
# Purpose: Parse FailingBanksLog_all.txt to extract comprehensive baseline
#          data for validation of R replication
#
# Input:  D:/Arcanum/Projects/FailingBanks/Inputs/statalog/FailingBanksLog_all.txt
# Output: tempfiles/stata_baseline_comprehensive.json
#         tempfiles/stata_baseline_comprehensive.rds
#
# Author: Claude Code v11.0
# Date:   November 18, 2025
# ==============================================================================

library(here)
library(tidyverse)
library(jsonlite)

# Read Stata log file
cat("Reading Stata log file...\n")
stata_log <- readLines(here("..", "Inputs", "statalog", "FailingBanksLog_all.txt"))
cat(sprintf("  Total lines: %s\n", format(length(stata_log), big.mark = ",")))

# Initialize baseline storage
baseline <- list()

# Define script list (matching our R scripts, excluding 00_setup.R)
scripts <- c(
  "01_import_GDP",
  "02_import_GFD_CPI",
  "03_import_GFD_Yields",
  "04_create-historical-dataset",
  "05_create-modern-dataset",
  "06_create-outflows-receivership-data",
  "07_combine-historical-modern-datasets-panel",
  "08_data_for_coefplots",
  "21_descriptives_failures_time_series",
  "22_descriptives_table",
  "31_coefplots_combined",
  "32_prob_of_failure_cross_section",
  "33_coefplots_historical",
  "34_coefplots_modern_era",
  "35_conditional_prob_failure",
  "51_auc",
  "52_auc_glm",
  "53_auc_by_size",
  "54_auc_tpr_fpr",
  "55_pr_auc",
  "61_deposits_assets_before_failure",
  "62_predicted_probability_of_failure",
  "71_banks_at_risk",
  "81_recovery_rates",
  "82_predicting_recovery_rates",
  "83_rho_v",
  "84_recovery_and_deposit_outflows",
  "85_causes_of_failure",
  "86_receivership_length",
  "87_depositor_recovery_rates_dynamics",
  "99_failures_rates_appendix"
)

# ==============================================================================
# Helper Functions
# ==============================================================================

# Find script start/end lines
find_script_bounds <- function(log_lines, script_name) {
  # Pattern: ". Do "$code/XX_script_name.do"" (note capital D and $code/)
  start_pattern <- sprintf("\\. Do \"\\$code/%s\\.do\"", script_name)
  start_line <- grep(start_pattern, log_lines, fixed = FALSE)[1]

  if (is.na(start_line)) {
    return(NULL)
  }

  # Find next script start or end of log
  next_starts <- grep("\\. do \"[0-9]{2}_", log_lines)
  next_start <- next_starts[next_starts > start_line][1]

  end_line <- if (is.na(next_start)) length(log_lines) else next_start - 1

  return(c(start_line, end_line))
}

# Extract observations count
extract_observations <- function(log_lines, start_line, end_line) {
  section <- log_lines[start_line:end_line]

  # Look for common patterns
  patterns <- c(
    "observations.*\\s+(\\d+)",           # "X observations"
    "(\\d+)\\s+observations",             # "X observations"
    "obs:\\s+(\\d+)",                     # "obs: X"
    "Number of obs\\s*=\\s*(\\d+)",       # "Number of obs = X"
    "\\(\\s*(\\d+)\\s+obs\\)",            # "(X obs)"
    "_N\\s*=\\s*(\\d+)"                   # "_N = X"
  )

  for (pattern in patterns) {
    matches <- str_match(section, regex(pattern, ignore_case = TRUE))
    obs_values <- as.numeric(matches[!is.na(matches[,2]), 2])
    if (length(obs_values) > 0) {
      # Return the most common value (mode)
      return(as.integer(names(sort(table(obs_values), decreasing = TRUE))[1]))
    }
  }

  return(NA)
}

# Extract AUC values (for scripts 51-55)
extract_auc_values <- function(log_lines, start_line, end_line) {
  section <- log_lines[start_line:end_line]

  # Pattern: ROC area or AUC value (0.XXXX format)
  auc_pattern <- "(?:ROC area|AUC)[^0-9]*(0\\.\\d{4,7})"
  matches <- str_match_all(section, regex(auc_pattern, ignore_case = TRUE))

  auc_values <- c()
  for (i in seq_along(matches)) {
    if (nrow(matches[[i]]) > 0) {
      for (j in 1:nrow(matches[[i]])) {
        auc_values <- c(auc_values, list(list(
          value = as.numeric(matches[[i]][j, 2]),
          line = start_line + i - 1
        )))
      }
    }
  }

  return(auc_values)
}

# Extract key statistics (means, SDs, etc.)
extract_statistics <- function(log_lines, start_line, end_line) {
  section <- log_lines[start_line:end_line]

  stats <- list()

  # Look for summary statistics tables
  # Pattern: variable name followed by numbers
  stat_lines <- grep("^\\s*\\w+\\s+\\d+", section)

  if (length(stat_lines) > 0) {
    # Extract first few for sample
    for (i in head(stat_lines, 10)) {
      line <- section[i]
      parts <- str_split(str_trim(line), "\\s+")[[1]]
      if (length(parts) >= 2) {
        var_name <- parts[1]
        value <- suppressWarnings(as.numeric(parts[2]))
        if (!is.na(value)) {
          stats[[var_name]] <- value
        }
      }
    }
  }

  return(stats)
}

# Determine tier classification
get_tier <- function(script_name) {
  tier1 <- c("04_create-historical-dataset", "05_create-modern-dataset",
             "06_create-outflows-receivership-data",
             "07_combine-historical-modern-datasets-panel",
             "35_conditional_prob_failure")
  tier2 <- c("51_auc", "52_auc_glm", "53_auc_by_size", "54_auc_tpr_fpr", "55_pr_auc")

  if (script_name %in% tier1) return(1)
  if (script_name %in% tier2) return(2)
  return(3)
}

# ==============================================================================
# Main Extraction Loop
# ==============================================================================

cat("\nExtracting baseline data for each script...\n")

for (script in scripts) {
  cat(sprintf("  Processing %s...", script))

  # Find script boundaries
  bounds <- find_script_bounds(stata_log, script)

  if (is.null(bounds)) {
    cat(" NOT FOUND in log\n")
    baseline[[script]] <- list(
      script_name = paste0(script, ".do"),
      found = FALSE,
      tier = get_tier(script)
    )
    next
  }

  start_line <- bounds[1]
  end_line <- bounds[2]
  line_count <- end_line - start_line + 1

  # Extract data
  observations <- extract_observations(stata_log, start_line, end_line)
  auc_values <- extract_auc_values(stata_log, start_line, end_line)
  statistics <- extract_statistics(stata_log, start_line, end_line)

  # Store baseline
  baseline[[script]] <- list(
    script_name = paste0(script, ".do"),
    script_number = as.integer(str_extract(script, "^\\d+")),
    found = TRUE,
    tier = get_tier(script),
    log_start_line = start_line,
    log_end_line = end_line,
    log_line_count = line_count,
    observations = if (is.na(observations)) NULL else observations,
    auc_values = if (length(auc_values) == 0) NULL else auc_values,
    key_statistics = if (length(statistics) == 0) NULL else statistics
  )

  cat(sprintf(" lines %d-%d", start_line, end_line))
  if (!is.na(observations)) cat(sprintf(", obs=%s", format(observations, big.mark = ",")))
  if (length(auc_values) > 0) cat(sprintf(", AUC=%d values", length(auc_values)))
  cat("\n")
}

# ==============================================================================
# Add Known AUC Values from JSON (for validation)
# ==============================================================================

cat("\nAdding known AUC values from stata_results_extracted.json...\n")

stata_json <- jsonlite::read_json(here("..", "stata_results_extracted.json"))

if (!is.null(stata_json$auc_values)) {
  for (script_name in names(stata_json$auc_values)) {
    script_key <- str_replace(script_name, "\\.do$", "")
    if (script_key %in% names(baseline)) {
      baseline[[script_key]]$auc_values_verified <- stata_json$auc_values[[script_name]]
    }
  }
}

# Add known sample sizes from JSON
if (!is.null(stata_json$sample_sizes)) {
  for (key in names(stata_json$sample_sizes)) {
    script_key <- str_replace(key, "_observations$", "")
    script_key <- str_replace(script_key, "\\.do$", "")
    if (script_key %in% names(baseline)) {
      baseline[[script_key]]$observations_verified <- stata_json$sample_sizes[[key]]
    }
  }
}

# ==============================================================================
# Create Summary Statistics
# ==============================================================================

cat("\nGenerating summary statistics...\n")

summary_stats <- tibble(
  script = names(baseline),
  found = map_lgl(baseline, ~.x$found),
  tier = map_int(baseline, ~.x$tier),
  observations = map_int(baseline, ~ifelse(is.null(.x$observations), NA, .x$observations)),
  auc_count = map_int(baseline, ~ifelse(is.null(.x$auc_values), 0, length(.x$auc_values)))
) %>%
  arrange(as.integer(str_extract(script, "^\\d+")))

cat("\nSummary by Tier:\n")
print(summary_stats %>% count(tier, name = "scripts"))

cat("\nScripts with observations extracted:\n")
cat(sprintf("  Found: %d/%d (%.1f%%)\n",
            sum(!is.na(summary_stats$observations)),
            nrow(summary_stats),
            100 * sum(!is.na(summary_stats$observations)) / nrow(summary_stats)))

cat("\nScripts with AUC values extracted:\n")
cat(sprintf("  Found: %d scripts with %d total AUC values\n",
            sum(summary_stats$auc_count > 0),
            sum(summary_stats$auc_count)))

# ==============================================================================
# Save Outputs
# ==============================================================================

cat("\nSaving baseline data...\n")

# Save as JSON (human-readable)
json_path <- here("tempfiles", "stata_baseline_comprehensive.json")
write_json(baseline, json_path, pretty = TRUE, auto_unbox = TRUE)
cat(sprintf("  JSON saved: %s\n", json_path))

# Save as RDS (R-native, faster loading)
rds_path <- here("tempfiles", "stata_baseline_comprehensive.rds")
saveRDS(baseline, rds_path)
cat(sprintf("  RDS saved: %s\n", rds_path))

# Save summary CSV
csv_path <- here("tempfiles", "stata_baseline_summary.csv")
write_csv(summary_stats, csv_path)
cat(sprintf("  Summary CSV saved: %s\n", csv_path))

# ==============================================================================
# Display Sample Baseline Entry
# ==============================================================================

cat("\n" %+% strrep("=", 80) %+% "\n")
cat("Sample Baseline Entry (Script 51 - AUC Analysis):\n")
cat(strrep("=", 80) %+% "\n\n")

if ("51_auc" %in% names(baseline)) {
  cat(toJSON(baseline$`51_auc`, pretty = TRUE, auto_unbox = TRUE))
} else {
  cat("Script 51 not found in baseline\n")
}

cat("\n\n" %+% strrep("=", 80) %+% "\n")
cat("BASELINE EXTRACTION COMPLETE\n")
cat(strrep("=", 80) %+% "\n")
cat(sprintf("\nTotal scripts processed: %d\n", length(baseline)))
cat(sprintf("Scripts found in log: %d\n", sum(map_lgl(baseline, ~.x$found))))
cat(sprintf("Scripts with observations: %d\n", sum(!is.na(summary_stats$observations))))
cat(sprintf("Total AUC values extracted: %d\n", sum(summary_stats$auc_count)))
cat("\nReady for Phase 1 validation!\n\n")
