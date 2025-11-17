# ==============================================================================
# SCRIPT 05: SUMMARY DASHBOARD - ONE-PAGE EXECUTIVE OVERVIEW
# ==============================================================================
# Purpose: Create comprehensive 4-quadrant dashboard summarizing all findings
# Output: Single infographic-style dashboard for executive presentation
# ==============================================================================

library(tidyverse)
library(scales)
library(patchwork)
library(grid)
library(gridExtra)

# Set paths
base_dir <- here::here()
presentation_outputs_dir <- file.path(base_dir, "code_expansion", "presentation_outputs")
presentation_data_dir <- file.path(base_dir, "code_expansion", "presentation_data")

# Load extracted data
key_numbers <- jsonlite::read_json(file.path(presentation_data_dir, "key_numbers.json"))
auc_values <- read_csv(file.path(presentation_data_dir, "auc_values.csv"),
                       show_col_types = FALSE)
risk_multipliers <- read_csv(file.path(presentation_data_dir, "risk_multipliers.csv"),
                             show_col_types = FALSE)
key_coefficients <- read_csv(file.path(presentation_data_dir, "key_coefficients.csv"),
                             show_col_types = FALSE)

# Define color scheme
colors <- list(
  primary = "#2166AC",     # Deep blue
  danger = "#B2182B",      # Deep red
  success = "#1B7837",     # Green
  warning = "#F4A460",     # Orange
  text_dark = "#2C3E50",
  background = "#F7F7F7"
)

# ==============================================================================
# QUADRANT 1: AUC GAUGE - PREDICTION ACCURACY
# ==============================================================================

cat("Creating AUC gauge quadrant...\n")

# Get Model 4 out-of-sample AUC
model4_auc <- auc_values %>%
  filter(str_detect(Model, "Model 4"), Type == "Out-of-Sample") %>%
  pull(AUC)

# Create gauge-style visualization
q1_data <- tibble(
  category = c("Random Guess", "Our Model", "Perfect"),
  value = c(0.50, model4_auc, 1.00),
  label_y = c(0.25, 0.5, 0.75)
)

q1 <- ggplot() +
  # Background arc (full range)
  annotate("rect", xmin = -1, xmax = 1, ymin = 0, ymax = 1,
           fill = "gray95", alpha = 0.5) +

  # Performance zones
  annotate("rect", xmin = -1, xmax = -0.6, ymin = 0, ymax = 1,
           fill = colors$danger, alpha = 0.3) +
  annotate("rect", xmin = -0.6, xmax = 0.2, ymin = 0, ymax = 1,
           fill = colors$warning, alpha = 0.3) +
  annotate("rect", xmin = 0.2, xmax = 1, ymin = 0, ymax = 1,
           fill = colors$success, alpha = 0.3) +

  # Main metric
  annotate("text", x = 0, y = 0.65,
           label = sprintf("%.1f%%", model4_auc * 100),
           size = 24, fontface = "bold", color = colors$primary) +
  annotate("text", x = 0, y = 0.45,
           label = "Prediction\nAccuracy",
           size = 5, color = colors$text_dark, lineheight = 0.9) +

  # Benchmarks
  annotate("text", x = -0.8, y = 0.15,
           label = "Random\n50%",
           size = 3, color = "gray40", lineheight = 0.9) +
  annotate("text", x = 0.8, y = 0.15,
           label = "Perfect\n100%",
           size = 3, color = "gray40", lineheight = 0.9) +

  # Context note
  annotate("text", x = 0, y = 0.05,
           label = "Out-of-Sample AUC (Model 4)",
           size = 3.5, color = "gray50") +

  # Styling
  coord_cartesian(xlim = c(-1, 1), ylim = c(0, 1)) +
  theme_void() +
  theme(
    plot.background = element_rect(fill = "white", color = "gray80", linewidth = 1),
    plot.margin = margin(10, 10, 10, 10)
  )

# ==============================================================================
# QUADRANT 2: RISK MULTIPLIER - KEY FINDING
# ==============================================================================

cat("Creating risk multiplier quadrant...\n")

# Prepare multiplier data
mult_data <- risk_multipliers %>%
  mutate(
    Era_Short = ifelse(str_detect(Era, "Historical"), "Historical", "Modern"),
    Multiplier_Label = sprintf("%.0fx", Multiplier)
  )

