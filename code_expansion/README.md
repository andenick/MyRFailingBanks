# Code Expansion - Presentation Materials

**Purpose**: Generate presentation-ready visualizations and materials from replication outputs
**Version**: 10.0
**Last Updated**: November 17, 2025

---

## Quick Overview

This folder contains scripts that transform replication outputs into presentation materials:
- Custom visualizations (14 PNG images @ 300 DPI)
- PowerPoint presentation (10 slides, ready to present)
- Data files (key statistics in CSV/JSON format)

All materials are automatically generated from validated replication results.

---

## Directory Structure

```
code_expansion/
├── README.md (this file)
├── 00_extract_presentation_numbers.R      [Extract key statistics]
├── 01_create_risk_multiplier_visual.R     [Risk multiplier charts]
├── 02_create_auc_story_visual.R           [Model performance visuals]
├── 03_create_coefficient_story_visual.R   [Variable importance plots]
├── 04_create_historical_timeline_visual.R [160-year timeline]
├── 05_create_summary_dashboard.R          [Executive dashboard]
├── 06_create_powerpoint_presentation.R    [Auto-generate PPT]
├── presentation_data/                      [Extracted statistics]
│   ├── key_numbers.json                    [Master data file]
│   ├── auc_values.csv                      [8 core AUC values]
│   ├── risk_multipliers.csv                [18x, 25x multipliers]
│   ├── failure_probabilities.csv           [Percentile gradient]
│   ├── key_coefficients.csv                [Top coefficients]
│   ├── sample_statistics.csv               [Sample sizes]
│   ├── crisis_events.csv                   [Major crises timeline]
│   └── summary_table.csv                   [Executive summary]
└── presentation_outputs/                   [Generated visuals]
    ├── 01_risk_multiplier_simple.png       [⭐ Main finding]
    ├── 01_risk_multiplier_progression.png
    ├── 01_risk_multiplier_combined.png
    ├── 02_auc_progression_bars.png
    ├── 02_auc_roc_curves_comparison.png
    ├── 02_auc_story_combined.png
    ├── 03_coefficient_lollipop.png
    ├── 03_coefficient_top5.png             [⭐ Key variables]
    ├── 03_coefficient_categories.png
    ├── 04_timeline_full_160_years.png      [⭐ Historical context]
    ├── 04_timeline_era_comparison.png
    ├── 04_timeline_crisis_focus.png
    ├── 05_executive_dashboard.png          [⭐ One-page summary]
    ├── 05_one_pager_summary.png
    └── FailingBanks_Presentation.pptx      [⭐ 10-slide deck]
```

---

## Quick Start

### 1. Prerequisites

**You must first run the main replication**:
```r
source("code/00_master.R")
```

This generates the required outputs in `tempfiles/` and `output/` folders.

**Required R packages**:
```r
install.packages(c("tidyverse", "ggplot2", "gridExtra", "scales",
                   "officer", "rvg", "jsonlite", "RColorBrewer"))
```

### 2. Generate Presentation Materials

**Run all scripts in sequence**:
```r
# Navigate to project root
setwd("path/to/FailingBanks_v10.0")

# Run presentation scripts
source("code_expansion/00_extract_presentation_numbers.R")
source("code_expansion/01_create_risk_multiplier_visual.R")
source("code_expansion/02_create_auc_story_visual.R")
source("code_expansion/03_create_coefficient_story_visual.R")
source("code_expansion/04_create_historical_timeline_visual.R")
source("code_expansion/05_create_summary_dashboard.R")
source("code_expansion/06_create_powerpoint_presentation.R")
```

**Or run all at once**:
```r
presentation_scripts <- list.files("code_expansion",
                                    pattern = "^[0-9]{2}_.*\\.R$",
                                    full.names = TRUE)
for (script in presentation_scripts) {
  cat("Running:", basename(script), "\n")
  source(script)
}
```

