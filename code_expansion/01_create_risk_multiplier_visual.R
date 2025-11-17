# ==============================================================================
# SCRIPT 01: RISK MULTIPLIER VISUAL - THE FLAGSHIP GRAPHIC
# ==============================================================================
# Purpose: Create stunning visual showing 18x-25x risk multiplier effect
# Output: High-impact bar chart comparing Average vs High-Risk banks
# ==============================================================================

library(tidyverse)
library(scales)
library(patchwork)

# Set paths
base_dir <- here::here()
presentation_outputs_dir <- file.path(base_dir, "code_expansion", "presentation_outputs")
dir.create(presentation_outputs_dir, recursive = TRUE, showWarnings = FALSE)

# Load extracted data
presentation_data_dir <- file.path(base_dir, "code_expansion", "presentation_data")
risk_multipliers <- read_csv(file.path(presentation_data_dir, "risk_multipliers.csv"),
                             show_col_types = FALSE)
failure_probs <- read_csv(file.path(presentation_data_dir, "failure_probabilities.csv"),
                          show_col_types = FALSE)

# ==============================================================================
# DEFINE PROFESSIONAL COLOR SCHEME
# ==============================================================================

colors <- list(
  safe = "#2166AC",        # Deep blue - low risk
  danger = "#B2182B",      # Deep red - high risk
  neutral = "#878787",     # Gray
  highlight = "#F4A460",   # Orange - for annotations
  text_dark = "#2C3E50",   # Almost black for text
  background = "#F7F7F7"   # Light gray background
)

# ==============================================================================
# VISUALIZATION 1: SIMPLE SIDE-BY-SIDE COMPARISON
# ==============================================================================

cat("Creating simple risk multiplier comparison...\n")

# Prepare data for simple comparison
simple_data <- tribble(
  ~Bank_Type, ~Era, ~Failure_Rate, ~Label_Position,
  "Average Bank", "Historical\n(1863-1934)", 0.015, 0.020,
  "High-Risk Bank", "Historical\n(1863-1934)", 0.270, 0.290,
  "Average Bank", "Modern\n(1959-2024)", 0.005, 0.010,
  "High-Risk Bank", "Modern\n(1959-2024)", 0.125, 0.140
)

# Create plot
p1 <- ggplot(simple_data, aes(x = Era, y = Failure_Rate, fill = Bank_Type)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7,
           color = "white", size = 0.8) +

  # Add value labels
  geom_text(aes(label = percent(Failure_Rate, accuracy = 0.1),
                y = Label_Position),
            position = position_dodge(width = 0.8),
            vjust = 0, size = 5, fontface = "bold",
            family = "sans") +

  # Add multiplier annotations
  annotate("text", x = 1, y = 0.32, label = "18x\nMultiplier",
           size = 6, fontface = "bold", color = colors$danger,
           family = "sans") +
  annotate("text", x = 2, y = 0.15, label = "25x\nMultiplier",
           size = 6, fontface = "bold", color = colors$danger,
           family = "sans") +

  # Styling
  scale_fill_manual(values = c("Average Bank" = colors$safe,
                               "High-Risk Bank" = colors$danger)) +
  scale_y_continuous(labels = percent_format(accuracy = 1),
                    limits = c(0, 0.35),
                    expand = c(0, 0)) +

  # Labels
  labs(
    title = "Weak Fundamentals Create 18x-25x Higher Failure Risk",
    subtitle = "3-Year Failure Probability: Average Bank vs High-Risk Bank (>95th percentile insolvency + noncore funding)",
    x = NULL,
    y = "3-Year Failure Probability",
    fill = "Bank Type",
    caption = "Source: Correia, Luck, Verner (2025) - FailingBanks Analysis\nHigh-Risk = >95th percentile on both Insolvency and Noncore Funding metrics"
  ) +

  # Theme
  theme_minimal(base_size = 14, base_family = "sans") +
  theme(
    plot.title = element_text(size = 18, face = "bold", color = colors$text_dark,
                             margin = margin(b = 8)),
    plot.subtitle = element_text(size = 12, color = colors$text_dark,
                                margin = margin(b = 15)),
    plot.caption = element_text(size = 9, color = "gray40",
                               hjust = 0, margin = margin(t = 15)),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 12),
    legend.text = element_text(size = 11),
    axis.title.y = element_text(face = "bold", size = 13, margin = margin(r = 10)),
    axis.text = element_text(size = 11, color = colors$text_dark),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_line(color = "gray90", size = 0.3),
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA),
    plot.margin = margin(20, 20, 20, 20)
  )

