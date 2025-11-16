# ==============================================================================
# Rho-V Analysis (Solvency Ratios) - TEST FIX VERSION
# ==============================================================================
# Testing fix for missing value handling to match Stata behavior
# ==============================================================================

library(tidyverse)
library(haven)
library(ggplot2)
library(here)

# Source setup
source(here::here("code", "00_setup.R"))

cat("================================================================================\n")
cat("RHO-V ANALYSIS - SOLVENCY RATIOS (TEST FIX)\n")
cat("================================================================================\n")

# Load data
cat("\n1. Loading historical deposit outflow data...\n")
df <- read_dta(here::here("dataclean", "deposits_before_failure_historical.dta"))

cat(sprintf("   Loaded %s observations\n", format(nrow(df), big.mark = ",")))

# Calculate solvency ratios (matching Stata lines 10-21)
df <- df %>%
  mutate(
    # Total collected from various sources
    total_collected = rowSums(select(., collected_from_assets, offsets_allowed_and_settled), na.rm = TRUE),
    total_collected_alt = rowSums(select(., collected_from_assets, offsets_allowed_and_settled, collected_from_shareholders), na.rm = TRUE),

    # Total claims
    total_claims_incl_offsets = rowSums(select(., amt_claims_proved, loans_paid_other_imp, offsets_allowed_and_settled), na.rm = TRUE),
    total_claims_incl_offsets_alt = rowSums(select(., deposits_at_suspension, loans_paid_other_imp, offsets_allowed_and_settled), na.rm = TRUE),

    # Solvency ratios
    solvency_ratio = total_collected / total_claims_incl_offsets,
    solvency_ratio_alt1 = total_collected_alt / total_claims_incl_offsets,
    solvency_ratio_alt2 = total_collected / total_claims_incl_offsets_alt
  ) %>%
  # Remove infinite values
  mutate(
    solvency_ratio = ifelse(is.finite(solvency_ratio), solvency_ratio, NA),
    solvency_ratio_alt1 = ifelse(is.finite(solvency_ratio_alt1), solvency_ratio_alt1, NA),
    solvency_ratio_alt2 = ifelse(is.finite(solvency_ratio_alt2), solvency_ratio_alt2, NA)
  )

cat(sprintf("   Solvency ratios calculated: %d non-NA values\n", sum(!is.na(df$solvency_ratio))))

# Calculate share of deeply insolvent banks (matching Stata lines 48-84)
cat("\n2. Calculating insolvency shares for different rho and v values...\n")
cat("   ⚠️  TEST FIX: NOT filtering NA values before threshold comparison\n")

rhos <- c(0, 50, 100, 200)
vs <- c(0, 25, 50, 75, 100, 150, 200)

results_list <- list()
counter <- 1

for (rho in rhos) {
  rho_label <- sprintf("%d%%", rho/10)

  for (v in vs) {
    threshold <- (1000 - rho) / (1000 + v)

    # FIX: Match Stata behavior - don't filter NAs before comparison
    # Stata keeps all observations and handles missing values naturally
    df_temp <- df %>%
      mutate(deeply_insolvent = solvency_ratio < threshold)

    share <- mean(df_temp$deeply_insolvent, na.rm = TRUE)

    results_list[[counter]] <- data.frame(
      rho_num = rho,
      rho_label = rho_label,
      v = v,
      share_deeply_insolvent = share
    )
    counter <- counter + 1
  }
}

results_df <- bind_rows(results_list)

cat(sprintf("   Calculated insolvency shares: %d scenarios\n", nrow(results_df)))

# Reshape to wide format
results_wide <- results_df %>%
  pivot_wider(
    id_cols = c(rho_num, rho_label),
    names_from = v,
    values_from = share_deeply_insolvent,
    names_prefix = "share_deeply_insolvent"
  ) %>%
  arrange(rho_num)

# Format for LaTeX table
results_formatted <- results_wide %>%
  mutate(across(starts_with("share"), ~sprintf("%.2f", .)))

# Display results
cat("\n3. Results Comparison:\n")
cat("================================================================================\n")
cat("Rho    | V=0   | V=25  | V=50  | V=75  | V=100 | V=150 | V=200\n")
cat("--------------------------------------------------------------------------------\n")
for (i in 1:nrow(results_formatted)) {
  cat(sprintf("%-6s | %-5s | %-5s | %-5s | %-5s | %-5s | %-5s | %-5s\n",
              results_formatted$rho_label[i],
              results_formatted$share_deeply_insolvent0[i],
              results_formatted$share_deeply_insolvent25[i],
              results_formatted$share_deeply_insolvent50[i],
              results_formatted$share_deeply_insolvent75[i],
              results_formatted$share_deeply_insolvent100[i],
              results_formatted$share_deeply_insolvent150[i],
              results_formatted$share_deeply_insolvent200[i]))
}
cat("================================================================================\n")

cat("\n4. Expected Stata Values (from log line 152,912):\n")
cat("================================================================================\n")
cat("Rho    | V=0   | V=25  | V=50  | V=75  | V=100 | V=150 | V=200\n")
cat("--------------------------------------------------------------------------------\n")
cat("0%     | 0.81  | 0.77  | 0.75  | 0.72  | 0.69  | 0.62  | 0.56\n")
cat("5%     | 0.74  | 0.71  | 0.68  | 0.65  | 0.62  | 0.55  | 0.49\n")
cat("10%    | 0.67  | 0.64  | 0.60  | 0.57  | 0.54  | 0.48  | 0.43\n")
cat("20%    | 0.50  | 0.48  | 0.45  | 0.42  | 0.40  | 0.36  | 0.31\n")
cat("================================================================================\n")

cat("\n5. Summary statistics:\n")
cat(sprintf("   Total observations: %d\n", nrow(df)))
cat(sprintf("   Valid solvency ratios: %d (%.1f%%)\n",
            sum(!is.na(df$solvency_ratio)),
            100*sum(!is.na(df$solvency_ratio))/nrow(df)))
cat(sprintf("   Mean solvency ratio: %.3f\n", mean(df$solvency_ratio, na.rm = TRUE)))
cat(sprintf("   Median solvency ratio: %.3f\n", median(df$solvency_ratio, na.rm = TRUE)))

cat("\n================================================================================\n")
cat("TEST FIX COMPLETE - COMPARE RESULTS ABOVE\n")
cat("================================================================================\n")
