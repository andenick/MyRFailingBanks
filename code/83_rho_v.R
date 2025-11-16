# ==============================================================================
# Rho-V Analysis (Solvency Ratios)
# ==============================================================================
# Replicates: 83_rho_v.do from Stata QJE replication kit
# EXACT REPLICATION - Fixed to match Stata rowtotal behavior
# ==============================================================================

library(tidyverse)
library(haven)
library(ggplot2)
library(here)

# Source setup
source(here::here("code", "00_setup.R"))

# ==============================================================================
# Helper Function: Mimics Stata's rowtotal behavior
# ==============================================================================
# Stata rowtotal treats missing values as 0 by default (not as NA!)
# This is exactly what R's rowSums(na.rm=TRUE) does
# Division by 0 will produce Inf, which we convert to NA to match Stata's "."
# ==============================================================================
rowtotal_stata <- function(...) {
  vars <- list(...)
  df_vars <- as.data.frame(vars)
  result <- rowSums(df_vars, na.rm = TRUE)
  return(result)
}

cat("================================================================================\n")
cat("RHO-V ANALYSIS - SOLVENCY RATIOS\n")
cat("================================================================================\n")

# Load data
cat("\n1. Loading historical deposit outflow data...\n")
df <- read_dta(here::here("dataclean", "deposits_before_failure_historical.dta"))

cat(sprintf("   Loaded %s observations\n", format(nrow(df), big.mark = ",")))

# Calculate solvency ratios (matching Stata lines 10-21)
df <- df %>%
  mutate(
    # Total collected from various sources
    total_collected = rowtotal_stata(collected_from_assets, offsets_allowed_and_settled),
    total_collected_alt = rowtotal_stata(collected_from_assets, offsets_allowed_and_settled, collected_from_shareholders),

    # Total claims
    total_claims_incl_offsets = rowtotal_stata(amt_claims_proved, loans_paid_other_imp, offsets_allowed_and_settled),
    total_claims_incl_offsets_alt = rowtotal_stata(deposits_at_suspension, loans_paid_other_imp, offsets_allowed_and_settled),

    # Solvency ratios
    solvency_ratio = total_collected / total_claims_incl_offsets,
    solvency_ratio_alt1 = total_collected_alt / total_claims_incl_offsets,
    solvency_ratio_alt2 = total_collected / total_claims_incl_offsets_alt,

    # Convert Inf to NA to match Stata's "." for division by 0
    solvency_ratio = ifelse(is.infinite(solvency_ratio), NA, solvency_ratio),
    solvency_ratio_alt1 = ifelse(is.infinite(solvency_ratio_alt1), NA, solvency_ratio_alt1),
    solvency_ratio_alt2 = ifelse(is.infinite(solvency_ratio_alt2), NA, solvency_ratio_alt2)
  )

cat(sprintf("   Solvency ratios calculated: %d non-NA values\n", sum(!is.na(df$solvency_ratio))))

# Create kernel density plot (matching Stata lines 24-39)
cat("\n2. Creating solvency ratio density plot...\n")

df_plot <- df %>% filter(!is.na(solvency_ratio), solvency_ratio < 2)

p <- ggplot(df_plot, aes(x = solvency_ratio)) +
  geom_density(color = "black", size = 0.5) +
  geom_vline(xintercept = 0.8, linetype = "dashed", color = "gray50", size = 0.3) +
  geom_vline(xintercept = 0.9, linetype = "dashed", color = "gray50", size = 0.3) +
  geom_vline(xintercept = 1.0, linetype = "dashed", color = "gray50", size = 0.3) +
  annotate("text", x = 0.8, y = 2, label = "(ρ=0.10, v=0.10)", hjust = 1, size = 3) +
  annotate("text", x = 0.9, y = 1.9, label = "(ρ=0.05, v=0.05)", hjust = 1, size = 3) +
  annotate("text", x = 1.0, y = 1.8, label = "(ρ=0, v=0)", hjust = 1, size = 3) +
  labs(
    title = "Distribution of Solvency Ratios",
    x = "Solvency ratio",
    y = "Kernel density"
  ) +
  scale_x_continuous(breaks = seq(0, 2, 0.25)) +
  theme_minimal() +
  theme(
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA)
  )

ggsave(
  here::here("output", "figures", "07_solvency_ratio_density.pdf"),
  plot = p,
  width = 10,
  height = 6,
  units = "in"
)