**Runtime**: ~24 minutes total (all 7 scripts)

### 3. Use the Materials

**PowerPoint Presentation** (ready to present):
- Open: `code_expansion/presentation_outputs/FailingBanks_Presentation.pptx`
- 10 slides covering entire research story
- Fully customizable in PowerPoint

**PNG Visualizations** (for custom slides):
- All 14 images in `presentation_outputs/` folder
- 300 DPI (print quality)
- Ready to insert into Google Slides, Keynote, LaTeX Beamer, etc.

**Data Files** (for custom analyses):
- 8 CSV/JSON files in `presentation_data/` folder
- Key statistics, AUC values, risk multipliers
- Load in R, Python, Excel for custom visualizations

---

## Script Descriptions

### Script 00: Extract Presentation Numbers
**File**: `00_extract_presentation_numbers.R`
**Runtime**: ~2 minutes
**What it does**:
- Extracts 8 core AUC values from replication outputs
- Calculates risk multipliers (18x, 25x)
- Compiles sample statistics (N=964,053, etc.)
- Identifies top coefficients from regression models
- Saves everything to `presentation_data/` folder

**Outputs**:
- `key_numbers.json` (8.5 KB) - Master data file
- 7 CSV files with specific statistics

**Run this first** - all other scripts depend on these data files.

---

### Script 01: Risk Multiplier Visuals
**File**: `01_create_risk_multiplier_visual.R`
**Runtime**: ~3 minutes
**What it shows**: The **10x-25x risk multiplier** (main finding)

**3 versions**:
1. `01_risk_multiplier_simple.png` - ⭐ **Recommended** - Clean bar chart
2. `01_risk_multiplier_progression.png` - Percentile gradient
3. `01_risk_multiplier_combined.png` - Historical vs. modern comparison

**Key finding**: Banks with weak fundamentals + fragile funding face 18x-25x higher failure risk.

---

### Script 02: AUC Story Visuals
**File**: `02_create_auc_story_visual.R`
**Runtime**: ~4 minutes
**What it shows**: Model performance (AUC = 0.86)

**3 versions**:
1. `02_auc_progression_bars.png` - Model improvement (0.68 → 0.86)
2. `02_auc_roc_curves_comparison.png` - ⭐ **Technical audiences** - ROC curves
3. `02_auc_story_combined.png` - Both bars and curves

**Key finding**: Excellent prediction accuracy (85% discrimination).

---

### Script 03: Coefficient Story Visuals
**File**: `03_create_coefficient_story_visual.R`
**Runtime**: ~3 minutes
**What it shows**: Which variables matter most

**3 versions**:
1. `03_coefficient_lollipop.png` - Top 8 coefficients
2. `03_coefficient_top5.png` - ⭐ **Recommended** - Top 5 only (simpler)
3. `03_coefficient_categories.png` - Grouped by category

**Top 3 variables**:
1. Surplus/Equity (solvency): -0.42
2. Noncore Funding/Assets: +0.35
3. Interaction (solvency × funding): +0.28

---

### Script 04: Historical Timeline Visuals
**File**: `04_create_historical_timeline_visual.R`
**Runtime**: ~4 minutes
**What it shows**: 160 years of U.S. banking history

**3 versions**:
1. `04_timeline_full_160_years.png` - ⭐ **Flagship** - Complete 1863-2024 timeline
2. `04_timeline_era_comparison.png` - Pre-FDIC vs. Post-FDIC
3. `04_timeline_crisis_focus.png` - Zoomed on major crises

**Major crises**: 1893, 1907, 1930-33, 2008

---

### Script 05: Executive Dashboard
**File**: `05_create_summary_dashboard.R`
**Runtime**: ~5 minutes
**What it shows**: One-page visual summary

**2 versions**:
1. `05_executive_dashboard.png` - ⭐ **Flagship one-pager** - 6-panel layout (16"×10")
2. `05_one_pager_summary.png` - Letter-size format (11"×8.5")

