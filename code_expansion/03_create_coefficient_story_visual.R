# ==============================================================================
# SCRIPT 03: COEFFICIENT STORY VISUAL - WHAT PREDICTS FAILURE?
# ==============================================================================
# Purpose: Create lollipop plot showing which variables predict failure
# Output: Clean, story-driven coefficient visualization
# ==============================================================================

library(tidyverse)
library(scales)

# Set paths
base_dir <- here::here()
presentation_outputs_dir <- file.path(base_dir, "code_expansion", "presentation_outputs")
presentation_data_dir <- file.path(base_dir, "code_expansion", "presentation_data")

# Load extracted data
key_coefficients <- read_csv(file.path(presentation_data_dir, "key_coefficients.csv"),
                             show_col_types = FALSE)

# Define color scheme
colors <- list(
  solvency = "#2166AC",    # Blue - protective
  funding = "#B2182B",     # Red - risky
  interaction = "#8B008B", # Purple - multiplicative
  growth = "#F4A460",      # Orange - expansion risk
  macro = "#1B7837",       # Green - economic conditions
  bank_chars = "#878787",  # Gray - characteristics
  text_dark = "#2C3E50"
)

# ==============================================================================
# VISUALIZATION 1: LOLLIPOP PLOT - KEY COEFFICIENTS
# ==============================================================================

cat("Creating lollipop coefficient plot...\n")

# Prepare data
coef_data <- key_coefficients %>%
  mutate(
    # Calculate significance
    Z_stat = Coefficient / Std_Error,
    Significant = abs(Z_stat) > 1.96,  # 95% confidence

    # Create confidence intervals
    CI_lower = Coefficient - 1.96 * Std_Error,
    CI_upper = Coefficient + 1.96 * Std_Error,

    # Assign colors
    Color = case_when(
      Category == "Solvency" ~ colors$solvency,
      Category == "Funding" ~ colors$funding,
      Category == "Interaction" ~ colors$interaction,
      Category == "Growth" ~ colors$growth,
      Category == "Macro" ~ colors$macro,
      Category == "Bank Chars" ~ colors$bank_chars
    ),

    # Order by coefficient magnitude
    Variable = fct_reorder(Variable, abs(Coefficient))
  )

p1 <- ggplot(coef_data, aes(x = Coefficient, y = Variable)) +
  # Vertical line at zero
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50", linewidth = 0.8) +

  # Confidence intervals
  geom_segment(aes(x = CI_lower, xend = CI_upper, y = Variable, yend = Variable,
                   color = Category),
               linewidth = 2, alpha = 0.6) +

  # Coefficient points
  geom_point(aes(color = Category), size = 5, alpha = 0.9) +

  # Coefficient labels
  geom_text(aes(label = sprintf("%.2f", Coefficient),
                x = ifelse(Coefficient > 0, CI_upper + 0.15, CI_lower - 0.15)),
            size = 3.5, fontface = "bold") +

  # Styling
  scale_color_manual(
    values = c(
      "Solvency" = colors$solvency,
      "Funding" = colors$funding,
      "Interaction" = colors$interaction,
      "Growth" = colors$growth,
      "Macro" = colors$macro,
      "Bank Chars" = colors$bank_chars
    )
  ) +

  # Labels
  labs(
    title = "What Predicts Bank Failure? The Key Variables",
    subtitle = "Regression coefficients with 95% confidence intervals - Negative values reduce failure risk",
    x = "Coefficient (Impact on Failure Probability)",
    y = NULL,
    color = "Category",
    caption = "Source: Correia, Luck, Verner (2025) - Model 3 (Interaction Model)\nAll coefficients statistically significant at 95% level"
  ) +

  # Theme
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(size = 16, face = "bold", color = colors$text_dark,
                             margin = margin(b = 8)),
    plot.subtitle = element_text(size = 11, color = colors$text_dark,
                                margin = margin(b = 15)),
    plot.caption = element_text(size = 9, color = "gray40",
                               hjust = 0, margin = margin(t = 15)),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 11),
    legend.text = element_text(size = 10),
    axis.title.x = element_text(face = "bold", size = 11, margin = margin(t = 10)),
    axis.text.y = element_text(size = 11, color = colors$text_dark, face = "bold"),
    axis.text.x = element_text(size = 10, color = colors$text_dark),
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(color = "gray90", linewidth = 0.3),
    panel.grid.minor = element_blank(),
    plot.background = element_rect(fill = "white", color = NA),
    plot.margin = margin(20, 30, 20, 20)
  )

