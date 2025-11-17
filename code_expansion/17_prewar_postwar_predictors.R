# ==============================================================================
# Script 17: Pre-War vs Post-War Failure Predictors
# ==============================================================================
# Purpose: Forest plot comparing coefficient importance of key fundamentals
#          between pre-1941 and post-1959 periods
# Output:  17_prewar_postwar_predictors.png (300 DPI)
# ==============================================================================

library(tidyverse)
library(here)
library(fixest)
library(scales)

# Set paths
dataclean_dir <- here::here("dataclean")
output_dir <- here::here("code_expansion", "presentation_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Load regression data
reg_data <- readRDS(file.path(dataclean_dir, "temp_reg_data.rds"))

# Define pre-war and post-war samples
prewar_data <- reg_data %>% filter(final_year <= 1941, final_year >= 1863)
postwar_data <- reg_data %>% filter(final_year >= 1959, final_year <= 2024)

# Run regressions for pre-war (using available variables)
model_prewar <- feols(
  failed ~ leverage + liquid_ratio + loan_ratio + noncore_ratio + growth | state + year,
  data = prewar_data,
  cluster = ~ bank_id
)

# Run regressions for post-war
model_postwar <- feols(
  failed ~ leverage + liquid_ratio + loan_ratio + noncore_ratio + growth + income_ratio | state + year,
  data = postwar_data,
  cluster = ~ bank_id
)

# Extract coefficients
coefs_prewar <- broom::tidy(model_prewar, conf.int = TRUE) %>%
  filter(term %in% c("leverage", "liquid_ratio", "loan_ratio", "noncore_ratio", "growth")) %>%
  mutate(Period = "Pre-War (1863-1941)")

coefs_postwar <- broom::tidy(model_postwar, conf.int = TRUE) %>%
  filter(term %in% c("leverage", "liquid_ratio", "loan_ratio", "noncore_ratio", "growth", "income_ratio")) %>%
  mutate(Period = "Post-War (1959-2024)")

# Combine
coef_comparison <- bind_rows(coefs_prewar, coefs_postwar) %>%
  mutate(
    Variable = case_when(
      term == "leverage" ~ "Capital (Equity/Assets)",
      term == "liquid_ratio" ~ "Liquidity Ratio",
      term == "loan_ratio" ~ "Loan Ratio",
      term == "noncore_ratio" ~ "Noncore Funding",
      term == "growth" ~ "Asset Growth (3yr)",
      term == "income_ratio" ~ "Net Income/Assets",
      TRUE ~ term
    ),
    Variable = factor(Variable, levels = c(
      "Capital (Equity/Assets)",
      "Liquidity Ratio",
      "Loan Ratio",
      "Noncore Funding",
      "Asset Growth (3yr)",
      "Net Income/Assets"
    ))
  )

# Create forest plot
p <- ggplot(coef_comparison, aes(x = estimate, y = Variable, color = Period)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.6) +
  geom_point(size = 4, position = position_dodge(width = 0.5)) +
  geom_errorbarh(
    aes(xmin = conf.low, xmax = conf.high),
    height = 0.2,
    linewidth = 1,
    position = position_dodge(width = 0.5)
  ) +
  scale_x_continuous(
    name = "Coefficient Estimate (Effect on Failure Probability)",
    breaks = seq(-0.5, 0.5, 0.1)
  ) +
  scale_y_discrete(name = "") +
  scale_color_manual(
    name = "Period",
    values = c("Pre-War (1863-1941)" = "#1f77b4", "Post-War (1959-2024)" = "#ff7f0e")
  ) +
  labs(
    title = "Failure Predictors Remain Consistent Across 160 Years",
    subtitle = "Lower capital, lower liquidity, higher loans, and higher noncore funding predict failure in both eras",
    caption = "Source: Regression analysis. Points show coefficient estimates with 95% confidence intervals. Controls: state, year FE."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 10),
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    axis.text.y = element_text(size = 11, face = "bold")
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "17_prewar_postwar_predictors.png"),
  plot = p,
  width = 12,
  height = 8,
  dpi = 300,
  bg = "white"
)

# Print coefficients
cat("\n=== PRE-WAR VS POST-WAR PREDICTORS ===\n\n")
cat("Pre-War Sample:\n")
print(coefs_prewar %>% select(term, estimate, conf.low, conf.high), n = Inf)
cat("\nPost-War Sample:\n")
print(coefs_postwar %>% select(term, estimate, conf.low, conf.high), n = Inf)

cat("\n✓ Saved: 17_prewar_postwar_predictors.png (12\" × 8\", 300 DPI)\n")
