# ===========================================================================
# Modern Period (2000+) Output Generation
# ===========================================================================

library(tidyverse)
library(openxlsx)

cat("\n===========================================================================\n")
cat("OUTPUT GENERATION: MODERN PERIOD (2000-PRESENT)\n")
cat("===========================================================================\n\n")

# Load results
results <- readRDS("D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/data/model_results_2000.rds")
auc_results <- read.csv("D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/outputs/tables/auc_results_2000.csv")
coefs <- read.csv("D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/outputs/tables/coefficients_all_models_2000.csv")

# ===========================================================================
# 1. CREATE EXCEL WORKBOOK
# ===========================================================================

cat("Creating consolidated Excel workbook...\n")

wb <- createWorkbook()

# Sheet 1: AUC Results
addWorksheet(wb, "AUC Results")
writeData(wb, "AUC Results", auc_results)

# Sheet 2: All Coefficients
addWorksheet(wb, "All Coefficients")
writeData(wb, "All Coefficients", coefs)

# Sheet 3: Model Comparison (pivot)
auc_wide <- auc_results %>%
  select(spec_name, model_type, auc) %>%
  pivot_wider(names_from = model_type, values_from = auc)

addWorksheet(wb, "AUC Comparison")
writeData(wb, "AUC Comparison", auc_wide)

# Sheet 4: Key Coefficients Only
key_coefs <- coefs %>%
  filter(variable %in% c("income_ratio", "noncore_ratio", "log_age", "noncore_ratio:income_ratio"))

addWorksheet(wb, "Key Coefficients")
writeData(wb, "Key Coefficients", key_coefs)

# Save workbook
saveWorkbook(wb,
             "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/outputs/tables/modern_2000_correia_results.xlsx",
             overwrite = TRUE)

cat("  ✓ Excel workbook created\n\n")

# ===========================================================================
# 2. CREATE COEFFICIENT PLOT
# ===========================================================================

cat("Creating coefficient comparison plot...\n")

# Filter to Spec 3 (interaction model)
plot_data <- key_coefs %>%
  filter(spec == 3, variable != "(Intercept)") %>%
  mutate(
    ci_lower = coefficient - 1.96 * se,
    ci_upper = coefficient + 1.96 * se
  )

library(ggplot2)

