# ===========================================================================
# Cause of Failures Figures
# ===========================================================================

source(here::here("code", "00_setup.R"))
source(here::here("code", "00_helper_functions.R"))

print_section("85 - Causes of Failure Analysis")

# --------------------------------------------------------------------------
# Load Data
# --------------------------------------------------------------------------

cat("Loading receivership dataset...\n")
df <- readRDS(here::here("tempfiles", "receivership_dataset_tmp.rds"))

cat(sprintf("  Loaded %d receiverships\n", nrow(df)))
cat(sprintf("  Unique banks: %d\n", length(unique(df$charter))))
# Use charter.x which is the actual column name
if ("charter.x" %in% names(df)) {
  df$charter <- df$charter.x
}

# --------------------------------------------------------------------------
# Figure 1 - Causes of Bank Failures as Classified by the OCC, 1863-1937
# --------------------------------------------------------------------------

print_header("Creating bar chart of failure causes")

# Encode the simplified cause of failure variable
df_causes <- df %>%
  filter(!is.na(simplified_cause_of_failure)) %>%
  mutate(
    # Create numeric encoding for cause
    cause = case_when(
      simplified_cause_of_failure == "Economic conditions" ~ 1,
      simplified_cause_of_failure == "Excessive lending" ~ 2,
      simplified_cause_of_failure == "Fraud" ~ 3,
      simplified_cause_of_failure == "Governance" ~ 4,
      simplified_cause_of_failure == "Losses" ~ 5,
      simplified_cause_of_failure == "No information" ~ 6,
      simplified_cause_of_failure == "Other" ~ 7,
      simplified_cause_of_failure == "Run" ~ 8,
      TRUE ~ NA_real_
    )
  )

# Get maximum cause per bank (one observation per bank)
df_causes <- df_causes %>%
  group_by(charter) %>%
  mutate(cause_of_failure = max(cause, na.rm = TRUE)) %>%
  ungroup() %>%
  mutate(
    cause_of_failure = ifelse(is.infinite(cause_of_failure), NA, cause_of_failure),
    # Set "No information" to NA
    cause_of_failure = ifelse(cause_of_failure == 6, NA, cause_of_failure)
  )

# Create factor with proper labels
df_causes <- df_causes %>%
  mutate(
    cause_label = factor(
      cause_of_failure,
      levels = c(1, 5, 3, 4, 2, 8, 7),
      labels = c("Economic\nconditions", "Losses", "Fraud", "Governance",
                 "Excessive\nlending", "Run", "Other")
    ),
    # Order for sorting
    order = case_when(
      cause_of_failure == 1 ~ 1,
      cause_of_failure == 5 ~ 2,
      cause_of_failure == 3 ~ 3,
      cause_of_failure == 4 ~ 4,
      cause_of_failure == 2 ~ 5,
      cause_of_failure == 8 ~ 6,
      cause_of_failure == 7 ~ 7,
      TRUE ~ NA_real_
    )
  )

# Calculate percentages for each cause
cause_summary <- df_causes %>%
  filter(!is.na(cause_label)) %>%
  group_by(cause_label, order) %>%
  summarise(n = n(), .groups = "drop") %>%
  mutate(
    total = sum(n),
    percent = 100 * n / total
  ) %>%
  arrange(order)

cat(sprintf("  Classified failures: %d\n", sum(cause_summary$n)))
cat("  Breakdown by cause:\n")
for (i in 1:nrow(cause_summary)) {
  cat(sprintf("    %s: %.1f%%\n",
              gsub("\n", " ", cause_summary$cause_label[i]),
              cause_summary$percent[i]))
}

# Create bar chart
p1 <- ggplot(cause_summary, aes(x = reorder(cause_label, order), y = percent)) +
  geom_col(fill = "steelblue", alpha = 0.8) +
  labs(
    x = NULL,
    y = "Percent of failures between 1865-1937"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    axis.text.x = element_text(size = 10),
    panel.grid.major.x = element_blank()
  ) +
  scale_y_continuous(expand = c(0, 0), limits = c(0, max(cause_summary$percent) * 1.1))

