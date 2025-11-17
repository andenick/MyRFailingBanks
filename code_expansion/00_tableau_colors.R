# ==============================================================================
# Tableau Color Palette Definition
# ==============================================================================
# Purpose: Standardize all visualization colors using Tableau 10 Classic palette
# Usage:   source("code_expansion/00_tableau_colors.R") in each script
# ==============================================================================

# Tableau 10 Classic Color Palette
tableau_colors <- c(
  "#1f77b4", # Blue (Primary - Modern Era)
  "#ff7f0e", # Orange (Secondary - Historical)
  "#2ca02c", # Green (Positive/Success)
  "#d62728", # Red (Negative/Failure)
  "#9467bd", # Purple (Great Depression)
  "#8c564b", # Brown (National Banking)
  "#e377c2", # Pink (Transitions)
  "#7f7f7f", # Gray (Neutral)
  "#bcbd22", # Yellow-Green (Early Fed)
  "#17becf"  # Cyan (Financial Crisis)
)

# Named color assignments for consistency
color_modern <- "#1f77b4"      # Blue
color_historical <- "#ff7f0e"  # Orange
color_success <- "#2ca02c"     # Green
color_failure <- "#d62728"     # Red
color_depression <- "#9467bd"  # Purple
color_national <- "#8c564b"    # Brown
color_transition <- "#e377c2"  # Pink
color_neutral <- "#7f7f7f"     # Gray
color_earlyfed <- "#bcbd22"    # Yellow-Green
color_crisis <- "#17becf"      # Cyan

# Era-specific colors (6 eras)
era_colors <- c(
  "1863-1913\nNational Banking" = color_national,
  "1914-1928\nEarly Fed/WWI" = color_earlyfed,
  "1929-1933\nGreat Depression\n(Pre-Holiday)" = color_depression,
  "1933-1935\nGreat Depression\n(Post-Holiday)" = color_transition,
  "1984-2006\nModern Pre-Crisis" = color_modern,
  "2007-2023\nFinancial Crisis" = color_crisis
)

# Failed vs Non-Failed colors
comparison_colors <- c(
  "Failed" = color_failure,
  "Non-Failed" = color_success,
  "Survived" = color_success
)

# Pre vs Post FDIC colors
fdic_colors <- c(
  "Pre-FDIC" = color_historical,
  "Post-FDIC" = color_modern
)

# Standard theme for all visualizations
theme_failing_banks <- function() {
  theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 14, hjust = 0),
      plot.subtitle = element_text(size = 11, color = "gray30", hjust = 0),
      plot.caption = element_text(size = 9, color = "gray50", hjust = 0),
      legend.position = "bottom",
      legend.title = element_text(face = "bold", size = 10),
      panel.grid.minor = element_blank()
    )
}

cat("✓ Tableau color palette loaded\n")
cat("  - tableau_colors: 10-color vector\n")
cat("  - era_colors: 6 historical eras\n")
cat("  - comparison_colors: Failed vs Non-Failed\n")
cat("  - fdic_colors: Pre vs Post FDIC\n")
cat("  - theme_failing_banks(): Standardized theme\n")
