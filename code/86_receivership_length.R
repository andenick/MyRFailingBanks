# ==============================================================================
# Receivership Length Analysis
# ==============================================================================
# Translation from: 86_receivership_length.py
# ==============================================================================

library(tidyverse)
library(haven)
library(ggplot2)
library(lubridate)

source(here::here("code", "00_setup.R"))

cat("================================================================================\n")
cat("RECEIVERSHIP LENGTH ANALYSIS\n")
cat("================================================================================\n")

# Load data
df <- readRDS(here::here("tempfiles", "receivership_dataset_tmp.rds"))
n# Calculate recovery rates if columns exist
# Create assets column if missing
if (!("assets" %in% names(df))) {
  if ("assets.x" %in% names(df)) df$assets <- df$assets.x
  else if ("assets_at_suspension" %in% names(df)) df$assets <- df$assets_at_suspension
}
if ("dividends" %in% names(df) && "deposits_at_suspension" %in% names(df)) {
  df <- df %>% mutate(
    recovery_rate = ifelse(!is.na(dividends) & !is.na(deposits_at_suspension) & deposits_at_suspension > 0,
                           (dividends / deposits_at_suspension) * 100, NA)
  )
}
if ("collected_from_assets" %in% names(df) && "assets_at_suspension" %in% names(df)) {
  df <- df %>% mutate(
    asset_recovery_rate = ifelse(!is.na(collected_from_assets) & !is.na(assets_at_suspension) & assets_at_suspension > 0,
                                  (collected_from_assets / assets_at_suspension) * 100, NA)
  )
}
cat(sprintf("Loaded %s observations\n", format(nrow(df), big.mark = ",")))

# Calculate receivership length
df <- df %>%
  filter(!is.na(receivership_date)) %>%
  mutate(
    receivership_date = as.Date(receivership_date),
    date_closed = as.Date(date_closed),
    receivership_length = as.numeric(difftime(date_closed, receivership_date, units = "days")),
    length_years = receivership_length / 365.25
  ) %>%
  filter(receivership_length > 0)  # Drop negative lengths

cat(sprintf("After filtering: %s observations\n", format(nrow(df), big.mark = ",")))

# Summary statistics
cat("\nReceivership length (years) summary:\n")
print(summary(df$length_years))

# Create categories
df <- df %>%
  mutate(
    length_cat = case_when(
      length_years < 2 ~ "< 2 years",
      length_years >= 2 & length_years < 4 ~ "2-4 years",
      length_years >= 4 & length_years < 6 ~ "4-6 years",
      length_years >= 6 & length_years < 10 ~ "6-10 years",
      length_years >= 10 ~ "10+ years"
    )
  )

# Summary by category
summary_by_cat <- df %>%
  group_by(length_cat) %>%
  summarise(
    n = n(),
    pct = n() / nrow(df) * 100,
    mean_recovery = mean(recovery_rate, na.rm = TRUE),
    .groups = "drop"
  )

print(summary_by_cat)

# Create LaTeX table
tex_table <- c(
  "\\begin{tabular}{lrr}",
  "\\hline",
  "Length Category & N & \\% \\\\",
  "\\hline",
  apply(summary_by_cat, 1, function(row) {
    sprintf("%s & %s & %.1f\\%%", row["length_cat"], row["n"], as.numeric(row["pct"]))
  }),
  "\\hline",
  "\\end{tabular}"
)

write_lines(tex_table, here::here("output", "tables", "08_receivership_length.tex"))
cat("   Saved: 08_receivership_length.tex\n")

# Time series plot
df_ts <- df %>%
  group_by(year = year(receivership_date)) %>%
  summarise(
    mean_length = mean(length_years, na.rm = TRUE),
    median_length = median(length_years, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  )

p <- ggplot(df_ts, aes(x = year, y = mean_length)) +
  geom_line(color = "blue", size = 1) +
  geom_point(aes(size = n), alpha = 0.6) +
  theme_minimal() +
  labs(
    title = "Receivership Length Across Time",
    x = "Year",
    y = "Mean Length (years)",
    size = "N Failures"
  )

ggsave(
  here::here("output", "figures", "99_receivership_length_across_time.pdf"),
  plot = p,
  width = 12,
  height = 8
)

cat("   Saved: 99_receivership_length_across_time.pdf\n")

cat("\n================================================================================\n")
cat("RECEIVERSHIP LENGTH ANALYSIS - COMPLETE\n")
cat("================================================================================\n")