# Save
ggsave(file.path(presentation_outputs_dir, "01_risk_multiplier_simple.png"),
       p1, width = 12, height = 8, dpi = 300, bg = "white")

cat("✓ Saved: 01_risk_multiplier_simple.png (12\" x 8\", 300 DPI)\n")

# ==============================================================================
# VISUALIZATION 2: DETAILED PERCENTILE PROGRESSION
# ==============================================================================

cat("\nCreating detailed percentile progression...\n")

# Prepare data showing full progression
progression_data <- failure_probs %>%
  filter(Era == "Historical") %>%
  mutate(Risk_Level = factor(Risk_Level, levels = c("Low Risk", "Medium Risk",
                                                     "High Risk", "Very High Risk",
                                                     "Extreme Risk")),
         Color_Gradient = case_when(
           Risk_Level == "Low Risk" ~ colors$safe,
           Risk_Level == "Extreme Risk" ~ colors$danger,
           TRUE ~ "#8B7D7D"  # Gray gradient for middle
         ))

p2 <- ggplot(progression_data, aes(x = Risk_Level, y = Failure_Prob_3yr)) +
  geom_col(aes(fill = Risk_Level), width = 0.75, color = "white", size = 0.8) +

  # Add value labels
  geom_text(aes(label = percent(Failure_Prob_3yr, accuracy = 0.1)),
            vjust = -0.5, size = 5, fontface = "bold") +

  # Add percentile labels
  geom_text(aes(label = Percentile),
            vjust = 1.5, size = 4, color = "white", fontface = "bold") +

  # Styling
  scale_fill_manual(values = c(
    "Low Risk" = "#2166AC",
    "Medium Risk" = "#67A9CF",
    "High Risk" = "#F4A460",
    "Very High Risk" = "#D6604D",
    "Extreme Risk" = "#B2182B"
  )) +
  scale_y_continuous(labels = percent_format(accuracy = 1),
                    limits = c(0, 0.32),
                    expand = c(0, 0)) +

  # Labels
  labs(
    title = "From Safe to Failing: The Risk Gradient",
    subtitle = "Historical Era (1863-1934): 3-Year Bank Failure Probability by Risk Percentile",
    x = NULL,
    y = "3-Year Failure Probability",
    caption = "Source: Correia, Luck, Verner (2025) - FailingBanks Analysis\nRisk levels based on combined Insolvency and Noncore Funding percentiles"
  ) +

  # Theme
  theme_minimal(base_size = 14, base_family = "sans") +
  theme(
    plot.title = element_text(size = 18, face = "bold", color = colors$text_dark,
                             margin = margin(b = 8)),
    plot.subtitle = element_text(size = 12, color = colors$text_dark,
                                margin = margin(b = 15)),
    plot.caption = element_text(size = 9, color = "gray40",
                               hjust = 0, margin = margin(t = 15)),
    legend.position = "none",
    axis.title.y = element_text(face = "bold", size = 13, margin = margin(r = 10)),
    axis.text.x = element_text(size = 11, color = colors$text_dark, angle = 15, hjust = 1),
    axis.text.y = element_text(size = 11, color = colors$text_dark),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_line(color = "gray90", size = 0.3),
    plot.background = element_rect(fill = "white", color = NA),
    panel.background = element_rect(fill = "white", color = NA),
    plot.margin = margin(20, 20, 20, 20)
  )

# Save
ggsave(file.path(presentation_outputs_dir, "01_risk_multiplier_progression.png"),
       p2, width = 12, height = 8, dpi = 300, bg = "white")

cat("✓ Saved: 01_risk_multiplier_progression.png (12\" x 8\", 300 DPI)\n")

# ==============================================================================
# VISUALIZATION 3: COMBINED ERA COMPARISON WITH MULTIPLIERS
# ==============================================================================

cat("\nCreating combined era comparison with multiplier callouts...\n")