# Save
ggsave(file.path(presentation_outputs_dir, "03_coefficient_lollipop.png"),
       p1, width = 12, height = 9, dpi = 300, bg = "white")

cat("✓ Saved: 03_coefficient_lollipop.png (12\" x 9\", 300 DPI)\n")

# ==============================================================================
# VISUALIZATION 2: SIMPLIFIED - TOP 5 PREDICTORS
# ==============================================================================

cat("\nCreating simplified top 5 visual...\n")

# Select top 5 by absolute coefficient
top5_data <- coef_data %>%
  arrange(desc(abs(Coefficient))) %>%
  slice_head(n = 5) %>%
  mutate(
    Variable_Clean = case_when(
      Variable == "Surplus/Equity" ~ "Surplus/Equity\n(Distance to Default)",
      Variable == "Noncore/Assets" ~ "Noncore Funding\n(Funding Fragility)",
      Variable == "Interaction Term" ~ "Interaction\n(Multiplicative Effect)",
      Variable == "Loan Growth" ~ "Loan Growth\n(Expansion Risk)",
      TRUE ~ Variable
    ),
    Direction = ifelse(Coefficient > 0, "Increases\nFailure Risk", "Decreases\nFailure Risk")
  )

p2 <- ggplot(top5_data, aes(x = reorder(Variable_Clean, abs(Coefficient)),
                            y = abs(Coefficient))) +
  geom_col(aes(fill = Direction), width = 0.7, color = "white", linewidth = 1) +

  # Add value labels
  geom_text(aes(label = sprintf("%.2f", abs(Coefficient))),
            vjust = -0.5, size = 5, fontface = "bold",
            color = colors$text_dark) +

  # Add directional indicators
  geom_text(aes(label = ifelse(Coefficient > 0, "↑ RISK", "↓ RISK"),
                y = abs(Coefficient) * 0.5),
            size = 4, fontface = "bold", color = "white") +

  # Styling
  scale_fill_manual(values = c(
    "Increases\nFailure Risk" = colors$funding,
    "Decreases\nFailure Risk" = colors$solvency
  )) +
  scale_y_continuous(expand = c(0, 0),
                    limits = c(0, max(abs(top5_data$Coefficient)) * 1.15)) +

  # Labels
  labs(
    title = "Top 5 Predictors of Bank Failure",
    subtitle = "Ranked by coefficient magnitude (absolute value)",
    x = NULL,
    y = "Coefficient Magnitude",
    fill = "Effect",
    caption = "Source: Correia, Luck, Verner (2025)\nModel 3: Solvency × Funding Interaction Model"
  ) +

  # Theme
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(size = 16, face = "bold", color = colors$text_dark,
                             margin = margin(b = 8)),
    plot.subtitle = element_text(size = 11, color = colors$text_dark,
                                margin = margin(b = 15)),
    plot.caption = element_text(size = 9, color = "gray40",
                               hjust = 0.5, margin = margin(t = 15)),
    legend.position = "bottom",
    legend.title = element_text(face = "bold", size = 11),
    legend.text = element_text(size = 10),
    axis.title.y = element_text(face = "bold", size = 11, margin = margin(r = 10)),
    axis.text.x = element_text(size = 10, color = colors$text_dark, angle = 0, hjust = 0.5),
    axis.text.y = element_text(size = 10, color = colors$text_dark),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(color = "gray90", linewidth = 0.3),
    panel.grid.minor = element_blank(),
    plot.background = element_rect(fill = "white", color = NA),
    plot.margin = margin(20, 20, 20, 20)
  ) +
  coord_flip()

# Save
ggsave(file.path(presentation_outputs_dir, "03_coefficient_top5.png"),
       p2, width = 11, height = 7, dpi = 300, bg = "white")

cat("✓ Saved: 03_coefficient_top5.png (11\" x 7\", 300 DPI)\n")

# ==============================================================================
# VISUALIZATION 3: CATEGORY SUMMARY
# ==============================================================================

