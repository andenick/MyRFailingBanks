# ===========================================================================
# Failure Number and Rate Time Series Plots
# Replicates: 21_descriptives_failures_time_series.do (Stata script)
#
# NOTE: This is a full rewrite to FAITHFULLY replicate the Stata logic.
#
# v12: Fixes "invalid font type" crash.
#      Removed all hard-coded references to the "Avenir" font,
#      which is not universally available to R's PDF graphics device.
#      ggplot2 will now fall back to a system-safe default font.
# ===========================================================================

library(haven)
library(dplyr)
library(tidyr)
library(here)
library(readr)   # For read_csv
library(ggplot2) # For plotting

# Source the setup script for directory paths
source(here::here("code", "00_setup.R"))

# --------------------------------------------------------------------------
# 1. Generate historical sample (1863-1935)
# --------------------------------------------------------------------------
message("Part 1: Processing historical failure and bank counts...")

# --- Historical Failures ---
# Load the file that R script 06 *actually* created
hist_failures_raw <- read_dta(file.path(dataclean_dir, "deposits_before_failure_historical.dta"))

hist_failures <- hist_failures_raw %>%
  mutate(year = as.integer(format(receivership_date, "%Y"))) %>%
  filter(year < 1936) %>%
  count(year, name = "failed_bank")

# Create a complete timeline from 1863-1935
all_hist_years <- tibble(year = 1863:1935)

# Replicates the Stata 'forval' loop to fill in zero-failure years
hist_failures_full <- left_join(all_hist_years, hist_failures, by = "year") %>%
  mutate(failed_bank = ifelse(is.na(failed_bank), 0, failed_bank))

# --- Historical Bank Counts ---
# This file was created by script 04
hist_num_banks <- read_dta(file.path(tempfiles_dir, "call-reports-historical.dta")) %>%
  filter(year < 1936) %>%
  # Get distinct banks *per year*
  distinct(bank_id, year) %>%
  count(year, name = "num_banks")

# --- Combine Historical ---
data_pre_1935 <- left_join(hist_failures_full, hist_num_banks, by = "year")

# --------------------------------------------------------------------------
# 2. Generate modern sample (1935-2024)
# --------------------------------------------------------------------------
message("Part 2: Processing modern failure and bank counts...")

# --- Modern Bank Counts ---
num_banks_fdic <- read_csv(file.path(sources_dir, "FDIC", "number_of_banks_FDIC.csv"),
                           show_col_types = FALSE) %>%
  rename(num_banks = TOTAL) %>%
  select(num_banks, YEAR) %>%
  filter(YEAR > 1935) %>%
  rename(year = YEAR)

# --- Modern Failures ---
mod_failures <- read_dta(file.path(sources_dir, "FDIC", "public-bank-data.dta")) %>%
  filter(is.na(restype1) | restype1 != "OBAM") %>%
  filter(!chclass1 %in% c("SL", "SA")) %>%
  mutate(year = as.integer(format(fail_day, "%Y"))) %>%
  filter(year > 1935) %>%
  count(year, name = "failed_bank")

# --- Combine Modern ---
data_post_1935 <- left_join(num_banks_fdic, mod_failures, by = "year") %>%
  mutate(failed_bank = ifelse(is.na(failed_bank), 0, failed_bank)) %>%
  arrange(year)

# --------------------------------------------------------------------------
# 3. Combine and Create Failure Rate
# --------------------------------------------------------------------------
message("Part 3: Combining datasets and calculating failure rate...")

combined_data <- bind_rows(data_pre_1935, data_post_1935) %>%
  arrange(year) %>%
  mutate(
    failure_rate = failed_bank / num_banks,

    # Create separate columns for plotting (replicating Stata logic)
    failed_bank_hist = ifelse(year <= 1936, failed_bank, NA),
    failed_bank_fdic = ifelse(year > 1934, failed_bank, NA),
    failure_rate_hist = ifelse(year <= 1936, failure_rate, NA),
    failure_rate_fdic = ifelse(year > 1934, failure_rate, NA)
  )

# --------------------------------------------------------------------------
# 4. Figures
# --------------------------------------------------------------------------
message("Part 4: Generating plots...")

# --- Plot 1: Number of Failures ---
crisis_lines <- c(1873, 1884, 1893, 1907, 1920, 1929, 1937, 1982, 2007)
crisis_labels <- tribble(
  ~year, ~label, ~y_pos,
  1873, "Panic of 1873", 400,
  1884, "Panic of 1884", 400,
  1893, "Panic of 1893", 400,
  1907, "Panic of 1907", 400,
  1920, "Recession of 1920-1921", 400,
  1929, "Great Depression", 400,
  1937, "Recession of 1937-1938", 400,
  1982, "S&L Crisis", 400,
  2007, "Global Financial Crisis", 400
)