ggsave(
  here::here("output", "figures", "04_pre_war_causes_bar_chart.pdf"),
  plot = p1,
  width = 12, height = 6
)

cat("  Saved: 04_pre_war_causes_bar_chart.pdf\n")

# --------------------------------------------------------------------------
# Figure 2 - Share of failures not classified by year
# --------------------------------------------------------------------------

print_header("Creating time series of classification completeness")

# Filter pre-1938 data and create classification indicator
df_timeseries <- df %>%
  filter(year < 1938) %>%
  mutate(
    cause = case_when(
      simplified_cause_of_failure == "Economic conditions" ~ 1,
      simplified_cause_of_failure == "Excessive lending" ~ 2,
      simplified_cause_of_failure == "Fraud" ~ 3,
      simplified_cause_of_failure == "Governance" ~ 4,
      simplified_cause_of_failure == "Losses" ~ 5,
      simplified_cause_of_failure == "No information" ~ 6,
      simplified_cause_of_failure == "Other" ~ 7,
      simplified_cause_of_failure == "Run" ~ 8,
      TRUE ~ NA_real_
    )
  )

# Get maximum cause per bank
df_timeseries <- df_timeseries %>%
  group_by(charter) %>%
  mutate(
    cause_of_failure = max(cause, na.rm = TRUE),
    cause_of_failure = ifelse(is.infinite(cause_of_failure), NA, cause_of_failure)
  ) %>%
  ungroup() %>%
  mutate(
    not_classified = is.na(cause_of_failure),
    # Use receivership year, not last call year
    year_fail = year(receivership_date)
  )

# Aggregate by year
year_summary <- df_timeseries %>%
  filter(!is.na(year_fail), year_fail < 1936) %>%
  group_by(year_fail) %>%
  summarise(
    total_failures = n(),
    not_classified = sum(not_classified, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    ratio = not_classified / total_failures
  )

cat(sprintf("  Years covered: %d-%d\n", min(year_summary$year_fail), max(year_summary$year_fail)))
cat(sprintf("  Average share not classified: %.1f%%\n", mean(year_summary$ratio) * 100))

# Create time series plot
p2 <- ggplot(year_summary, aes(x = year_fail)) +
  geom_line(aes(y = ratio), color = "darkblue", size = 0.8) +
  geom_line(aes(y = total_failures / max(total_failures)),
            color = "grey60", size = 0.8, linetype = "solid") +
  geom_vline(xintercept = c(1873, 1893, 1907, 1929),
             linetype = "solid", color = "grey70", size = 0.3) +
  annotate("text", x = 1873, y = 1, label = "Panic of 1873",
           hjust = 1.05, vjust = -0.5, size = 2.5, angle = 90) +
  annotate("text", x = 1893, y = 1, label = "Panic of 1893",
           hjust = 1.05, vjust = -0.5, size = 2.5, angle = 90) +
  annotate("text", x = 1907, y = 1, label = "Panic of 1907",
           hjust = 1.05, vjust = -0.5, size = 2.5, angle = 90) +
  annotate("text", x = 1929, y = 1, label = "Great Depression",
           hjust = 1.05, vjust = -0.5, size = 2.5, angle = 90) +
  scale_y_continuous(
    name = "Share of failed banks with failure not classified",
    labels = scales::percent_format(accuracy = 1),
    sec.axis = sec_axis(
      ~ . * max(year_summary$total_failures),
      name = "Number of failed national banks"
    )
  ) +
  labs(x = NULL) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    panel.grid.minor = element_blank()
  )

ggsave(
  here::here("output", "figures", "99_classification_failure_reasons.pdf"),
  plot = p2,
  width = 10, height = 6
)

cat("  Saved: 99_classification_failure_reasons.pdf\n")

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------

print_complete("85_causes_of_failure.R")

cat("\nOutputs created:\n")
cat("  - output/figures/04_pre_war_causes_bar_chart.pdf\n")
cat("  - output/figures/99_classification_failure_reasons.pdf\n")
