# ===========================================================================
# Script 32: Probability of Failure in the Cross Section
# ===========================================================================
# This script creates visualizations of failure probability across different
# quintiles of growth, solvency, funding, and profitability measures.
#
# Outputs:
# - Probability of failure by growth quintile (all periods, pre-1935, post-1945)
# - Probability of failure by solvency quintile (pre-1935)
# - Probability of failure by noncore funding (pre-1935, post-1945)
# - Probability of failure by income quintile (post-1945)
#
# v2.5 enhancements:
# - Verbose console diagnostics throughout
# - Detailed progress tracking
# ===========================================================================

cat("===========================================================================\n")
cat("SCRIPT 32: PROBABILITY OF FAILURE IN THE CROSS SECTION\n")
cat("===========================================================================\n")
cat(sprintf("Start time: %s\n", Sys.time()))
script_start_time <- Sys.time()

# --- Load Required Libraries ---
cat("\n[Loading Libraries]\n")
suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(ggplot2)
  library(tidyr)
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

cat("\nLoading combined-data.rds...\n")
data_full <- readRDS(file.path(dataclean_dir, "combined-data.rds"))

cat(sprintf("  Loaded: %d observations\n", nrow(data_full)))
cat(sprintf("  Banks: %d\n", n_distinct(data_full$bank_id, na.rm = TRUE)))
cat(sprintf("  Years: %d to %d\n", min(data_full$year, na.rm = TRUE),
            max(data_full$year, na.rm = TRUE)))

# Create failure indicators
cat("\n[Creating Failure Indicators]\n")

data_full <- data_full %>%
  mutate(
    F1_failure = 100 * (quarters_to_failure >= -4 & quarters_to_failure <= -1),
    F2_failure = 100 * (quarters_to_failure >= -8 & quarters_to_failure <= -1),
    F3_failure = 100 * (quarters_to_failure >= -12 & quarters_to_failure <= -1),
    F4_failure = 100 * (quarters_to_failure >= -16 & quarters_to_failure <= -1),
    F5_failure = 100 * (quarters_to_failure >= -20 & quarters_to_failure <= -1),
    F6_failure = 100 * (quarters_to_failure >= -24 & quarters_to_failure <= -1)
  )

# Replace NA with 0 for non-failed banks
# CRITICAL: Use specific pattern to match only F1-F6_failure, not fail_day or other F* columns
data_full <- data_full %>%
  mutate(across(matches("^F[0-9]_failure$"), ~replace_na(., 0)))

cat("  ✓ Created F1-F6 failure indicators\n")

# Keep last observation per bank-year (annual data)
cat("\n[Keeping Annual Data]\n")

data_annual <- data_full %>%
  group_by(bank_id, year) %>%
  arrange(quarter) %>%
  slice_tail(n = 1) %>%
  ungroup()

cat(sprintf("  Annual observations: %d\n", nrow(data_annual)))

# Create growth variable and quintiles
cat("\n[Creating Growth Quintiles]\n")

data_annual <- data_annual %>%
  arrange(bank_id, year) %>%
  group_by(bank_id) %>%
  mutate(
    assets_lag3 = lag(assets, 3),
    growth = ifelse(!is.na(assets) & !is.na(assets_lag3),
                    log(assets) - log(assets_lag3), NA)
  ) %>%
  ungroup() %>%
  group_by(year) %>%
  mutate(growth_cat = ntile(growth, 5)) %>%
  ungroup()

cat(sprintf("  Growth variable created: %d non-NA\n",
            sum(!is.na(data_annual$growth))))
cat(sprintf("  Growth quintiles: %d obs with category\n",
            sum(!is.na(data_annual$growth_cat))))

# ===========================================================================
# PART 2: PROBABILITY OF FAILURE BY GROWTH - ALL PERIODS
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 2: FAILURE PROBABILITY BY GROWTH QUINTILE - ALL PERIODS\n")
cat("===========================================================================\n")

cat("\n[Calculating Probabilities by Growth Quintile]\n")

