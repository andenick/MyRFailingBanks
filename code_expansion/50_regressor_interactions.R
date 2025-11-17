# Script 50: Regressor Interactions
library(tidyverse)
library(here)
library(scales)
source(here::here("code_expansion", "00_tableau_colors.R"))
output_dir <- here::here("code_expansion", "presentation_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
panel_data <- readRDS(here::here("dataclean", "combined-data.rds"))
p <- ggplot(panel_data %>% filter(!is.na(leverage))) +
  geom_point(aes(x = year, y = leverage), alpha = 0.3) +
  labs(title = "Regressor Interactions") +
  theme_failing_banks()
ggsave(file.path(output_dir, "50_regressor_interactions.png"), p, width = 12, height = 8, dpi = 300, bg = "white")
cat("Saved: 50_regressor_interactions.png
")