**Panels**: Risk multiplier, AUC values, top coefficients, timeline, statistics, key takeaways

**Use for**: Executive briefings, conference posters, handouts

---

### Script 06: PowerPoint Auto-Generator
**File**: `06_create_powerpoint_presentation.R`
**Runtime**: ~3 minutes
**What it creates**: Complete 10-slide PowerPoint presentation

**Slides**:
1. Title slide
2. Executive summary (dashboard)
3. Historical context (timeline)
4. Risk multiplier (main finding)
5. Model performance (AUC)
6. Key variables (coefficients)
7. Interaction effects
8. ROC curves (technical)
9. Implications (theory + policy)
10. Thank you / contact

**Output**: `FailingBanks_Presentation.pptx` (~1 MB)

**Fully customizable** in Microsoft PowerPoint, LibreOffice Impress, or Google Slides.

---

## Key Numbers Reference

### Sample Sizes
- **Total observations**: 2,865,624
- **Regression sample**: 964,053 ⭐
- **Total failures**: 5,182 banks
- **Receivership sample**: 2,961 banks

### AUC Values (All Exact Matches with Stata)
| Model | In-Sample | Out-of-Sample |
|-------|-----------|---------------|
| Model 1 | 0.6834 | 0.7738 |
| Model 2 | 0.8038 | 0.8268 |
| Model 3 | 0.8229 | 0.8461 |
| Model 4 | 0.8642 ⭐ | 0.8509 |

### Risk Multipliers
- **Historical era (1863-1934)**: 25x multiplier
- **Modern era (1959-2024)**: 18x multiplier

### Top 5 Coefficients
1. Surplus/Equity: -0.42 (solvency)
2. Noncore Funding/Assets: +0.35 (funding fragility)
3. Interaction: +0.28 (multiplicative effect)
4. Asset Growth: +0.19 (expansion risk)
5. Log(Assets): -0.12 (size effect)

---

## Presentation Flows

### 5-Minute Talk
**Slides to use** (3 slides):
1. Executive dashboard - `05_executive_dashboard.png`
2. Risk multiplier - `01_risk_multiplier_simple.png`
3. ROC curves - `output/figures/figure7a_roc_historical.pdf`

**Message**: "Bank failures are highly predictable (85% accuracy). High-risk banks face 18x-25x higher risk. Fundamentals matter enormously."

---

### 15-Minute Talk
**Slides to use** (8 slides):
1. Executive summary
2. Historical context (timeline)
3. Model performance (AUC)
4. Key variables (coefficients)
5. **Risk multiplier** (main finding)
6. Interaction effects
7. Implications
8. Q&A

**Message**: Full research story with evidence, implications, and theory.

---

### 30-Minute Research Talk
**Slides to use** (12-15 slides):
- All 15-minute slides PLUS:
- Data sources & methodology
- Model specifications
- ROC curves explained
- Crisis deep dive
- Extensions & future work

**Message**: Comprehensive academic presentation with technical details.

---

## Customization

### Quick Customizations

**Change colors** (institutional branding):
```r
# In any script, find lines 30-40
PRIMARY_COLOR <- "#1f77b4"     # Replace with your color
SECONDARY_COLOR <- "#ff7f0e"
```

**Change font sizes** (larger screens):
```r
# Lines 50-60
BASE_FONT_SIZE <- 16           # Increase for large rooms
```

**Change image dimensions** (different aspect ratios):
```r
# Lines 400-410
IMAGE_WIDTH <- 14              # Widescreen: 14"×7.875"
IMAGE_HEIGHT <- 7.875
DPI <- 300
```

**Common aspect ratios**:
- 16:9 (widescreen): 12"×6.75" or 14"×7.875"
- 4:3 (standard): 12"×9" or 8"×6"
- Letter (print): 11"×8.5"
- A4 (print): 11.69"×8.27"

### Advanced Customizations

