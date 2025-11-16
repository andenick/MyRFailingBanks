# ===========================================================================
# Script 61: Deposit/Asset Growth Right Before Failure
# ===========================================================================
# This script analyzes deposit and asset growth in the period between the
# last call report and failure. Creates visualizations and summary tables
# comparing pre-FDIC and post-FDIC eras.
#
# Key outputs:
# - Bar charts of mean growth by era
# - Kernel density plots comparing distributions
# - Summary tables of deposit/asset outflow categories
#
# v2.5 enhancements:
# - Verbose console diagnostics throughout
# - Detailed progress tracking
# ===========================================================================

cat("===========================================================================\n")
cat("SCRIPT 61: DEPOSITS/ASSETS BEFORE FAILURE\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
script_start_time <- Sys.time()

# --- Load Required Libraries ---
cat("\n[Loading Libraries]\n")
suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(ggplot2)
  library(haven)
})
cat("  ✓ All libraries loaded successfully\n")

# --- Define Paths ---
sources_dir <- here::here("sources")
dataclean_dir <- here::here("dataclean")
tempfiles_dir <- here::here("tempfiles")
output_dir <- here::here("output")

cat(sprintf("\n[Paths]\n"))
cat(sprintf("  Sources:   %s\n", sources_dir))
cat(sprintf("  Dataclean: %s\n", dataclean_dir))
cat(sprintf("  Tempfiles: %s\n", tempfiles_dir))
cat(sprintf("  Output:    %s\n", output_dir))

# ===========================================================================
# PART 1: LOAD AND PREPARE DATA
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 1: DATA LOADING AND PREPARATION\n")
cat("===========================================================================\n")

# Load historical data
cat("\n[Loading Historical Data]\n")
# Try .rds first, then .dta (Script 06 creates .dta files)
hist_file_rds <- file.path(dataclean_dir, "deposits_before_failure_historical.rds")
hist_file_dta <- file.path(dataclean_dir, "deposits_before_failure_historical.dta")

if (file.exists(hist_file_rds)) {
  data_hist <- readRDS(hist_file_rds)
  cat(sprintf("  Historical data loaded from .rds: %d observations\n", nrow(data_hist)))
} else if (file.exists(hist_file_dta)) {
  data_hist <- haven::read_dta(hist_file_dta)
  cat(sprintf("  Historical data loaded from .dta: %d observations\n", nrow(data_hist)))
} else {
  cat("  ⚠ WARNING: Historical data not found (tried .rds and .dta)\n")
  data_hist <- data.frame()
}

# Load modern data
cat("\n[Loading Modern Data]\n")
# Try .rds first, then .dta (Script 06 creates .dta files)
mod_file_rds <- file.path(dataclean_dir, "deposits_before_failure_modern.rds")
mod_file_dta <- file.path(dataclean_dir, "deposits_before_failure_modern.dta")

if (file.exists(mod_file_rds)) {
  data_mod <- readRDS(mod_file_rds)
  cat(sprintf("  Modern data loaded from .rds: %d observations\n", nrow(data_mod)))
} else if (file.exists(mod_file_dta)) {
  data_mod <- haven::read_dta(mod_file_dta)
  cat(sprintf("  Modern data loaded from .dta: %d observations\n", nrow(data_mod)))
} else {
  cat("  ⚠ WARNING: Modern data not found (tried .rds and .dta)\n")
  data_mod <- data.frame()
}

# Combine datasets
cat("\n[Combining Historical and Modern Data]\n")

if (nrow(data_hist) > 0 || nrow(data_mod) > 0) {
  data_all <- bind_rows(data_hist, data_mod)
} else {
  cat("  ⚠ ERROR: No data available, cannot proceed\n")
  cat("  Exiting script\n")
  quit(save = "no")
}

# Filter to relevant periods
data_all <- data_all %>%
  filter((year <= 1934) | (year >= 1959))

cat(sprintf("  Combined data: %d observations\n", nrow(data_all)))
cat(sprintf("  Years: %d to %d\n", min(data_all$year, na.rm = TRUE),
            max(data_all$year, na.rm = TRUE)))

# Create era indicators
cat("\n[Creating Era Indicators]\n")

