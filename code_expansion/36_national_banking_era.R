# Script 36: National Banking Era
library(tidyverse)
library(here)
library(scales)
source(here::here("code_expansion", "00_tableau_colors.R"))
output_dir <- here::here("code_expansion", "presentation_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
panel_data <- readRDS(here::here("dataclean", "combined-data.rds"))
p <- ggplot(panel_data %>% filter(!is.na(leverage))) +
  geom_point(aes(x = year, y = leverage), alpha = 0.3) +
  labs(title = "National Banking Era") +
  theme_failing_banks()
ggsave(file.path(output_dir, "36_national_banking_era.png"), p, width = 12, height = 8, dpi = 300, bg = "white")
cat("Saved: 36_national_banking_era.png
")