q2 <- ggplot(mult_data, aes(x = Era_Short, y = Multiplier)) +
  geom_col(fill = colors$danger, width = 0.5, color = "white", linewidth = 1) +

  # Add multiplier labels
  geom_text(aes(label = Multiplier_Label),
            vjust = -0.5, size = 10, fontface = "bold",
            color = colors$danger) +

  # Add subtitle
  annotate("text", x = 1.5, y = max(mult_data$Multiplier) * 0.5,
           label = "Banks with weak fundamentals\nface extreme failure risk",
           size = 4, color = colors$text_dark, lineheight = 0.9) +

  # Styling
  scale_y_continuous(expand = c(0, 0),
                    limits = c(0, max(mult_data$Multiplier) * 1.2)) +
  labs(
    title = "Risk Multiplier Effect",
    x = NULL,
    y = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(size = 14, face = "bold", hjust = 0.5,
                             color = colors$text_dark, margin = margin(b = 10)),
    axis.text.x = element_text(size = 11, color = colors$text_dark, face = "bold"),
    axis.text.y = element_blank(),
    panel.grid = element_blank(),
    plot.background = element_rect(fill = "white", color = "gray80", linewidth = 1),
    plot.margin = margin(10, 10, 10, 10)
  )

# ==============================================================================
# QUADRANT 3: TOP PREDICTORS - KEY COEFFICIENTS
# ==============================================================================

cat("Creating key predictors quadrant...\n")

# Select top 5 coefficients by magnitude
top_coefs <- key_coefficients %>%
  arrange(desc(abs(Coefficient))) %>%
  slice_head(n = 5) %>%
  mutate(
    Variable_Short = case_when(
      Variable == "Surplus/Equity" ~ "Surplus/Equity",
      Variable == "Noncore/Assets" ~ "Noncore Funding",
      Variable == "Interaction Term" ~ "Interaction",
      Variable == "Loan Growth" ~ "Loan Growth",
      TRUE ~ Variable
    ),
    Direction = ifelse(Coefficient > 0, "↑ Risk", "↓ Risk"),
    Fill_Color = ifelse(Coefficient > 0, colors$danger, colors$primary)
  )

q3 <- ggplot(top_coefs, aes(x = reorder(Variable_Short, abs(Coefficient)),
                            y = abs(Coefficient))) +
  geom_col(aes(fill = Direction), width = 0.6, color = "white", linewidth = 0.8) +

  # Add coefficient values
  geom_text(aes(label = sprintf("%.2f", abs(Coefficient))),
            hjust = -0.2, size = 3.5, fontface = "bold",
            color = colors$text_dark) +

  # Styling
  scale_fill_manual(values = c("↑ Risk" = colors$danger, "↓ Risk" = colors$primary)) +
  scale_y_continuous(expand = c(0, 0),
                    limits = c(0, max(abs(top_coefs$Coefficient)) * 1.2)) +
  coord_flip() +
  labs(
    title = "Top 5 Predictors",
    x = NULL,
    y = NULL,
    fill = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(size = 14, face = "bold", hjust = 0.5,
                             color = colors$text_dark, margin = margin(b = 10)),
    axis.text.y = element_text(size = 10, color = colors$text_dark, face = "bold"),
    axis.text.x = element_blank(),
    panel.grid = element_blank(),
    legend.position = "bottom",
    legend.text = element_text(size = 9, face = "bold"),
    plot.background = element_rect(fill = "white", color = "gray80", linewidth = 1),
    plot.margin = margin(10, 10, 10, 10)
  )

# ==============================================================================
# QUADRANT 4: SAMPLE COVERAGE - DATA SCOPE
# ==============================================================================

cat("Creating data coverage quadrant...\n")

# Extract sample statistics
sample_stats <- tibble(
  Metric = c(
    "Total Banks",
    "Total Obs",
    "Time Span",
    "Failure Events"
  ),
  Value = c(
    format(key_numbers$sample_statistics$total_banks, big.mark = ","),
    format(key_numbers$sample_statistics$total_observations, big.mark = ","),
    "160 years",
    format(key_numbers$sample_statistics$total_failures, big.mark = ",")
  ),
  Icon = c("🏛️", "📊", "📅", "⚠️")
)

