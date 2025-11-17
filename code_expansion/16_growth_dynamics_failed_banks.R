# ==============================================================================
# Script 16: Growth Dynamics in Failed Banks
# ==============================================================================
# Purpose: Line plot showing boom-period growth vs bust-period contraction
#          for failed vs survived banks
# Output:  16_growth_dynamics_failed_banks.png (300 DPI)
# ==============================================================================

library(tidyverse)
library(here)
library(scales)

# Set paths
dataclean_dir <- here::here("dataclean")
output_dir <- here::here("code_expansion", "presentation_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Load panel data
panel_data <- readRDS(file.path(dataclean_dir, "combined-data.rds"))

# Prepare data: banks with growth measures
growth_data <- panel_data %>%
  filter(!is.na(growth_boom), !is.na(growth_bust), !is.na(failed)) %>%
  filter(growth_boom >= -1, growth_boom <= 3) %>% # Reasonable range
  filter(growth_bust >= -1, growth_bust <= 3) %>%
  mutate(
    failure_status = ifelse(failed == 1, "Failed Banks", "Non-Failed Banks"),
    era = case_when(
      year >= 1863 & year < 1930 ~ "Pre-Depression\n(1863-1929)",
      year >= 1930 & year < 1960 ~ "Depression Era\n(1930-1959)",
      year >= 1960 & year < 2007 ~ "Modern Pre-Crisis\n(1960-2006)",
      year >= 2007 ~ "Financial Crisis\n(2007-2024)",
      TRUE ~ "Other"
    )
  ) %>%
  filter(era != "Other")

# Calculate average growth dynamics by era and failure status
summary_growth <- growth_data %>%
  group_by(era, failure_status) %>%
  summarize(
    avg_boom_growth = mean(growth_boom, na.rm = TRUE) * 100,
    avg_bust_growth = mean(growth_bust, na.rm = TRUE) * 100,
    n_banks = n(),
    .groups = "drop"
  ) %>%
  pivot_longer(
    cols = c(avg_boom_growth, avg_bust_growth),
    names_to = "Period",
    values_to = "Growth_Rate"
  ) %>%
  mutate(
    Period = ifelse(Period == "avg_boom_growth", "Boom (t-10 to t-3)", "Bust (t-3 to t)")
  )

# Create visualization
p <- ggplot(summary_growth, aes(x = Period, y = Growth_Rate, color = failure_status, group = failure_status)) +
  geom_line(linewidth = 1.5, alpha = 0.8) +
  geom_point(size = 4, alpha = 0.9) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.6) +
  facet_wrap(~ era, ncol = 2, scales = "free_y") +
  scale_y_continuous(
    name = "Average Real Asset Growth (%)",
    breaks = seq(-50, 150, 25)
  ) +
  scale_x_discrete(name = "") +
  scale_color_manual(
    name = "",
    values = c("Failed Banks" = "#d62728", "Non-Failed Banks" = "#2ca02c")
  ) +
  labs(
    title = "Failed Banks Grow Faster in Booms, Contract Harder in Busts",
    subtitle = "Boom-bust pattern: Failed banks pursue aggressive growth, then experience severe contraction before failure",
    caption = "Source: Combined call reports. Boom = t-10 to t-3 quarters before failure/observation. Bust = t-3 to t."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0),
    legend.position = "bottom",
    legend.text = element_text(size = 11),
    strip.text = element_text(face = "bold", size = 10),
    strip.background = element_rect(fill = "gray90", color = NA),
    panel.grid.minor = element_blank(),
    panel.spacing = unit(1, "lines"),
    axis.text.x = element_text(size = 9)
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "16_growth_dynamics_failed_banks.png"),
  plot = p,
  width = 12,
  height = 10,
  dpi = 300,
  bg = "white"
)

# Print summary
cat("\n=== GROWTH DYNAMICS ===\n\n")
print(summary_growth, n = Inf)

cat("\n✓ Saved: 16_growth_dynamics_failed_banks.png (12\" × 10\", 300 DPI)\n")