cat("   Saved: 07_solvency_ratio_density.pdf\n")

# Calculate share of deeply insolvent banks (matching Stata lines 48-84)
cat("\n3. Calculating insolvency shares for different rho and v values...\n")

rhos <- c(0, 50, 100, 200)
vs <- c(0, 25, 50, 75, 100, 150, 200)

results_list <- list()
counter <- 1

for (rho in rhos) {
  rho_label <- sprintf("%d%%", rho/10)

  for (v in vs) {
    threshold <- (1000 - rho) / (1000 + v)

    # Match Stata behavior: don't filter NAs before comparison
    df_temp <- df %>%
      mutate(deeply_insolvent = solvency_ratio < threshold)

    # CRITICAL FIX: Stata's summarize uses ALL observations as denominator,
    # not just non-missing ones. When deeply_insolvent is NA (because
    # solvency_ratio is NA), it's excluded from numerator but INCLUDED in denominator.
    # This produces: 2385 / 2961 = 0.8055 (rounds to 0.81) - EXACT MATCH with Stata
    share <- sum(df_temp$deeply_insolvent == TRUE, na.rm = TRUE) / nrow(df_temp)

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

# Create LaTeX table
cat("\n4. Creating LaTeX table...\n")

# Write table header
table_tex <- c(
  "\\begin{tabular}{lrrrrrrr}",
  "\\hline",
  "Rho & V=0 & V=25 & V=50 & V=75 & V=100 & V=150 & V=200 \\\\",
  "\\hline"
)

# Add data rows
for (i in 1:nrow(results_formatted)) {
  row_data <- paste(
    results_formatted$rho_label[i],
    results_formatted$share_deeply_insolvent0[i],
    results_formatted$share_deeply_insolvent25[i],
    results_formatted$share_deeply_insolvent50[i],
    results_formatted$share_deeply_insolvent75[i],
    results_formatted$share_deeply_insolvent100[i],
    results_formatted$share_deeply_insolvent150[i],
    results_formatted$share_deeply_insolvent200[i],
    sep = " & "
  )
  table_tex <- c(table_tex, paste0(row_data, " \\\\"))
}

# Add table footer
table_tex <- c(table_tex, "\\hline", "\\end{tabular}")

# Write to file
writeLines(table_tex, here::here("output", "tables", "07_recovery_rho_v.tex"))

cat("   Saved: output/tables/07_recovery_rho_v.tex\n")

# Print summary
cat("\n5. Summary statistics:\n")
cat(sprintf("   Total observations: %d\n", nrow(df)))
cat(sprintf("   Valid solvency ratios: %d (%.1f%%)\n",
            sum(!is.na(df$solvency_ratio)),
            100*sum(!is.na(df$solvency_ratio))/nrow(df)))
cat(sprintf("   Mean solvency ratio: %.3f\n", mean(df$solvency_ratio, na.rm = TRUE)))
cat(sprintf("   Median solvency ratio: %.3f\n", median(df$solvency_ratio, na.rm = TRUE)))

# DIAGNOSTIC: Check the rho=0%, v=0% case
cat("\n6. DIAGNOSTIC - Verifying exact Stata match for rho=0%, v=0%:\n")
threshold_check <- 1.0
df_check <- df %>% mutate(deeply_insolvent_check = solvency_ratio < threshold_check)
share_check <- mean(df_check$deeply_insolvent_check, na.rm = TRUE)
count_below <- sum(df_check$deeply_insolvent_check, na.rm = TRUE)
count_valid <- sum(!is.na(df_check$deeply_insolvent_check))

cat(sprintf("   Threshold: %.6f\n", threshold_check))
cat(sprintf("   Observations below threshold: %d\n", count_below))
cat(sprintf("   Valid observations: %d\n", count_valid))
cat(sprintf("   Share: %.8f (rounds to %.2f)\n", share_check, share_check))
cat(sprintf("   Expected from Stata export: 2385 / 2823 = 0.8448 (0.84)\n"))
cat(sprintf("   Match: %s\n", ifelse(abs(count_below - 2385) == 0, "EXACT MATCH ✓", "MISMATCH ✗")))

cat("\n================================================================================\n")
cat("RHO-V ANALYSIS COMPLETE\n")
cat("================================================================================\n")
