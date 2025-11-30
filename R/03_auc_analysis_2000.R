# ===========================================================================
# Modern Period (2000+) AUC/ROC Analysis
# ===========================================================================

library(tidyverse)
library(pROC)

cat("\n===========================================================================\n")
cat("AUC/ROC ANALYSIS: MODERN PERIOD (2000-PRESENT)\n")
cat("===========================================================================\n\n")

# Load model results
results <- readRDS("D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/data/model_results_2000.rds")
data <- results$data

# Calculate AUC for all models
auc_results <- data.frame()

for (model_type in c("lpm", "logit", "probit")) {
  model_list <- results[[model_type]]

  for (i in 1:length(model_list)) {
    mod <- model_list[[i]]

    # Get fitted values (predictions are already on same rows as data used in model)
    preds <- fitted(mod$fit)
    actual_values <- mod$fit$model$F1_failure  # Get actual from model frame

    # Calculate ROC and AUC
    roc_obj <- roc(actual_values, preds, quiet = TRUE, direction = "<")
    auc_val <- as.numeric(auc(roc_obj))

    auc_results <- rbind(auc_results, data.frame(
      spec = i,
      spec_name = mod$spec_name,
      model_type = model_type,
      auc = auc_val,
      n_obs = length(preds)
    ))

    cat(sprintf("%s - %s: AUC = %.4f (n=%s)\n",
                model_type, mod$spec_name, auc_val, format(length(preds), big.mark=",")))
  }
}

cat("\n")

# Save AUC results
write.csv(auc_results,
          "D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/outputs/tables/auc_results_2000.csv",
          row.names = FALSE)

cat("✓ AUC results saved\n\n")

# Create ROC plots
cat("Creating ROC curve plots...\n")

pdf("D:/Arcanum/Projects/FailingBanks/Technical/modern_2000_analysis/outputs/figures/roc_curves_2000.pdf",
    width = 12, height = 8)

par(mfrow = c(2, 2))

for (i in 1:4) {
  # Get fitted values from each model
  lpm_fit <- fitted(results$lpm[[i]]$fit)
  logit_fit <- fitted(results$logit[[i]]$fit)
  probit_fit <- fitted(results$probit[[i]]$fit)

  # Get actual values from model frames
  lpm_actual <- results$lpm[[i]]$fit$model$F1_failure
  logit_actual <- results$logit[[i]]$fit$model$F1_failure
  probit_actual <- results$probit[[i]]$fit$model$F1_failure

  # Calculate ROC curves
  roc_lpm <- roc(lpm_actual, lpm_fit, quiet = TRUE, direction = "<")
  roc_logit <- roc(logit_actual, logit_fit, quiet = TRUE, direction = "<")
  roc_probit <- roc(probit_actual, probit_fit, quiet = TRUE, direction = "<")

  # Plot
  plot(roc_lpm, col = "blue", lwd = 2,
       main = results$specs[[i]]$name,
       print.auc = FALSE)
  lines(roc_logit, col = "red", lwd = 2)
  lines(roc_probit, col = "green", lwd = 2)
  abline(a = 0, b = 1, lty = 2, col = "gray")

  legend("bottomright",
         legend = c(
           sprintf("LPM (AUC=%.4f)", as.numeric(auc(roc_lpm))),
           sprintf("Logit (AUC=%.4f)", as.numeric(auc(roc_logit))),
           sprintf("Probit (AUC=%.4f)", as.numeric(auc(roc_probit)))
         ),
         col = c("blue", "red", "green"),
         lwd = 2,
         cex = 0.8)
}

dev.off()

cat("\n✓ AUC analysis complete\n")
cat("✓ ROC curves saved\n\n")
cat("Next step: Run 04_create_outputs_2000.R\n\n")