p <- ggplot(plot_data, aes(x = variable, y = coefficient, color = model_type)) +
  geom_point(position = position_dodge(width = 0.5), size = 3) +
  geom_errorbar(aes(ymin = ci_lower, ymax = ci_upper),
                position = position_dodge(width = 0.5),
                width = 0.2) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  coord_flip() +
  labs(
    title = "Model 3: Solvency × Funding Interaction - Coefficient Estimates",
    subtitle = "Point estimates with 95% confidence intervals (Modern Period 2000-2023)",
    x = NULL,
    y = "Coefficient Estimate",
    color = "Model Type"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave("D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/outputs/figures/coefficient_plot_2000.pdf",
       p, width = 10, height = 6)

cat("  ✓ Coefficient plot created\n\n")

# ===========================================================================
# 3. CREATE SUMMARY REPORT
# ===========================================================================

cat("Creating summary report...\n")

# Correia benchmarks for comparison
correia_benchmarks <- data.frame(
  spec = 1:4,
  correia_auc = c(0.683, 0.804, 0.823, 0.864)
)

# Compare our Logit results with Correia
our_logit <- auc_results %>% filter(model_type == "logit")
comparison <- our_logit %>%
  left_join(correia_benchmarks, by = "spec") %>%
  mutate(
    diff = auc - correia_auc,
    pct_diff = (auc - correia_auc) / correia_auc * 100
  )

report <- c(
  "===========================================================================",
  "MODERN PERIOD (2000-PRESENT) REGRESSION ANALYSIS - SUMMARY REPORT",
  "===========================================================================",
  sprintf("Generated: %s", Sys.time()),
  "",
  "SAMPLE CHARACTERISTICS:",
  sprintf("  Period: 2000-2023 (24 years)"),
  sprintf("  Observations: %s", format(nrow(results$data), big.mark=",")),
  sprintf("  Failure events: %d (%.4f%%)",
          sum(results$data$F1_failure), mean(results$data$F1_failure) * 100),
  "",
  "MODELS ESTIMATED:",
  "  - Linear Probability Model (LPM) - 4 specifications",
  "  - Logit - 4 specifications",
  "  - Probit - 4 specifications",
  "  - Total: 12 models",
  "",
  "AUC RESULTS (IN-SAMPLE):",
  "-----------------------------------",
  "",
  "Model 1: Solvency Only",
  sprintf("  LPM:    %.4f", auc_results$auc[auc_results$spec==1 & auc_results$model_type=="lpm"]),
  sprintf("  Logit:  %.4f", auc_results$auc[auc_results$spec==1 & auc_results$model_type=="logit"]),
  sprintf("  Probit: %.4f", auc_results$auc[auc_results$spec==1 & auc_results$model_type=="probit"]),
  "",
  "Model 2: Funding Only",
  sprintf("  LPM:    %.4f", auc_results$auc[auc_results$spec==2 & auc_results$model_type=="lpm"]),
  sprintf("  Logit:  %.4f", auc_results$auc[auc_results$spec==2 & auc_results$model_type=="logit"]),
  sprintf("  Probit: %.4f", auc_results$auc[auc_results$spec==2 & auc_results$model_type=="probit"]),
  "",
  "Model 3: Solvency × Funding",
  sprintf("  LPM:    %.4f", auc_results$auc[auc_results$spec==3 & auc_results$model_type=="lpm"]),
  sprintf("  Logit:  %.4f", auc_results$auc[auc_results$spec==3 & auc_results$model_type=="logit"]),
  sprintf("  Probit: %.4f", auc_results$auc[auc_results$spec==3 & auc_results$model_type=="probit"]),
  "",
  "Model 4: Full with Controls",
  sprintf("  LPM:    %.4f", auc_results$auc[auc_results$spec==4 & auc_results$model_type=="lpm"]),
  sprintf("  Logit:  %.4f", auc_results$auc[auc_results$spec==4 & auc_results$model_type=="logit"]),
  sprintf("  Probit: %.4f", auc_results$auc[auc_results$spec==4 & auc_results$model_type=="probit"]),
  "",
  "COMPARISON WITH CORREIA BENCHMARKS (Logit models):",
  "---------------------------------------------------",
  sprintf("Spec 1: Ours=%.4f, Correia=%.4f, Diff=%+.4f (%+.1f%%)",
          comparison$auc[1], comparison$correia_auc[1], comparison$diff[1], comparison$pct_diff[1]),
  sprintf("Spec 2: Ours=%.4f, Correia=%.4f, Diff=%+.4f (%+.1f%%)",
          comparison$auc[2], comparison$correia_auc[2], comparison$diff[2], comparison$pct_diff[2]),
  sprintf("Spec 3: Ours=%.4f, Correia=%.4f, Diff=%+.4f (%+.1f%%)",
          comparison$auc[3], comparison$correia_auc[3], comparison$diff[3], comparison$pct_diff[3]),
  sprintf("Spec 4: Ours=%.4f, Correia=%.4f, Diff=%+.4f (%+.1f%%)",
          comparison$auc[4], comparison$correia_auc[4], comparison$diff[4], comparison$pct_diff[4]),
  "",
  "OUTPUTS CREATED:",
  "  - modern_2000_correia_results.xlsx (consolidated Excel workbook)",
  "  - coefficients_all_models_2000.csv (all coefficients)",
  "  - auc_results_2000.csv (AUC comparison)",
  "  - roc_curves_2000.pdf (ROC curve plots)",
  "  - coefficient_plot_2000.pdf (coefficient comparison)",
  "",
  "STATUS: ANALYSIS COMPLETE ✓",
  "==========================================================================="
)

writeLines(report,
           "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/outputs/reports/analysis_summary_2000.txt")

cat("  ✓ Summary report created\n\n")

# Print report to console
cat("\n")
cat(paste(report, collapse = "\n"))
cat("\n\n")

cat("===========================================================================\n")
cat("ALL OUTPUTS CREATED SUCCESSFULLY\n")
cat("===========================================================================\n\n")