plot1 <- ggplot(combined_data, aes(x = year)) +
  geom_line(aes(y = failed_bank_hist, color = "National banks"), na.rm = TRUE) +
  geom_line(aes(y = failed_bank_fdic, color = "FDIC member banks"), na.rm = TRUE) +
  geom_vline(xintercept = crisis_lines, linetype = "dashed", color = "grey70") +
  # *** FIX: Removed family = "Avenir" ***
  geom_text(data = crisis_labels, aes(x = year, y = y_pos, label = label),
            angle = 90, vjust = -0.5, hjust = 0, size = 3) +
  scale_color_manual(values = c("National banks" = "black", "FDIC member banks" = "blue"),
                     guide = guide_legend(override.aes = list(linetype = 1, shape = NA))) +
  scale_x_continuous(breaks = seq(1860, 2020, 10)) +
  labs(
    y = "Number of failed banks",
    x = "",
    color = NULL
  ) +
  # *** FIX: Removed base_family = "Avenir" ***
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(file.path(figures_dir, "03_failures_across_time.pdf"), plot1, width = 10, height = 6)
message("Saved: 03_failures_across_time.pdf")

# --- Plot 2: Failure Rate (Crises) ---
crisis_labels_rate <- crisis_labels %>%
  mutate(y_pos = 0.08,
         label = gsub(" \\d{4}-.*", "", label)) # Shorter labels

plot2 <- ggplot(combined_data, aes(x = year)) +
  geom_line(aes(y = failure_rate_hist, color = "National banks"), na.rm = TRUE) +
  geom_line(aes(y = failure_rate_fdic, color = "FDIC member banks"), na.rm = TRUE) +
  geom_vline(xintercept = c(1873, 1884, 1893, 1907, 1920, 1929, 2007, 1982), linetype = "dashed", color = "grey70") +
  # *** FIX: Removed family = "Avenir" ***
  geom_text(data = crisis_labels_rate %>% filter(year != 1937), # 1937 line removed in Stata
            aes(x = year, y = y_pos, label = label),
            angle = 90, vjust = -0.5, hjust = 0, size = 3) +
  scale_color_manual(values = c("National banks" = "black", "FDIC member banks" = "blue"),
                     guide = guide_legend(override.aes = list(linetype = 1, shape = NA))) +
  scale_x_continuous(breaks = seq(1860, 2020, 10)) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1.0)) +
  labs(
    y = "% Failed banks / # banks",
    x = "",
    color = NULL
  ) +
  # *** FIX: Removed base_family = "Avenir" ***
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(file.path(figures_dir, "03_failures_across_time_rate.pdf"), plot2, width = 10, height = 6)
message("Saved: 03_failures_across_time_rate.pdf")

# --- Plot 3: Failure Rate (Policy) ---
policy_lines <- c(1913, 1934, 1983, 1991, 2009)
policy_labels <- tribble(
  ~year, ~label, ~y_pos,
  1913, "Federal Reserve", 0.08,
  1934, "Federal Deposit Insurance Corp. (FDIC)", 0.08,
  1983, "ILSA", 0.08,
  1991, "Basel I", 0.08,
  2009, "SCAP/DFAST/CCAR", 0.08
)

plot3 <- ggplot(combined_data, aes(x = year)) +
  geom_line(aes(y = failure_rate_hist, color = "National banks"), na.rm = TRUE) +
  geom_line(aes(y = failure_rate_fdic, color = "FDIC member banks"), na.rm = TRUE) +
  geom_vline(xintercept = policy_lines, linetype = "dashed", color = "grey70") +
  # *** FIX: Removed family = "Avenir" ***
  geom_text(data = policy_labels, aes(x = year, y = y_pos, label = label),
            angle = 90, vjust = -0.5, hjust = 0, size = 3) +
  scale_color_manual(values = c("National banks" = "black", "FDIC member banks" = "blue"),
                     guide = guide_legend(override.aes = list(linetype = 1, shape = NA))) +
  scale_x_continuous(breaks = seq(1860, 2020, 10)) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1.0)) +
  labs(
    y = "% Failed banks / # banks",
    x = "",
    color = NULL
  ) +
  # *** FIX: Removed base_family = "Avenir" ***
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(file.path(figures_dir, "03_failures_across_time_rate_pres.pdf"), plot3, width = 10, height = 6)
message("Saved: 03_failures_across_time_rate_pres.pdf")

message("Script 21 (plot failures) completed successfully.")