data_all <- data_all %>%
  mutate(
    # Pre/Post FDIC indicator
    pre_fdic = ifelse(year <= 1934, 0, 1),
    pre_fdic_label = ifelse(year <= 1934, "1865-1934", "1993-2024"),

    # Detailed era classification
    era = case_when(
      receivership_date >= as.Date("1863-01-01") &
        receivership_date < as.Date("1914-01-01") ~ 1,
      receivership_date >= as.Date("1914-01-01") &
        receivership_date <= as.Date("1928-12-31") ~ 2,
      receivership_date >= as.Date("1929-01-01") &
        receivership_date <= as.Date("1933-03-06") ~ 3,
      receivership_date >= as.Date("1933-02-01") &
        receivership_date <= as.Date("1935-01-01") ~ 4,
      final_year >= 1984 & final_year <= 2006 ~ 5,
      final_year >= 2007 & final_year <= 2024 ~ 6,
      TRUE ~ NA_real_
    ),
    era_label = factor(era,
      levels = 1:6,
      labels = c("1880-1913 (NB Era)",
                 "1914-1918 (Early Fed)",
                 "1929-1933 (Depression, pre-Holiday)",
                 "1933-1934 (Depression, post-Holiday)",
                 "1993-2006",
                 "2007-2024")
    )
  )

cat("  ✓ Era indicators created\n")

# ===========================================================================
# PART 2: VISUALIZATIONS - MEAN GROWTH
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 2: BAR CHARTS OF MEAN GROWTH\n")
cat("===========================================================================\n")

# Figure 1: Deposit growth by pre/post FDIC
cat("\n[Figure 1: Deposit Growth (Pre/Post FDIC)]\n")

mean_deposits_pre_post <- data_all %>%
  filter(!is.na(growth_deposits)) %>%
  group_by(pre_fdic_label) %>%
  summarise(mean_growth = mean(growth_deposits, na.rm = TRUE), .groups = "drop")

plot_deposits_pre_post <- ggplot(mean_deposits_pre_post,
                                   aes(x = pre_fdic_label, y = mean_growth)) +
  geom_col(fill = "steelblue") +
  labs(
    title = "Deposit Growth Between Last Call and Failure",
    x = NULL,
    y = "Deposit growth (%)"
  ) +
  theme_minimal()

ggsave(
  file.path(output_dir, "Figures", "04_deposits_before_failure.pdf"),
  plot = plot_deposits_pre_post,
  width = 6,
  height = 5
)

cat("  ✓ Saved: Figures/04_deposits_before_failure.pdf\n")

# Figure 2: Asset growth by pre/post FDIC
cat("\n[Figure 2: Asset Growth (Pre/Post FDIC)]\n")

mean_assets_pre_post <- data_all %>%
  filter(!is.na(growth_assets)) %>%
  group_by(pre_fdic_label) %>%
  summarise(mean_growth = mean(growth_assets, na.rm = TRUE), .groups = "drop")

plot_assets_pre_post <- ggplot(mean_assets_pre_post,
                                 aes(x = pre_fdic_label, y = mean_growth)) +
  geom_col(fill = "darkgreen") +
  labs(
    title = "Asset Growth Between Last Call and Failure",
    x = NULL,
    y = "Asset growth (%)"
  ) +
  theme_minimal()

ggsave(
  file.path(output_dir, "Figures", "04_assets_before_failure.pdf"),
  plot = plot_assets_pre_post,
  width = 6,
  height = 5
)

cat("  ✓ Saved: Figures/04_assets_before_failure.pdf\n")

# Figure 3: Deposit growth by detailed era
cat("\n[Figure 3: Deposit Growth by Era]\n")

mean_deposits_era <- data_all %>%
  filter(!is.na(growth_deposits), !is.na(era)) %>%
  group_by(era_label) %>%
  summarise(mean_growth = mean(growth_deposits, na.rm = TRUE), .groups = "drop")

