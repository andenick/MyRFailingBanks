# ==============================================================================
# Script 40: Global Financial Crisis Timeline (2004-2012)
# ==============================================================================
library(tidyverse)
library(here)
library(scales)
source(here::here("code_expansion", "00_tableau_colors.R"))
output_dir <- here::here("code_expansion", "presentation_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
panel_data <- readRDS(here::here("dataclean", "combined-data.rds"))
gfc_data <- panel_data %>%
  filter(year >= 2004 & year <= 2012) %>%
  mutate(
    phase = case_when(
      year >= 2004 & year <= 2006 ~ "Boom (2004-2006)",
      year == 2007 ~ "Crisis Begins (2007)",
      year == 2008 | year == 2009 ~ "Crash (2008-2009)",
      year >= 2010 & year <= 2012 ~ "Recovery (2010-2012)",
      TRUE ~ "Other"
    )
  ) %>%
  filter(phase != "Other")
metrics_summary <- gfc_data %>%
  group_by(phase, year) %>%
  summarize(
    failures = sum(failed_bank == 1, na.rm = TRUE),
    mean_income = mean(income_ratio, na.rm = TRUE) * 100,
    mean_npl = mean(npl_ratio, na.rm = TRUE) * 100,
    mean_liquid = mean(liquid_ratio, na.rm = TRUE) * 100,
    .groups = "drop"
  )
p <- ggplot(metrics_summary, aes(x = year, y = failures)) +
  geom_col(fill = color_crisis, alpha = 0.8) +
  scale_x_continuous(breaks = 2004:2012) +
  labs(title = "Global Financial Crisis: Boom, Crash, Recovery (2004-2012)",
       subtitle = "Annual bank failures during GFC period") +
  theme_failing_banks()
ggsave(file.path(output_dir, "40_gfc_timeline.png"), plot = p, width = 14, height = 10, dpi = 300, bg = "white")
cat("\n✓ Saved: 40_gfc_timeline.png\n")