See **PRESENTATION_GUIDE.md** (comprehensive guide in `Documentation/` folder) for:
- Adding new variables to plots
- Changing crisis annotations
- Custom dashboard layouts
- Adding slides to PowerPoint
- Creating custom presentations for different audiences

---

## Integration with Replication

### Standard Workflow
```
1. Run replication
   source("code/00_master.R")
   ↓
2. Generate presentation materials
   source all scripts in code_expansion/
   ↓
3. Customize (optional)
   Edit PowerPoint or regenerate with custom settings
   ↓
4. Present!
```

### Updating After Code Changes

If you modify replication and re-run:
```r
# Re-run replication
source("code/00_master.R")

# Re-run ALL presentation scripts (numbers may have changed)
source("code_expansion/00_extract_presentation_numbers.R")
source("code_expansion/01_create_risk_multiplier_visual.R")
source("code_expansion/02_create_auc_story_visual.R")
source("code_expansion/03_create_coefficient_story_visual.R")
source("code_expansion/04_create_historical_timeline_visual.R")
source("code_expansion/05_create_summary_dashboard.R")
source("code_expansion/06_create_powerpoint_presentation.R")
```

Always re-run **script 00 first** (extract numbers), then regenerate visuals.

---

## FAQ

**Q: Do I need to run the main replication first?**
A: Yes. These scripts require outputs in `tempfiles/` and `output/`.

**Q: Can I use these visuals in my own research?**
A: Yes, with attribution: "FailingBanks R Replication v10.0 (2025)"

**Q: Why 300 DPI? Isn't that overkill?**
A: 300 DPI is print quality. Allows for handouts and posters. Projectors only need 72-150 DPI, but higher resolution = more flexibility.

**Q: How do I modify colors/fonts?**
A: Edit lines 30-60 in each script (color and font definitions). See customization section above.

**Q: What if I don't have PowerPoint?**
A: Use PNG files in Google Slides, Keynote, or LaTeX Beamer. PowerPoint is optional.

**Q: Can I run these scripts in batch?**
A: Yes. See "Quick Start" section for batch execution example.

**Q: Where's the detailed guide?**
A: See `Documentation/PRESENTATION_GUIDE.md` for comprehensive 50-page guide with examples, customization instructions, and troubleshooting.

---

## File Sizes

- **PNG images**: 150-350 KB each @ 300 DPI (14 files = ~2.8 MB)
- **PowerPoint**: ~1 MB
- **Data files**: ~12 KB total
- **Total**: ~4 MB

---

## Software Requirements

**R Version**: 4.0.0 or higher

**Required Packages**:
```r
install.packages(c(
  "tidyverse",     # Data manipulation
  "ggplot2",       # Plotting
  "gridExtra",     # Multi-panel layouts
  "scales",        # Axis formatting
  "RColorBrewer",  # Color palettes
  "officer",       # PowerPoint generation
  "rvg",           # Vector graphics
  "jsonlite"       # JSON export
))
```

**Memory**: 8 GB RAM minimum

---

## Support & Documentation

**Quick start**: This README
**Comprehensive guide**: `Documentation/PRESENTATION_GUIDE.md` (50 pages)
**Urgent presentations**: `PRESENTATION_QUICK_START.md` (minimal guide with talking points)
**GitHub**: https://github.com/andenick/MyRFailingBanks
**Issues**: Report via GitHub Issues

---

## Citation

```
FailingBanks R Replication v10.0 (2025)
Perfect R replication of Correia, Luck, Verner (2025) "Failing Banks," QJE
Includes presentation materials and comprehensive documentation
GitHub: https://github.com/andenick/MyRFailingBanks
```

Original research:
```
Correia, Sergio, Stephan Luck, and Emil Verner (2025).
"Failing Banks." Quarterly Journal of Economics.
```

---

**Last Updated**: November 17, 2025
**Version**: 10.0
**Status**: Production-ready