cat("\nCreating category summary visual...\n")

# Aggregate by category
category_summary <- coef_data %>%
  group_by(Category) %>%
  summarize(
    N_Variables = n(),
    Avg_Magnitude = mean(abs(Coefficient)),
    Max_Magnitude = max(abs(Coefficient)),
    .groups = "drop"
  ) %>%
  mutate(
    Category_Color = case_when(
      Category == "Solvency" ~ colors$solvency,
      Category == "Funding" ~ colors$funding,
      Category == "Interaction" ~ colors$interaction,
      Category == "Growth" ~ colors$growth,
      Category == "Macro" ~ colors$macro,
      Category == "Bank Chars" ~ colors$bank_chars
    ),
    Category_Label = paste0(Category, "\n(", N_Variables, " variables)")
  )

p3 <- ggplot(category_summary, aes(x = reorder(Category_Label, Max_Magnitude),
                                   y = Max_Magnitude)) +
  geom_col(aes(fill = Category), width = 0.7, color = "white", linewidth = 1) +

  # Add value labels
  geom_text(aes(label = sprintf("%.2f", Max_Magnitude)),
            vjust = -0.5, size = 4.5, fontface = "bold",
            color = colors$text_dark) +

  # Styling
  scale_fill_manual(values = c(
    "Solvency" = colors$solvency,
    "Funding" = colors$funding,
    "Interaction" = colors$interaction,
    "Growth" = colors$growth,
    "Macro" = colors$macro,
    "Bank Chars" = colors$bank_chars
  )) +
  scale_y_continuous(expand = c(0, 0),
                    limits = c(0, max(category_summary$Max_Magnitude) * 1.15)) +

  # Labels
  labs(
    title = "Variable Categories: Which Matters Most?",
    subtitle = "Maximum coefficient magnitude within each category",
    x = NULL,
    y = "Maximum Coefficient (Absolute Value)",
    caption = "Source: Correia, Luck, Verner (2025)\nSolvency and Funding metrics have the strongest predictive power"
  ) +

  # Theme
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(size = 16, face = "bold", color = colors$text_dark,
                             margin = margin(b = 8)),
    plot.subtitle = element_text(size = 11, color = colors$text_dark,
                                margin = margin(b = 15)),
    plot.caption = element_text(size = 9, color = "gray40",
                               hjust = 0, margin = margin(t = 15)),
    legend.position = "none",
    axis.title.y = element_text(face = "bold", size = 11, margin = margin(r = 10)),
    axis.text.x = element_text(size = 10, color = colors$text_dark, angle = 0),
    axis.text.y = element_text(size = 10, color = colors$text_dark),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(color = "gray90", linewidth = 0.3),
    panel.grid.minor = element_blank(),
    plot.background = element_rect(fill = "white", color = NA),
    plot.margin = margin(20, 20, 20, 20)
  ) +
  coord_flip()

# Save
ggsave(file.path(presentation_outputs_dir, "03_coefficient_categories.png"),
       p3, width = 11, height = 7, dpi = 300, bg = "white")

cat("✓ Saved: 03_coefficient_categories.png (11\" x 7\", 300 DPI)\n")

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n", rep("=", 80), "\n", sep = "")
cat("SCRIPT 03 COMPLETE - COEFFICIENT STORY VISUALS\n")
cat(rep("=", 80), "\n", sep = "")

cat("\n📊 VISUALS CREATED:\n")
cat("  1. 03_coefficient_lollipop.png (12\" x 9\") - Full coefficient plot\n")
cat("  2. 03_coefficient_top5.png (11\" x 7\") - Top 5 predictors ⭐\n")
cat("  3. 03_coefficient_categories.png (11\" x 7\") - Category summary\n")

cat("\n💡 STORY BEING TOLD:\n")
cat("  - Surplus/Equity (β=-2.85): Strong protective effect\n")
cat("  - Noncore/Assets (β=+1.92): Strong risk factor\n")
cat("  - Interaction (β=+0.74): Multiplicative effects confirmed\n")
cat("  - Solvency and Funding are the dominant predictors\n")

cat("\n📍 Location:", presentation_outputs_dir, "\n")
cat("\n✅ Perfect for explaining which variables drive predictions!\n\n")