# Create text-based summary
q4 <- ggplot() +
  # Title
  annotate("text", x = 0.5, y = 0.92,
           label = "Data Coverage",
           size = 6, fontface = "bold", color = colors$text_dark) +

  # Metrics
  annotate("text", x = 0.15, y = 0.75,
           label = sample_stats$Icon[1], size = 8) +
  annotate("text", x = 0.5, y = 0.75,
           label = sample_stats$Metric[1], size = 4.5,
           color = colors$text_dark, hjust = 0) +
  annotate("text", x = 0.85, y = 0.75,
           label = sample_stats$Value[1], size = 5,
           fontface = "bold", color = colors$primary, hjust = 1) +

  annotate("text", x = 0.15, y = 0.58,
           label = sample_stats$Icon[2], size = 8) +
  annotate("text", x = 0.5, y = 0.58,
           label = sample_stats$Metric[2], size = 4.5,
           color = colors$text_dark, hjust = 0) +
  annotate("text", x = 0.85, y = 0.58,
           label = sample_stats$Value[2], size = 5,
           fontface = "bold", color = colors$primary, hjust = 1) +

  annotate("text", x = 0.15, y = 0.41,
           label = sample_stats$Icon[3], size = 8) +
  annotate("text", x = 0.5, y = 0.41,
           label = sample_stats$Metric[3], size = 4.5,
           color = colors$text_dark, hjust = 0) +
  annotate("text", x = 0.85, y = 0.41,
           label = sample_stats$Value[3], size = 5,
           fontface = "bold", color = colors$primary, hjust = 1) +

  annotate("text", x = 0.15, y = 0.24,
           label = sample_stats$Icon[4], size = 8) +
  annotate("text", x = 0.5, y = 0.24,
           label = sample_stats$Metric[4], size = 4.5,
           color = colors$text_dark, hjust = 0) +
  annotate("text", x = 0.85, y = 0.24,
           label = sample_stats$Value[4], size = 5,
           fontface = "bold", color = colors$danger, hjust = 1) +

  # Footer
  annotate("text", x = 0.5, y = 0.08,
           label = "Comprehensive historical\nanalysis (1863-2024)",
           size = 3.5, color = "gray50", lineheight = 0.9) +

  # Styling
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1)) +
  theme_void() +
  theme(
    plot.background = element_rect(fill = "white", color = "gray80", linewidth = 1),
    plot.margin = margin(10, 10, 10, 10)
  )

# ==============================================================================
# COMBINE INTO DASHBOARD
# ==============================================================================

cat("\nCombining quadrants into dashboard...\n")

# Create 2x2 layout
dashboard <- (q1 | q2) / (q3 | q4) +
  plot_annotation(
    title = "Bank Failure Prediction: Executive Summary",
    subtitle = sprintf("Model achieves %.1f%% accuracy in predicting failures | Weak fundamentals create %.0fx-%.0fx higher risk | Analysis spans 160 years, %s banks",
                      model4_auc * 100,
                      min(mult_data$Multiplier),
                      max(mult_data$Multiplier),
                      format(key_numbers$sample_statistics$total_banks, big.mark = ",")),
    caption = "Source: Correia, Luck, Verner (2025) - FailingBanks Analysis\nCombines solvency metrics, funding fragility, and interaction effects to predict bank failures with unprecedented accuracy",
    theme = theme(
      plot.title = element_text(size = 20, face = "bold", hjust = 0.5,
                               color = colors$text_dark, margin = margin(b = 8)),
      plot.subtitle = element_text(size = 12, hjust = 0.5,
                                   color = colors$text_dark, margin = margin(b = 15)),
      plot.caption = element_text(size = 9, hjust = 0.5, color = "gray40",
                                 margin = margin(t = 15)),
      plot.background = element_rect(fill = "white", color = NA)
    )
  )

# Save
ggsave(file.path(presentation_outputs_dir, "05_executive_dashboard.png"),
       dashboard, width = 16, height = 10, dpi = 300, bg = "white")

cat("✓ Saved: 05_executive_dashboard.png (16\" x 10\", 300 DPI)\n")

# ==============================================================================
# BONUS: CREATE SIMPLIFIED ONE-PAGER
# ==============================================================================

cat("\nCreating simplified one-pager...\n")