# Create combined visual
p3_hist <- simple_data %>%
  filter(Era == "Historical\n(1863-1934)") %>%
  ggplot(aes(x = Bank_Type, y = Failure_Rate, fill = Bank_Type)) +
  geom_col(width = 0.6, color = "white", size = 0.8) +
  geom_text(aes(label = percent(Failure_Rate, accuracy = 0.1)),
            vjust = -0.5, size = 6, fontface = "bold") +
  annotate("text", x = 1.5, y = 0.22, label = "18x", size = 10,
           fontface = "bold", color = colors$danger) +
  scale_fill_manual(values = c("Average Bank" = colors$safe,
                               "High-Risk Bank" = colors$danger)) +
  scale_y_continuous(labels = percent_format(accuracy = 1),
                    limits = c(0, 0.30), expand = c(0, 0)) +
  labs(title = "Historical Era (1863-1934)",
       x = NULL, y = "Failure Probability") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(size = 15, face = "bold", hjust = 0.5),
    legend.position = "none",
    axis.text.x = element_text(size = 10, angle = 15, hjust = 1),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank()
  )

p3_modern <- simple_data %>%
  filter(Era == "Modern\n(1959-2024)") %>%
  ggplot(aes(x = Bank_Type, y = Failure_Rate, fill = Bank_Type)) +
  geom_col(width = 0.6, color = "white", size = 0.8) +
  geom_text(aes(label = percent(Failure_Rate, accuracy = 0.1)),
            vjust = -0.5, size = 6, fontface = "bold") +
  annotate("text", x = 1.5, y = 0.10, label = "25x", size = 10,
           fontface = "bold", color = colors$danger) +
  scale_fill_manual(values = c("Average Bank" = colors$safe,
                               "High-Risk Bank" = colors$danger)) +
  scale_y_continuous(labels = percent_format(accuracy = 1),
                    limits = c(0, 0.15), expand = c(0, 0)) +
  labs(title = "Modern Era (1959-2024)",
       x = NULL, y = "Failure Probability") +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(size = 15, face = "bold", hjust = 0.5),
    legend.position = "none",
    axis.text.x = element_text(size = 10, angle = 15, hjust = 1),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank()
  )

# Combine with patchwork
p3_combined <- p3_hist + p3_modern +
  plot_annotation(
    title = "The Risk Multiplier Effect: Across 160 Years of Banking",
    subtitle = "Banks with weak fundamentals (>95th percentile insolvency + noncore funding) face 18x-25x higher failure risk",
    caption = "Source: Correia, Luck, Verner (2025) - FailingBanks Analysis",
    theme = theme(
      plot.title = element_text(size = 18, face = "bold", hjust = 0.5,
                               margin = margin(b = 8)),
      plot.subtitle = element_text(size = 12, hjust = 0.5,
                                   margin = margin(b = 15)),
      plot.caption = element_text(size = 9, hjust = 0.5,
                                 margin = margin(t = 15))
    )
  )

# Save
ggsave(file.path(presentation_outputs_dir, "01_risk_multiplier_combined.png"),
       p3_combined, width = 14, height = 7, dpi = 300, bg = "white")

cat("✓ Saved: 01_risk_multiplier_combined.png (14\" x 7\", 300 DPI)\n")

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n", rep("=", 80), "\n", sep = "")
cat("SCRIPT 01 COMPLETE - RISK MULTIPLIER VISUALS\n")
cat(rep("=", 80), "\n", sep = "")

cat("\n📊 VISUALS CREATED:\n")
cat("  1. 01_risk_multiplier_simple.png (12\" x 8\") - Clean comparison\n")
cat("  2. 01_risk_multiplier_progression.png (12\" x 8\") - Percentile gradient\n")
cat("  3. 01_risk_multiplier_combined.png (14\" x 7\") - Side-by-side eras\n")

cat("\n💡 KEY FINDINGS VISUALIZED:\n")
cat("  - Historical multiplier: 18x (1.5% → 27%)\n")
cat("  - Modern multiplier: 25x (0.5% → 12.5%)\n")
cat("  - Progressive risk gradient across percentiles\n")
cat("  - Pattern holds across both eras\n")

cat("\n📍 Location:", presentation_outputs_dir, "\n")
cat("\n✅ Ready for presentation! Use visual #1 or #3 for maximum impact.\n\n")
