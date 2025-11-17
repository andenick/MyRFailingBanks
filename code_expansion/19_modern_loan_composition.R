# ==============================================================================
# Script 19: Modern Era Loan Composition Evolution
# ==============================================================================
# Purpose: Heatmap showing evolution of loan portfolio composition
#          (real estate, C&I, consumer) in modern era (1984-2024)
# Output:  19_modern_loan_composition.png (300 DPI)
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

# Prepare data: modern era loan composition
loan_composition <- panel_data %>%
  filter(year >= 1984, year <= 2024) %>%
  filter(!is.na(loans_re), !is.na(loans_ci), !is.na(loans_consumer), !is.na(failed)) %>%
  mutate(
    total_loans = loans_re + loans_ci + loans_consumer,
    re_share = ifelse(total_loans > 0, (loans_re / total_loans) * 100, NA),
    ci_share = ifelse(total_loans > 0, (loans_ci / total_loans) * 100, NA),
    consumer_share = ifelse(total_loans > 0, (loans_consumer / total_loans) * 100, NA),
    failure_status = ifelse(failed == 1, "Failed Banks", "Non-Failed Banks")
  ) %>%
  filter(!is.na(re_share), !is.na(ci_share), !is.na(consumer_share)) %>%
  group_by(year, failure_status) %>%
  summarize(
    `Real Estate` = mean(re_share, na.rm = TRUE),
    `Commercial & Industrial` = mean(ci_share, na.rm = TRUE),
    `Consumer` = mean(consumer_share, na.rm = TRUE),
    n_banks = n(),
    .groups = "drop"
  ) %>%
  filter(n_banks >= 10) %>%
  pivot_longer(
    cols = c(`Real Estate`, `Commercial & Industrial`, `Consumer`),
    names_to = "Loan_Type",
    values_to = "Share"
  ) %>%
  mutate(
    Loan_Type = factor(Loan_Type, levels = c("Real Estate", "Commercial & Industrial", "Consumer"))
  )

# Create heatmap
p <- ggplot(loan_composition, aes(x = year, y = Loan_Type, fill = Share)) +
  geom_tile(color = "white", linewidth = 0.5) +
  facet_wrap(~ failure_status, ncol = 1) +
  scale_x_continuous(
    name = "Year",
    breaks = seq(1985, 2020, 5),
    expand = c(0, 0)
  ) +
  scale_y_discrete(name = "") +
  scale_fill_gradient2(
    name = "Share of\nTotal Loans (%)",
    low = "#2166ac",
    mid = "white",
    high = "#b2182b",
    midpoint = 40,
    breaks = seq(0, 80, 20),
    limits = c(0, 80)
  ) +
  labs(
    title = "Evolution of Loan Portfolio Composition in Modern Era (1984-2024)",
    subtitle = "Real estate loans dominate. Failed banks hold slightly higher RE concentrations in crisis periods.",
    caption = "Source: Modern call reports. Heatmap shows average loan composition across all banks by year and failure status."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14, hjust = 0),
    plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0),
    legend.position = "right",
    legend.title = element_text(face = "bold", size = 10),
    strip.text = element_text(face = "bold", size = 11),
    strip.background = element_rect(fill = "gray90", color = NA),
    panel.grid = element_blank(),
    axis.text.y = element_text(size = 11, face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "19_modern_loan_composition.png"),
  plot = p,
  width = 14,
  height = 8,
  dpi = 300,
  bg = "white"
)

cat("\n=== MODERN LOAN COMPOSITION ===\n")
cat(sprintf("Years covered: %d to %d\n", min(loan_composition$year), max(loan_composition$year)))

cat("\n✓ Saved: 19_modern_loan_composition.png (14\" × 8\", 300 DPI)\n")