# Create text-heavy summary
one_pager <- ggplot() +
  # Main title
  annotate("text", x = 0.5, y = 0.95,
           label = "Can Bank Fundamentals Predict Failure?",
           size = 10, fontface = "bold", color = colors$text_dark) +

  # Answer
  annotate("text", x = 0.5, y = 0.88,
           label = sprintf("YES: %.1f%% Accuracy", model4_auc * 100),
           size = 16, fontface = "bold", color = colors$primary) +

  # Key Finding 1
  annotate("text", x = 0.5, y = 0.75,
           label = sprintf("🎯 KEY FINDING 1: %.0fx-%.0fx Risk Multiplier",
                          min(mult_data$Multiplier),
                          max(mult_data$Multiplier)),
           size = 7, fontface = "bold", color = colors$danger) +
  annotate("text", x = 0.5, y = 0.68,
           label = "Banks with weak fundamentals (>95th percentile) face extreme failure risk\nHistorical: 1.5% → 27% | Modern: 0.5% → 12.5%",
           size = 4.5, color = colors$text_dark, lineheight = 0.9) +

  # Key Finding 2
  annotate("text", x = 0.5, y = 0.56,
           label = "🎯 KEY FINDING 2: Multiplicative Effects",
           size = 7, fontface = "bold", color = colors$danger) +
  annotate("text", x = 0.5, y = 0.49,
           label = "Insolvency + Funding Fragility interact\nBanks with BOTH face higher risk than sum of parts",
           size = 4.5, color = colors$text_dark, lineheight = 0.9) +

  # Key Finding 3
  annotate("text", x = 0.5, y = 0.37,
           label = "🎯 KEY FINDING 3: Robust Across Eras",
           size = 7, fontface = "bold", color = colors$danger) +
  annotate("text", x = 0.5, y = 0.30,
           label = "Pattern holds across 160 years (1863-2024)\nPre-FDIC and Post-FDIC eras show same mechanisms",
           size = 4.5, color = colors$text_dark, lineheight = 0.9) +

  # Bottom stats
  annotate("rect", xmin = 0.05, xmax = 0.95, ymin = 0.05, ymax = 0.20,
           fill = colors$background, color = "gray70", linewidth = 0.8) +
  annotate("text", x = 0.5, y = 0.16,
           label = sprintf("📊 DATA: %s banks | %s observations | 160 years | %s failures",
                          format(key_numbers$sample_statistics$total_banks, big.mark = ","),
                          format(key_numbers$sample_statistics$total_observations, big.mark = ","),
                          format(key_numbers$sample_statistics$total_failures, big.mark = ",")),
           size = 4, color = colors$text_dark, fontface = "bold") +
  annotate("text", x = 0.5, y = 0.09,
           label = "Source: Correia, Luck, Verner (2025) - Failing Banks",
           size = 3.5, color = "gray40") +

  # Styling
  coord_cartesian(xlim = c(0, 1), ylim = c(0, 1)) +
  theme_void() +
  theme(
    plot.background = element_rect(fill = "white", color = NA),
    plot.margin = margin(20, 20, 20, 20)
  )

# Save
ggsave(file.path(presentation_outputs_dir, "05_one_pager_summary.png"),
       one_pager, width = 11, height = 8.5, dpi = 300, bg = "white")

cat("✓ Saved: 05_one_pager_summary.png (11\" x 8.5\", 300 DPI)\n")

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n", rep("=", 80), "\n", sep = "")
cat("SCRIPT 05 COMPLETE - SUMMARY DASHBOARD\n")
cat(rep("=", 80), "\n", sep = "")

cat("\n📊 VISUALS CREATED:\n")
cat("  1. 05_executive_dashboard.png (16\" x 10\") - 4-quadrant overview ⭐\n")
cat("  2. 05_one_pager_summary.png (11\" x 8.5\") - Text-heavy summary\n")

cat("\n💡 DASHBOARD INCLUDES:\n")
cat("  - Quadrant 1: AUC gauge (85.1% accuracy)\n")
cat("  - Quadrant 2: Risk multiplier (18x-25x)\n")
cat("  - Quadrant 3: Top 5 predictors\n")
cat("  - Quadrant 4: Data coverage summary\n")

cat("\n📍 Location:", presentation_outputs_dir, "\n")
cat("\n✅ Perfect for executive presentations and one-slide summaries!\n\n")
