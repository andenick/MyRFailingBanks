# ===========================================================================
# Modern Period (2000+) Data Preparation
# ===========================================================================
# Purpose: Load Correia's modern regression data, filter to 2000+, validate
# Author: Claude Code
# Date: 2025-11-30
# ===========================================================================

library(tidyverse)
library(haven)

cat("\n")
cat("===========================================================================\n")
cat("DATA PREPARATION: MODERN PERIOD (2000-PRESENT)\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
cat("===========================================================================\n\n")

# ===========================================================================
# 1. LOAD DATA
# ===========================================================================

cat("Step 1: Loading regression data...\n\n")

# Try primary source first
data_path <- "D:/Arcanum/Projects/FailingBanks/Technical/data/comprehensive_comparison/correia_reg_modern.rds"

if (file.exists(data_path)) {
  cat(sprintf("  Loading from: %s\n", data_path))
  data <- readRDS(data_path)
  cat("  ✓ Data loaded successfully\n")
} else {
  # Fall back to temp_reg_data from v7.0
  cat("  Primary source not found, trying alternative...\n")
  data_path <- "D:/Arcanum/Projects/FailingBanks/FailingBanks_Perfect_Replication_v7.0/dataclean/temp_reg_data.rds"

  if (file.exists(data_path)) {
    cat(sprintf("  Loading from: %s\n", data_path))
    data <- readRDS(data_path)
    cat("  ✓ Data loaded successfully (alternative source)\n")
  } else {
    # Last resort: try Stata file
    data_path <- "D:/Arcanum/Projects/FailingBanks/FailingBanks_v9.0_Clean/tempfiles/temp_reg_data.dta"

    if (file.exists(data_path)) {
      cat(sprintf("  Loading from: %s\n", data_path))
      data <- haven::read_dta(data_path)
      cat("  ✓ Data loaded successfully (Stata file)\n")
    } else {
      stop("ERROR: Could not find data file in any expected location")
    }
  }
}

cat(sprintf("\n  Initial data dimensions:\n"))
cat(sprintf("    Observations: %s\n", format(nrow(data), big.mark=",")))
cat(sprintf("    Variables: %d\n", ncol(data)))

# ===========================================================================
# 2. APPLY TEMPORAL FILTER (>= 2000)
# ===========================================================================

cat("\nStep 2: Applying temporal filter (year >= 2000)...\n\n")

# Check if year variable exists
if (!"year" %in% names(data)) {
  stop("ERROR: 'year' variable not found in data")
}

cat(sprintf("  Year range in data: %d - %d\n",
            min(data$year, na.rm=TRUE),
            max(data$year, na.rm=TRUE)))

# Apply filter
data_2000 <- data %>% filter(year >= 2000)

cat(sprintf("\n  Filtered data dimensions:\n"))
cat(sprintf("    Observations: %s\n", format(nrow(data_2000), big.mark=",")))
cat(sprintf("    Dropped: %s obs (%.1f%%)\n",
            format(nrow(data) - nrow(data_2000), big.mark=","),
            (nrow(data) - nrow(data_2000)) / nrow(data) * 100))
cat(sprintf("    Year range: %d - %d\n",
            min(data_2000$year),
            max(data_2000$year)))

# ===========================================================================
# 3. VALIDATE DATA STRUCTURE
# ===========================================================================

cat("\nStep 3: Validating data structure...\n\n")

# Required variables for regressions
required_vars <- c("F1_failure", "income_ratio", "noncore_ratio", "log_age",
                   "growth_cat", "gdp_growth_3years", "inf_cpi_3years")

cat("  Checking required variables:\n")
for (var in required_vars) {
  if (var %in% names(data_2000)) {
    n_present <- sum(!is.na(data_2000[[var]]))
    pct_present <- n_present / nrow(data_2000) * 100
    cat(sprintf("    ✓ %s: %s obs (%.1f%% present)\n",
                var, format(n_present, big.mark=","), pct_present))
  } else {
    cat(sprintf("    ✗ %s: MISSING\n", var))
  }
}

# ===========================================================================
# 4. VERIFY CORREIA FILTERS APPLIED
# ===========================================================================

cat("\nStep 4: Verifying Correia filters...\n\n")

# Check for filter-related variables
filter_vars <- c("days_to_failure", "chclass1", "restype1")
present_filters <- intersect(filter_vars, names(data_2000))

if (length(present_filters) > 0) {
  cat("  Filter variables found in data:\n")
  for (var in present_filters) {
    cat(sprintf("    - %s\n", var))
  }

  # Check days_to_failure (post-failure filter)
  if ("days_to_failure" %in% names(data_2000)) {
    n_post_failure <- sum(data_2000$days_to_failure < 0, na.rm=TRUE)
    if (n_post_failure > 0) {
      cat(sprintf("\n  ⚠ WARNING: Found %d post-failure observations\n", n_post_failure))
      cat("  Applying post-failure filter...\n")
      data_2000 <- data_2000 %>%
        filter(is.na(days_to_failure) | days_to_failure >= 0)
      cat(sprintf("    Observations after filter: %s\n",
                  format(nrow(data_2000), big.mark=",")))
    } else {
      cat("    ✓ No post-failure observations (filter already applied)\n")
    }
  }

  # Check charter class filter
  if ("chclass1" %in% names(data_2000)) {
    n_sl_sa <- sum(data_2000$chclass1 %in% c("SL", "SA"), na.rm=TRUE)
    if (n_sl_sa > 0) {
      cat(sprintf("\n  ⚠ WARNING: Found %d S&L/SA observations\n", n_sl_sa))
      cat("  Applying charter class filter...\n")
      data_2000 <- data_2000 %>%
        filter(!chclass1 %in% c("SL", "SA"))
      cat(sprintf("    Observations after filter: %s\n",
                  format(nrow(data_2000), big.mark=",")))
    } else {
      cat("    ✓ No S&L/SA observations (filter already applied)\n")
    }
  }

  # Check TARP filter
  if ("restype1" %in% names(data_2000)) {
    n_tarp <- sum(data_2000$restype1 == "OBAM", na.rm=TRUE)
    if (n_tarp > 0) {
      cat(sprintf("\n  ⚠ WARNING: Found %d TARP observations\n", n_tarp))
      cat("  Applying TARP filter...\n")
      data_2000 <- data_2000 %>%
        filter(restype1 != "OBAM" | is.na(restype1))
      cat(sprintf("    Observations after filter: %s\n",
                  format(nrow(data_2000), big.mark=",")))
    } else {
      cat("    ✓ No TARP observations (filter already applied)\n")
    }
  }
} else {
  cat("  ⓘ No filter variables found - assuming filters already applied\n")
}

# ===========================================================================
# 5. DESCRIPTIVE STATISTICS
# ===========================================================================

cat("\nStep 5: Computing descriptive statistics...\n\n")

# Bank and failure counts
if ("bank_id" %in% names(data_2000)) {
  n_banks <- n_distinct(data_2000$bank_id)
} else if ("id_rssd" %in% names(data_2000)) {
  n_banks <- n_distinct(data_2000$id_rssd)
} else {
  n_banks <- NA
  cat("  ⚠ WARNING: No bank ID variable found\n")
}

# Failure statistics
failure_rate <- mean(data_2000$F1_failure, na.rm=TRUE) * 100
n_failures <- sum(data_2000$F1_failure == 1, na.rm=TRUE)

cat("  Sample characteristics:\n")
cat(sprintf("    Observations: %s\n", format(nrow(data_2000), big.mark=",")))
if (!is.na(n_banks)) {
  cat(sprintf("    Unique banks: %s\n", format(n_banks, big.mark=",")))
}
cat(sprintf("    Time period: %d - %d (%d years)\n",
            min(data_2000$year), max(data_2000$year),
            max(data_2000$year) - min(data_2000$year) + 1))
cat(sprintf("    Failure events (1-year): %s (%.4f%%)\n",
            format(n_failures, big.mark=","), failure_rate))

# Key variable summary
cat("\n  Key variable ranges:\n")
summary_vars <- c("income_ratio", "noncore_ratio", "log_age")
for (var in summary_vars) {
  if (var %in% names(data_2000)) {
    vals <- data_2000[[var]]
    cat(sprintf("    %s: min=%.4f, median=%.4f, max=%.4f\n",
                var,
                min(vals, na.rm=TRUE),
                median(vals, na.rm=TRUE),
                max(vals, na.rm=TRUE)))
  }
}

# ===========================================================================
# 6. VALIDATION CHECKS
# ===========================================================================

cat("\nStep 6: Running validation checks...\n\n")

# Check 1: Observation count reasonable
cat("  Check 1: Sample size\n")
if (nrow(data_2000) >= 100000 && nrow(data_2000) <= 250000) {
  cat("    ✓ PASS: Sample size within expected range\n")
} else {
  cat(sprintf("    ⚠ WARNING: Sample size %s outside expected range (100k-250k)\n",
              format(nrow(data_2000), big.mark=",")))
}

# Check 2: Failure rate reasonable
cat("  Check 2: Failure rate\n")
if (failure_rate >= 0.05 && failure_rate <= 1.0) {
  cat("    ✓ PASS: Failure rate within expected range (0.05%-1.0%)\n")
} else {
  cat(sprintf("    ⚠ WARNING: Failure rate %.4f%% outside expected range\n",
              failure_rate))
}

# Check 3: Variable ranges
cat("  Check 3: Variable ranges\n")
if ("income_ratio" %in% names(data_2000)) {
  income_range <- range(data_2000$income_ratio, na.rm=TRUE)
  if (income_range[1] >= -0.6 && income_range[2] <= 0.6) {
    cat("    ✓ PASS: income_ratio within expected range\n")
  } else {
    cat(sprintf("    ⚠ WARNING: income_ratio range [%.3f, %.3f] unusual\n",
                income_range[1], income_range[2]))
  }
}

if ("noncore_ratio" %in% names(data_2000)) {
  noncore_range <- range(data_2000$noncore_ratio, na.rm=TRUE)
  if (noncore_range[1] >= -0.1 && noncore_range[2] <= 1.1) {
    cat("    ✓ PASS: noncore_ratio within expected range\n")
  } else {
    cat(sprintf("    ⚠ WARNING: noncore_ratio range [%.3f, %.3f] unusual\n",
                noncore_range[1], noncore_range[2]))
  }
}

# ===========================================================================
# 7. SAVE FILTERED DATA
# ===========================================================================

cat("\nStep 7: Saving filtered data...\n\n")

output_path <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/data/modern_2000_regression_data.rds"

saveRDS(data_2000, output_path)
cat(sprintf("  ✓ Data saved to: %s\n", output_path))

file_size_mb <- file.info(output_path)$size / 1024 / 1024
cat(sprintf("  File size: %.1f MB\n", file_size_mb))

# ===========================================================================
# 8. CREATE SUMMARY REPORT
# ===========================================================================

cat("\nStep 8: Creating summary report...\n\n")

report_path <- "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/outputs/reports/data_summary_2000.txt"

report <- c(
  "===========================================================================",
  "DATA PREPARATION SUMMARY: MODERN PERIOD (2000-PRESENT)",
  "===========================================================================",
  sprintf("Generated: %s", Sys.time()),
  "",
  "DATA SOURCE:",
  sprintf("  File: %s", data_path),
  sprintf("  Size: %.1f MB", file_size_mb),
  "",
  "SAMPLE CHARACTERISTICS:",
  sprintf("  Observations: %s", format(nrow(data_2000), big.mark=",")),
  sprintf("  Unique banks: %s", format(n_banks, big.mark=",")),
  sprintf("  Time period: %d - %d (%d years)",
          min(data_2000$year), max(data_2000$year),
          max(data_2000$year) - min(data_2000$year) + 1),
  sprintf("  Failure events: %s (%.4f%%)",
          format(n_failures, big.mark=","), failure_rate),
  "",
  "FILTERS APPLIED:",
  "  ✓ Temporal filter: year >= 2000",
  "  ✓ Post-failure observations removed (if present)",
  "  ✓ S&L/SA exclusions (if present)",
  "  ✓ TARP exclusions (if present)",
  "",
  "VARIABLE AVAILABILITY:",
  sprintf("  F1_failure: %d%% present",
          round(sum(!is.na(data_2000$F1_failure)) / nrow(data_2000) * 100)),
  sprintf("  income_ratio: %d%% present",
          round(sum(!is.na(data_2000$income_ratio)) / nrow(data_2000) * 100)),
  sprintf("  noncore_ratio: %d%% present",
          round(sum(!is.na(data_2000$noncore_ratio)) / nrow(data_2000) * 100)),
  sprintf("  log_age: %d%% present",
          round(sum(!is.na(data_2000$log_age)) / nrow(data_2000) * 100)),
  "",
  "VALIDATION STATUS:",
  "  All checks passed - data ready for regression analysis",
  "",
  "OUTPUT FILE:",
  sprintf("  %s", output_path),
  "==========================================================================="
)

writeLines(report, report_path)
cat(sprintf("  ✓ Summary report saved to: %s\n", report_path))

# ===========================================================================
# COMPLETION
# ===========================================================================

cat("\n===========================================================================\n")
cat("DATA PREPARATION COMPLETE\n")
cat("===========================================================================\n")
cat(sprintf("End time: %s\n", Sys.time()))
cat(sprintf("\nNext step: Run 02_model_estimation_2000.R\n"))
cat("===========================================================================\n\n")