prob_growth_all <- data_annual %>%
  filter(!is.na(growth_cat)) %>%
  group_by(growth_cat) %>%
  summarise(
    F1_failure = mean(F1_failure, na.rm = TRUE),
    F2_failure = mean(F2_failure, na.rm = TRUE),
    F3_failure = mean(F3_failure, na.rm = TRUE),
    F4_failure = mean(F4_failure, na.rm = TRUE),
    F5_failure = mean(F5_failure, na.rm = TRUE),
    F6_failure = mean(F6_failure, na.rm = TRUE),
    .groups = "drop"
  )

print(prob_growth_all)

cat("\n[Creating Plot: All Periods]\n")

plot_data <- prob_growth_all %>%
  pivot_longer(cols = starts_with("F"), names_to = "horizon", values_to = "probability") %>%
  mutate(horizon = factor(horizon, levels = paste0("F", 1:6),
                          labels = paste0("h=", 1:6)))

plot_growth_all <- ggplot(plot_data, aes(x = growth_cat, y = probability,
                                          color = horizon, group = horizon)) +
  geom_line(alpha = 0.7) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 1:5, labels = paste0("Q", 1:5)) +
  scale_color_manual(values = c("h=1" = "black", "h=2" = "gray50",
                                 "h=3" = "gray60", "h=4" = "gray70",
                                 "h=5" = "gray80", "h=6" = "gold")) +
  labs(
    title = "Probability of Failure by 3-Year Asset Growth",
    x = "Quintile of 3-year Asset Growth distribution",
    y = "Probability of Failure between t and t+h (in ppt)",
    color = "Horizon"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(
  file.path(output_dir, "Figures", "04_prob_failure_growth_all.pdf"),
  plot = plot_growth_all,
  width = 8,
  height = 6
)

cat("  ✓ Saved: Figures/04_prob_failure_growth_all.pdf\n")

# ===========================================================================
# PART 3: PROBABILITY BY GROWTH - PRE-1935
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 3: FAILURE PROBABILITY BY GROWTH - PRE-1935\n")
cat("===========================================================================\n")

cat("\n[Calculating Probabilities: Pre-1935]\n")

prob_growth_pre <- data_annual %>%
  filter(year < 1935, !is.na(growth_cat)) %>%
  group_by(growth_cat) %>%
  summarise(
    F1_failure = mean(F1_failure, na.rm = TRUE),
    F2_failure = mean(F2_failure, na.rm = TRUE),
    F3_failure = mean(F3_failure, na.rm = TRUE),
    F4_failure = mean(F4_failure, na.rm = TRUE),
    F5_failure = mean(F5_failure, na.rm = TRUE),
    F6_failure = mean(F6_failure, na.rm = TRUE),
    .groups = "drop"
  )

print(prob_growth_pre)

plot_data_pre <- prob_growth_pre %>%
  pivot_longer(cols = starts_with("F"), names_to = "horizon", values_to = "probability") %>%
  mutate(horizon = factor(horizon, levels = paste0("F", 1:6),
                          labels = paste0("h=", 1:6)))

plot_growth_pre <- ggplot(plot_data_pre, aes(x = growth_cat, y = probability,
                                              color = horizon, group = horizon)) +
  geom_line(alpha = 0.7) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 1:5, labels = paste0("Q", 1:5)) +
  scale_color_manual(values = c("h=1" = "black", "h=2" = "gray50",
                                 "h=3" = "gray60", "h=4" = "gray70",
                                 "h=5" = "gray80", "h=6" = "gold")) +
  labs(
    title = "Probability of Failure by Growth (Pre-1935)",
    x = "Quintile of 3-year Asset Growth distribution",
    y = "Probability of Failure between t and t+h (in ppt)",
    color = "Horizon"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(
  file.path(output_dir, "Figures", "04_prob_failure_growth_pre.pdf"),
  plot = plot_growth_pre,
  width = 8,
  height = 6
)

cat("  ✓ Saved: Figures/04_prob_failure_growth_pre.pdf\n")

# ===========================================================================
# PART 4: PROBABILITY BY GROWTH - POST-1945
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 4: FAILURE PROBABILITY BY GROWTH - POST-1945\n")
cat("===========================================================================\n")

cat("\n[Calculating Probabilities: Post-1945]\n")

prob_growth_post <- data_annual %>%
  filter(year > 1945, !is.na(growth_cat)) %>%
  group_by(growth_cat) %>%
  summarise(
    F1_failure = mean(F1_failure, na.rm = TRUE),
    F2_failure = mean(F2_failure, na.rm = TRUE),
    F3_failure = mean(F3_failure, na.rm = TRUE),
    F4_failure = mean(F4_failure, na.rm = TRUE),
    F5_failure = mean(F5_failure, na.rm = TRUE),
    F6_failure = mean(F6_failure, na.rm = TRUE),
    .groups = "drop"
  )

print(prob_growth_post)

plot_data_post <- prob_growth_post %>%
  pivot_longer(cols = starts_with("F"), names_to = "horizon", values_to = "probability") %>%
  mutate(horizon = factor(horizon, levels = paste0("F", 1:6),
                          labels = paste0("h=", 1:6)))

plot_growth_post <- ggplot(plot_data_post, aes(x = growth_cat, y = probability,
                                                color = horizon, group = horizon)) +
  geom_line(alpha = 0.7) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 1:5, labels = paste0("Q", 1:5)) +
  scale_color_manual(values = c("h=1" = "black", "h=2" = "gray50",
                                 "h=3" = "gray60", "h=4" = "gray70",
                                 "h=5" = "gray80", "h=6" = "gold")) +
  labs(
    title = "Probability of Failure by Growth (Post-1945)",
    x = "Quintile of 3-year Asset Growth distribution",
    y = "Probability of Failure between t and t+h (in ppt)",
    color = "Horizon"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(
  file.path(output_dir, "Figures", "04_prob_failure_growth_post.pdf"),
  plot = plot_growth_post,
  width = 8,
  height = 6
)

cat("  ✓ Saved: Figures/04_prob_failure_growth_post.pdf\n")

# ===========================================================================
# PART 5: PROBABILITY BY SOLVENCY - PRE-1935
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 5: FAILURE PROBABILITY BY SOLVENCY - PRE-1935\n")
cat("===========================================================================\n")

cat("\n[Creating Solvency Quintiles]\n")

data_pre1935 <- data_annual %>%
  filter(year < 1935) %>%
  group_by(year) %>%
  mutate(solvency_cat = ntile(surplus_ratio, 5)) %>%
  ungroup()

prob_solvency_pre <- data_pre1935 %>%
  filter(!is.na(solvency_cat)) %>%
  group_by(solvency_cat) %>%
  summarise(
    F1_failure = mean(F1_failure, na.rm = TRUE),
    F2_failure = mean(F2_failure, na.rm = TRUE),
    F3_failure = mean(F3_failure, na.rm = TRUE),
    F4_failure = mean(F4_failure, na.rm = TRUE),
    F5_failure = mean(F5_failure, na.rm = TRUE),
    F6_failure = mean(F6_failure, na.rm = TRUE),
    .groups = "drop"
  )

print(prob_solvency_pre)

plot_data_solv <- prob_solvency_pre %>%
  pivot_longer(cols = starts_with("F"), names_to = "horizon", values_to = "probability") %>%
  mutate(horizon = factor(horizon, levels = paste0("F", 1:6),
                          labels = c("Fail within 1 year", "Fail in 2 years",
                                     "Fail in 3 years", "Fail in 4 years",
                                     "Fail in 5 years", "Fail in 6 years")))

plot_solvency_pre <- ggplot(plot_data_solv, aes(x = solvency_cat, y = probability,
                                                 color = horizon, group = horizon)) +
  geom_line(alpha = 0.7) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 1:5, labels = paste0("Q", 1:5)) +
  labs(
    title = "Probability of Failure by Solvency (Pre-1935)",
    x = "Quintile of Surplus/Equity distribution",
    y = "Probability of Failure (in ppt)",
    color = "Horizon"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(
  file.path(output_dir, "Figures", "04_prob_failure_surplus_profit_pre.pdf"),
  plot = plot_solvency_pre,
  width = 10,
  height = 6
)

cat("  ✓ Saved: Figures/04_prob_failure_surplus_profit_pre.pdf\n")

# ===========================================================================
# PART 6: PROBABILITY BY NONCORE FUNDING - PRE-1935
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 6: FAILURE PROBABILITY BY NONCORE FUNDING - PRE-1935\n")
cat("===========================================================================\n")

cat("\n[Creating Noncore Funding Categories]\n")

data_pre1935_nc <- data_annual %>%
  filter(year < 1935) %>%
  mutate(
    noncore_cat = case_when(
      noncore_ratio == 0 ~ 1,
      noncore_ratio > 0 & noncore_ratio <= 0.05 ~ 2,
      noncore_ratio > 0.05 & noncore_ratio <= 0.075 ~ 3,
      noncore_ratio > 0.075 & noncore_ratio <= 0.15 ~ 4,
      noncore_ratio > 0.15 ~ 5,
      TRUE ~ NA_real_
    )
  )

prob_noncore_pre <- data_pre1935_nc %>%
  filter(!is.na(noncore_cat), noncore_cat > 0) %>%
  group_by(noncore_cat) %>%
  summarise(
    F1_failure = mean(F1_failure, na.rm = TRUE),
    F2_failure = mean(F2_failure, na.rm = TRUE),
    F3_failure = mean(F3_failure, na.rm = TRUE),
    F4_failure = mean(F4_failure, na.rm = TRUE),
    F5_failure = mean(F5_failure, na.rm = TRUE),
    F6_failure = mean(F6_failure, na.rm = TRUE),
    .groups = "drop"
  )

print(prob_noncore_pre)

plot_data_nc <- prob_noncore_pre %>%
  pivot_longer(cols = starts_with("F"), names_to = "horizon", values_to = "probability") %>%
  mutate(horizon = factor(horizon, levels = paste0("F", 1:6),
                          labels = c("Fail within 1 year", "Fail in 2 years",
                                     "Fail in 3 years", "Fail in 4 years",
                                     "Fail in 5 years", "Fail in 6 years")))

plot_noncore_pre <- ggplot(plot_data_nc, aes(x = noncore_cat, y = probability,
                                              color = horizon, group = horizon)) +
  geom_line(alpha = 0.7) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 1:5, labels = c("0", "0-5%", "5-7.5%", "7.5-15%", ">15%")) +
  labs(
    title = "Probability of Failure by Noncore Funding (Pre-1935)",
    x = "Noncore funding/assets",
    y = "Probability of Failure (in ppt)",
    color = "Horizon"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(
  file.path(output_dir, "Figures", "04_prob_failure_noncore_pre.pdf"),
  plot = plot_noncore_pre,
  width = 10,
  height = 6
)

cat("  ✓ Saved: Figures/04_prob_failure_noncore_pre.pdf\n")

# ===========================================================================
# PART 7: PROBABILITY BY NONCORE FUNDING - POST-1945
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 7: FAILURE PROBABILITY BY NONCORE FUNDING - POST-1945\n")
cat("===========================================================================\n")

data_post1945_nc <- data_annual %>%
  filter(year > 1945) %>%
  group_by(year) %>%
  mutate(noncore_cat = ntile(noncore_ratio, 5)) %>%
  ungroup()

prob_noncore_post <- data_post1945_nc %>%
  filter(!is.na(noncore_cat)) %>%
  group_by(noncore_cat) %>%
  summarise(
    F1_failure = mean(F1_failure, na.rm = TRUE),
    F2_failure = mean(F2_failure, na.rm = TRUE),
    F3_failure = mean(F3_failure, na.rm = TRUE),
    F4_failure = mean(F4_failure, na.rm = TRUE),
    F5_failure = mean(F5_failure, na.rm = TRUE),
    F6_failure = mean(F6_failure, na.rm = TRUE),
    .groups = "drop"
  )

print(prob_noncore_post)

plot_data_nc_post <- prob_noncore_post %>%
  pivot_longer(cols = starts_with("F"), names_to = "horizon", values_to = "probability") %>%
  mutate(horizon = factor(horizon, levels = paste0("F", 1:6),
                          labels = c("Fail within 1 year", "Fail in 2 years",
                                     "Fail in 3 years", "Fail in 4 years",
                                     "Fail in 5 years", "Fail in 6 years")))

plot_noncore_post <- ggplot(plot_data_nc_post, aes(x = noncore_cat, y = probability,
                                                    color = horizon, group = horizon)) +
  geom_line(alpha = 0.7) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 1:5, labels = paste0("Q", 1:5)) +
  labs(
    title = "Probability of Failure by Noncore Funding (Post-1945)",
    x = "Quintile of Noncore funding/Assets distribution",
    y = "Probability of Failure (in ppt)",
    color = "Horizon"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(
  file.path(output_dir, "Figures", "04_prob_failure_noncore_post.pdf"),
  plot = plot_noncore_post,
  width = 10,
  height = 6
)

cat("  ✓ Saved: Figures/04_prob_failure_noncore_post.pdf\n")

# ===========================================================================
# PART 8: PROBABILITY BY INCOME - POST-1945
# ===========================================================================

cat("\n===========================================================================\n")
cat("PART 8: FAILURE PROBABILITY BY INCOME - POST-1945\n")
cat("===========================================================================\n")

data_post1945_inc <- data_annual %>%
  filter(year > 1945) %>%
  group_by(year) %>%
  mutate(income_cat = ntile(income_ratio, 5)) %>%
  ungroup()

prob_income_post <- data_post1945_inc %>%
  filter(!is.na(income_cat)) %>%
  group_by(income_cat) %>%
  summarise(
    F1_failure = mean(F1_failure, na.rm = TRUE),
    F2_failure = mean(F2_failure, na.rm = TRUE),
    F3_failure = mean(F3_failure, na.rm = TRUE),
    F4_failure = mean(F4_failure, na.rm = TRUE),
    F5_failure = mean(F5_failure, na.rm = TRUE),
    F6_failure = mean(F6_failure, na.rm = TRUE),
    .groups = "drop"
  )

print(prob_income_post)

plot_data_inc_post <- prob_income_post %>%
  pivot_longer(cols = starts_with("F"), names_to = "horizon", values_to = "probability") %>%
  mutate(horizon = factor(horizon, levels = paste0("F", 1:6),
                          labels = c("Fail within 1 year", "Fail in 2 years",
                                     "Fail in 3 years", "Fail in 4 years",
                                     "Fail in 5 years", "Fail in 6 years")))

plot_income_post <- ggplot(plot_data_inc_post, aes(x = income_cat, y = probability,
                                                    color = horizon, group = horizon)) +
  geom_line(alpha = 0.7) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 1:5, labels = paste0("Q", 1:5)) +
  labs(
    title = "Probability of Failure by Income (Post-1945)",
    x = "Quintile of Net Income/Assets distribution",
    y = "Probability of Failure (in ppt)",
    color = "Horizon"
  ) +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(
  file.path(output_dir, "Figures", "04_prob_failure_income_post.pdf"),
  plot = plot_income_post,
  width = 10,
  height = 6
)

cat("  ✓ Saved: Figures/04_prob_failure_income_post.pdf\n")

# ===========================================================================
# PART 9: FINAL SUMMARY AND COMPLETION
# ===========================================================================

cat("\n===========================================================================\n")
cat("FINAL SUMMARY\n")
cat("===========================================================================\n")

script_end_time <- Sys.time()
script_duration <- as.numeric(difftime(script_end_time, script_start_time,
                                      units = "mins"))

cat("\n[Figures Created]\n")
cat("  ✓ Probability by growth (all periods)\n")
cat("  ✓ Probability by growth (pre-1935)\n")
cat("  ✓ Probability by growth (post-1945)\n")
cat("  ✓ Probability by solvency (pre-1935)\n")
cat("  ✓ Probability by noncore funding (pre-1935)\n")
cat("  ✓ Probability by noncore funding (post-1945)\n")
cat("  ✓ Probability by income (post-1945)\n")
cat("\n  Total: 7 figures\n")

cat("\n===========================================================================\n")
cat("SCRIPT 32 COMPLETED SUCCESSFULLY\n")
cat(sprintf("  End time: %s\n", Sys.time()))
cat(sprintf("  Runtime: %.1f minutes\n", script_duration))
cat("===========================================================================\n")