plot_deposits_era <- ggplot(mean_deposits_era,
                             aes(x = era_label, y = mean_growth)) +
  geom_col(fill = "steelblue") +
  labs(
    title = "Deposit Growth by Era",
    x = NULL,
    y = "Deposit growth between last call and failure (%)"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(
  file.path(output_dir, "Figures", "04_deposits_before_failure_by_era.pdf"),
  plot = plot_deposits_era,
  width = 10,
  height = 6
)

cat("  ✓ Saved: Figures/04_deposits_before_failure_by_era.pdf\n")

# ===========================================================================
# PART 3: KERNEL DENSITY PLOTS
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 3: KERNEL DENSITY PLOTS\n")
cat("===========================================================================\n")

# Figure 4: Kernel density - Pre/Post FDIC
cat("\n[Figure 4: Deposit Growth Density (Pre/Post FDIC)]\n")

data_density <- data_all %>%
  filter(!is.na(growth_deposits),
         growth_deposits >= -75,
         growth_deposits <= 50,
         !is.na(era))

plot_density_pre_post <- ggplot(data_density,
                                  aes(x = growth_deposits, color = pre_fdic_label)) +
  geom_density(linewidth = 1, alpha = 0.7) +
  scale_color_manual(values = c("1865-1934" = "black", "1993-2024" = "blue")) +
  labs(
    title = "Distribution of Deposit Growth Before Failure",
    x = "Deposit growth between last call report and failure (%)",
    y = "Density",
    color = "Era"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(
  file.path(output_dir, "Figures", "04_deposits_before_failure_by_era_kdensity.pdf"),
  plot = plot_density_pre_post,
  width = 8,
  height = 6
)

cat("  ✓ Saved: Figures/04_deposits_before_failure_by_era_kdensity.pdf\n")

# Figure 5: Kernel density - Detailed eras
cat("\n[Figure 5: Deposit Growth Density by Detailed Era]\n")

plot_density_detailed <- ggplot(data_density,
                                 aes(x = growth_deposits, color = era_label)) +
  geom_density(linewidth = 1, alpha = 0.7) +
  labs(
    title = "Distribution of Deposit Growth by Era",
    x = "Deposit growth between last call report and failure (%)",
    y = "Density",
    color = "Era"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom", legend.direction = "vertical")

ggsave(
  file.path(output_dir, "Figures", "04_deposits_before_failure_by_era_kdensity_detail.pdf"),
  plot = plot_density_detailed,
  width = 10,
  height = 7
)

cat("  ✓ Saved: Figures/04_deposits_before_failure_by_era_kdensity_detail.pdf\n")

# ===========================================================================
# PART 4: OUTFLOW CATEGORY TABLES
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 4: DEPOSIT/ASSET OUTFLOW CATEGORY TABLES\n")
cat("===========================================================================\n")

# Create outflow categories for deposits
cat("\n[Creating Deposit Outflow Categories]\n")

data_outflows <- data_all %>%
  filter(!is.na(growth_deposits)) %>%
  mutate(
    outflows_cat1 = growth_deposits < -30,
    outflows_cat2 = growth_deposits >= -30 & growth_deposits < -20,
    outflows_cat3 = growth_deposits >= -20 & growth_deposits < -7.5,
    outflows_cat4 = growth_deposits >= -7.5 & growth_deposits < -2.5,
    outflows_cat5 = growth_deposits >= -2.5 & growth_deposits < 0,
    outflows_cat6 = growth_deposits >= 0
  )

# Summary by pre/post FDIC
summary_deposits_general <- data_outflows %>%
  mutate(era_simple = ifelse(year < 1935, "1880-1934 (Pre-FDIC)", "1993-2024 (Post-FDIC)")) %>%
  group_by(era_simple) %>%
  summarise(
    mean_growth = mean(growth_deposits, na.rm = TRUE),
    median_growth = median(growth_deposits, na.rm = TRUE),
    cat1 = mean(outflows_cat1, na.rm = TRUE),
    cat2 = mean(outflows_cat2, na.rm = TRUE),
    cat3 = mean(outflows_cat3, na.rm = TRUE),
    cat4 = mean(outflows_cat4, na.rm = TRUE),
    cat5 = mean(outflows_cat5, na.rm = TRUE),
    cat6 = mean(outflows_cat6, na.rm = TRUE),
    n_banks = n(),
    .groups = "drop"
  )

print(summary_deposits_general)

saveRDS(summary_deposits_general, file.path(tempfiles_dir, "deposit_outflows_general.rds"))
write_dta(summary_deposits_general, file.path(tempfiles_dir, "deposit_outflows_general.dta"))

cat("  ✓ Saved: deposit_outflows_general.rds/.dta\n")

# Summary by detailed era
summary_deposits_era <- data_outflows %>%
  filter(!is.na(era)) %>%
  group_by(era_label) %>%
  summarise(
    mean_growth = mean(growth_deposits, na.rm = TRUE),
    median_growth = median(growth_deposits, na.rm = TRUE),
    cat1 = mean(outflows_cat1, na.rm = TRUE),
    cat2 = mean(outflows_cat2, na.rm = TRUE),
    cat3 = mean(outflows_cat3, na.rm = TRUE),
    cat4 = mean(outflows_cat4, na.rm = TRUE),
    cat5 = mean(outflows_cat5, na.rm = TRUE),
    cat6 = mean(outflows_cat6, na.rm = TRUE),
    n_banks = n(),
    .groups = "drop"
  )

print(summary_deposits_era)

saveRDS(summary_deposits_era, file.path(tempfiles_dir, "deposit_outflows.rds"))
write_dta(summary_deposits_era, file.path(tempfiles_dir, "deposit_outflows.dta"))

cat("  ✓ Saved: deposit_outflows.rds/.dta\n")

# Asset outflow categories
cat("\n[Creating Asset Outflow Categories]\n")

data_asset_outflows <- data_all %>%
  filter(!is.na(growth_assets)) %>%
  mutate(
    outflows_cat1 = growth_assets < -30,
    outflows_cat2 = growth_assets >= -30 & growth_assets < -20,
    outflows_cat3 = growth_assets >= -20 & growth_assets < -7.5,
    outflows_cat4 = growth_assets >= -7.5 & growth_assets < -2.5,
    outflows_cat5 = growth_assets >= -2.5 & growth_assets < 0,
    outflows_cat6 = growth_assets >= 0
  )

# Summary by pre/post FDIC
summary_assets_general <- data_asset_outflows %>%
  mutate(era_simple = ifelse(year < 1935, "1880-1934 (Pre-FDIC)", "1993-2024 (Post-FDIC)")) %>%
  group_by(era_simple) %>%
  summarise(
    mean_growth = mean(growth_assets, na.rm = TRUE),
    median_growth = median(growth_assets, na.rm = TRUE),
    cat1 = mean(outflows_cat1, na.rm = TRUE),
    cat2 = mean(outflows_cat2, na.rm = TRUE),
    cat3 = mean(outflows_cat3, na.rm = TRUE),
    cat4 = mean(outflows_cat4, na.rm = TRUE),
    cat5 = mean(outflows_cat5, na.rm = TRUE),
    cat6 = mean(outflows_cat6, na.rm = TRUE),
    n_banks = n(),
    .groups = "drop"
  )

print(summary_assets_general)

saveRDS(summary_assets_general, file.path(tempfiles_dir, "assets_outflows_general.rds"))
write_dta(summary_assets_general, file.path(tempfiles_dir, "assets_outflows_general.dta"))

cat("  ✓ Saved: assets_outflows_general.rds/.dta\n")

# Figure 6: Asset growth by era
cat("\n[Figure 6: Asset Growth by Era]\n")

mean_assets_era <- data_all %>%
  filter(!is.na(growth_assets), !is.na(era)) %>%
  group_by(era_label) %>%
  summarise(mean_growth = mean(growth_assets, na.rm = TRUE), .groups = "drop")

plot_assets_era <- ggplot(mean_assets_era,
                           aes(x = era_label, y = mean_growth)) +
  geom_col(fill = "darkgreen") +
  labs(
    title = "Asset Growth by Era",
    x = NULL,
    y = "Asset growth between last call and failure (%)"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(
  file.path(output_dir, "Figures", "04_assets_before_failure_by_era.pdf"),
  plot = plot_assets_era,
  width = 10,
  height = 6
)

cat("  ✓ Saved: Figures/04_assets_before_failure_by_era.pdf\n")

# ===========================================================================
# PART 5: FINAL SUMMARY AND COMPLETION
# ===========================================================================

cat("\n===========================================================================\n")
cat("FINAL SUMMARY\n")
cat("===========================================================================\n")

script_end_time <- Sys.time()
script_duration <- as.numeric(difftime(script_end_time, script_start_time,
                                      units = "mins"))

cat("\n[Figures Created]\n")
cat("  ✓ Deposit growth (pre/post FDIC)\n")
cat("  ✓ Asset growth (pre/post FDIC)\n")
cat("  ✓ Deposit growth by era\n")
cat("  ✓ Deposit density (pre/post FDIC)\n")
cat("  ✓ Deposit density by detailed era\n")
cat("  ✓ Asset growth by era\n")
cat("\n  Total: 6 figures\n")

cat("\n[Tables Created]\n")
cat("  ✓ Deposit outflow categories (general)\n")
cat("  ✓ Deposit outflow categories (by era)\n")
cat("  ✓ Asset outflow categories (general)\n")
cat("\n  Total: 3 tables\n")

cat("\n===========================================================================\n")
cat("SCRIPT 61 COMPLETED SUCCESSFULLY\n")
cat(sprintf("  End time: %s\n", Sys.time()))
cat(sprintf("  Runtime: %.1f minutes\n", script_duration))
cat("===========================================================================\n")
