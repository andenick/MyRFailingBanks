# ==============================================================================
# Script 42: Capital Adequacy - Pre vs Post FDIC
# ==============================================================================
library(tidyverse)
library(here)
library(scales)
source(here::here("code_expansion", "00_tableau_colors.R"))
output_dir <- here::here("code_expansion", "presentation_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
panel_data <- readRDS(here::here("dataclean", "combined-data.rds"))
capital_data <- panel_data %>%
  filter(!is.na(leverage)) %>%
  mutate(
    leverage_pct = leverage * 100,
    fdic_era = ifelse(year < 1934, "Pre-FDIC", "Post-FDIC"),
    bank_status = ifelse(failed_bank == 1, "Failed", "Non-Failed")
  )
p <- ggplot(capital_data, aes(x = interaction(fdic_era, bank_status), y = leverage_pct, fill = bank_status)) +
  geom_violin(alpha = 0.6) +
  geom_boxplot(width = 0.15, alpha = 0.8) +
  scale_fill_manual(values = comparison_colors) +
  labs(title = "Capital Adequacy Improves Post-FDIC: Higher and More Stable",
       subtitle = "Leverage (equity/assets) distributions") +
  theme_failing_banks()
ggsave(file.path(output_dir, "42_capital_adequacy_pre_post_fdic.png"), plot = p, width = 12, height = 8, dpi = 300, bg = "white")
cat("\n✓ Saved: 42_capital_adequacy_pre_post_fdic.png\n")
