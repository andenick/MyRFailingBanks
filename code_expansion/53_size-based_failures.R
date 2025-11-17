# Script 53: Size-Based Failures
library(tidyverse)
library(here)
library(scales)
source(here::here("code_expansion", "00_tableau_colors.R"))
output_dir <- here::here("code_expansion", "presentation_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
panel_data <- readRDS(here::here("dataclean", "combined-data.rds"))
p <- ggplot(panel_data %>% filter(!is.na(leverage))) +
  geom_point(aes(x = year, y = leverage), alpha = 0.3) +
  labs(title = "Size-Based Failures") +
  theme_failing_banks()
ggsave(file.path(output_dir, "53_size-based_failures.png"), p, width = 12, height = 8, dpi = 300, bg = "white")
cat("Saved: 53_size-based_failures.png
")
