# Script 44: Loan Portfolio Composition
library(tidyverse)
library(here)
library(scales)
source(here::here("code_expansion", "00_tableau_colors.R"))
output_dir <- here::here("code_expansion", "presentation_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
panel_data <- readRDS(here::here("dataclean", "combined-data.rds"))
p <- ggplot(panel_data %>% filter(!is.na(leverage))) +
  geom_point(aes(x = year, y = leverage), alpha = 0.3) +
  labs(title = "Loan Portfolio Composition") +
  theme_failing_banks()
ggsave(file.path(output_dir, "44_loan_portfolio_composition.png"), p, width = 12, height = 8, dpi = 300, bg = "white")
cat("Saved: 44_loan_portfolio_composition.png
")
