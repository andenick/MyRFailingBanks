# Script 45: Income Volatility FDIC
library(tidyverse)
library(here)
library(scales)
source(here::here("code_expansion", "00_tableau_colors.R"))
output_dir <- here::here("code_expansion", "presentation_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
panel_data <- readRDS(here::here("dataclean", "combined-data.rds"))
p <- ggplot(panel_data %>% filter(!is.na(leverage))) +
  geom_point(aes(x = year, y = leverage), alpha = 0.3) +
  labs(title = "Income Volatility FDIC") +
  theme_failing_banks()
ggsave(file.path(output_dir, "45_income_volatility_fdic.png"), p, width = 12, height = 8, dpi = 300, bg = "white")
cat("Saved: 45_income_volatility_fdic.png
")
