# ==============================================================================
# Script 07: Recovery Rate Distribution by Era
# ==============================================================================
# Purpose: Create histogram/density plot showing full distribution of depositor
#          recovery rates (dividends 0-100%) across 6 historical eras
# Output:  07_recovery_distribution_by_era.png (300 DPI)
# ==============================================================================

library(tidyverse)
library(here)
library(scales)

# Load Tableau color palette
source(here::here("code_expansion", "00_tableau_colors.R"))

# Set paths
tempfiles_dir <- here::here("tempfiles")
output_dir <- here::here("code_expansion", "presentation_outputs")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Load receivership data
recv_data <- readRDS(file.path(tempfiles_dir, "receivership_dataset_tmp.rds"))

# Parse receivership_date if needed and create era variable
recv_data <- recv_data %>%
  mutate(
    receivership_date = as.Date(date_receiver_appt, format = "%b. %d,%Y"),
    # Create era variable based on receivership date
    era = case_when(
      receivership_date >= as.Date("1863-01-01") & receivership_date < as.Date("1914-01-01") ~ 1,
      receivership_date >= as.Date("1914-01-01") & receivership_date <= as.Date("1928-12-31") ~ 2,
      receivership_date >= as.Date("1929-01-01") & receivership_date <= as.Date("1933-03-06") ~ 3,
      receivership_date >= as.Date("1933-02-01") & receivership_date <= as.Date("1935-01-01") ~ 4,
      final_year >= 1984 & final_year <= 2006 ~ 5,
      final_year >= 2007 & final_year <= 2023 ~ 6,
      TRUE ~ NA_real_
    ),
    # Create era labels
    era_label = case_when(
      era == 1 ~ "1863-1913\nNational Banking",
      era == 2 ~ "1914-1928\nEarly Fed/WWI",
      era == 3 ~ "1929-1933\nGreat Depression\n(Pre-Holiday)",
      era == 4 ~ "1933-1935\nGreat Depression\n(Post-Holiday)",
      era == 5 ~ "1984-2006\nModern Pre-Crisis",
      era == 6 ~ "2007-2023\nFinancial Crisis",
      TRUE ~ "Other"
    ),
    era_label = factor(era_label, levels = c(
      "1863-1913\nNational Banking",
      "1914-1928\nEarly Fed/WWI",
      "1929-1933\nGreat Depression\n(Pre-Holiday)",
      "1933-1935\nGreat Depression\n(Post-Holiday)",
      "1984-2006\nModern Pre-Crisis",
      "2007-2023\nFinancial Crisis"
    )),
    # Create full recovery indicator
    full_recov = ifelse(!is.na(dividends) & dividends >= 99.9, 1, 0)
  ) %>%
  filter(!is.na(dividends), !is.na(era_label), era_label != "Other")

# Calculate summary statistics
summary_stats <- recv_data %>%
  group_by(era_label) %>%
  summarize(
    n = n(),
    mean_recovery = mean(dividends, na.rm = TRUE),
    median_recovery = median(dividends, na.rm = TRUE),
    pct_full_recov = mean(full_recov, na.rm = TRUE) * 100,
    .groups = "drop"
  )

# Create visualization
p <- ggplot(recv_data, aes(x = dividends, fill = era_label)) +
  geom_density(alpha = 0.6, color = NA) +
  facet_wrap(~ era_label, ncol = 2, scales = "free_y") +
  scale_x_continuous(
    name = "Depositor Recovery Rate (%)",
    breaks = seq(0, 100, 25),
    limits = c(0, 100)
  ) +
  scale_y_continuous(name = "Density") +
  scale_fill_manual(
    name = "Era",
    values = era_colors,
    guide = "none"
  ) +
  labs(
    title = "Distribution of Depositor Recovery Rates Across Historical Eras",
    subtitle = "Percentage of deposits recovered in bank receiverships (0-100%)",
    caption = "Source: OCC receivership records (1863-2023). Each panel shows density distribution for one era."
  ) +
  theme_failing_banks() +
  theme(
    strip.text = element_text(face = "bold", size = 10),
    strip.background = element_rect(fill = "gray90", color = NA),
    panel.spacing = unit(1, "lines")
  )

# Save high-resolution output
ggsave(
  filename = file.path(output_dir, "07_recovery_distribution_by_era.png"),
  plot = p,
  width = 12,
  height = 10,
  dpi = 300,
  bg = "white"
)

# Print summary statistics
cat("\n=== RECOVERY RATE DISTRIBUTION BY ERA ===\n\n")
print(summary_stats, n = Inf)

cat("\n✓ Saved: 07_recovery_distribution_by_era.png (12\" × 10\", 300 DPI)\n")
