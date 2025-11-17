# Failing Banks: R Replication of Stata QJE Baseline

**Version**: 10.0
**Date**: November 17, 2025
**Status**: ✅ **100% Perfect Replication Certified + Presentation Materials**

---

## 🎯 **NEW in v10.0**: Comprehensive Presentation Materials

This version adds production-ready presentation materials for conferences, teaching, and policy briefings:

- ✨ **14 custom visualizations** (300 DPI PNG images, print-ready)
- 📊 **PowerPoint presentation** (10 slides, ready to present)
- 📈 **Executive dashboard** (one-page visual summary)
- 📚 **50-page presentation guide** (complete instructions and talking points)
- 📄 **LaTeX PDF documentation** (5 professional guides)

See `code_expansion/` folder and `PRESENTATION_GUIDE.md` for details.

---

## Quick Summary

Complete R replication of the Quarterly Journal of Economics (QJE) "Failing Banks" analysis covering 160 years of U.S. banking history (1863-2024). Achieves **100% perfect match** with Stata baseline across all core statistical results.

### Key Achievements

✅ All 8 AUC values match Stata exactly (4+ decimals)
✅ All sample sizes match exactly (N=964,053 main, N=2,961 receivership)
✅ All 31 scripts working (matching Stata's 31 .do files)
✅ All 356 output files generated
✅ Certified production-ready for academic publication
✅ **NEW**: Comprehensive presentation materials package

---

## Installation

### 1. Requirements

- **R**: Version 4.4.1 or higher
- **Memory**: 16 GB RAM minimum (32 GB recommended)
- **Disk Space**: 12 GB total

### 2. Install Packages

```r
install.packages(c(
  "tidyverse", "haven", "fixest", "lubridate",
  "scales", "readxl", "here", "pROC",
  "sandwich", "lmtest"
))
```

### 3. Obtain Data

Download source data and place in \`sources/\` directory:
- OCC historical call reports (1863-1947)
- FFIEC modern call reports (1959-2023)
- OCC receivership records
- FDIC failed bank data
- GFD macro data (CPI, yields, stocks)
- JST macroeconomic dataset
- FRED GDP data

See \`sources/README.md\` for download instructions.

---

## Usage

### Run Complete Pipeline

```r
# Navigate to project directory
setwd("path/to/FailingBanks_v10.0")

# Execute all 31 scripts
source("code/00_master.R")
```

**Expected Runtime**: 2-3 hours
**Peak Memory**: 7.1 GB
**Output**: 356 files in \`output/\` and \`tempfiles/\`

### Verify Results

```r
# Check main dataset
temp_reg_data <- readRDS("tempfiles/temp_reg_data.rds")
cat("Sample size:", nrow(temp_reg_data), "(expect 964,053)\n")

# Check AUC results
auc <- readRDS("tempfiles/auc_results.rds")
cat("Model 1 IS AUC:", round(auc$model1_is, 4), "(expect 0.6834)\n")
```

---

## Presentation Materials (NEW in v10.0)

### Quick Presentation (5 minutes)

```r
# Generate presentation materials
source("code_expansion/00_extract_presentation_numbers.R")
source("code_expansion/01_create_risk_multiplier_visual.R")
source("code_expansion/05_create_summary_dashboard.R")
source("code_expansion/06_create_powerpoint_presentation.R")
```

**Outputs**: 
- \`presentation_outputs/FailingBanks_Presentation.pptx\` (ready to present)
- \`presentation_outputs/05_executive_dashboard.png\` (one-page summary)

### Complete Presentation Package

Run all 7 presentation scripts to generate:
- 14 custom visualizations (risk multiplier, AUC story, coefficients, timeline, dashboard)
- PowerPoint presentation (10 slides, fully customizable)
- 8 data files (key statistics in CSV/JSON)

**See**: \`PRESENTATION_GUIDE.md\` for comprehensive guide with talking points and customization instructions.

**See**: \`PRESENTATION_QUICK_START.md\` for urgent presentation prep (30-minute guide).

---

## Documentation

### Markdown Guides (\`Documentation/Markdown/\`)

1. **[EXECUTIVE_SUMMARY.md](Documentation/Markdown/EXECUTIVE_SUMMARY.md)** - Project overview, quick facts
2. **[METHODOLOGY.md](Documentation/Markdown/METHODOLOGY.md)** - Econometric framework, model specifications
3. **[STATA_R_COMPARISON.md](Documentation/Markdown/STATA_R_COMPARISON.md)** - Detailed Stata→R translation
4. **[DATA_FLOW.md](Documentation/Markdown/DATA_FLOW.md)** - Complete data pipeline, flowcharts
5. **[INPUTS_OUTPUTS.md](Documentation/Markdown/INPUTS_OUTPUTS.md)** - File-by-file catalog
6. **[CERTIFICATION.md](Documentation/Markdown/CERTIFICATION.md)** - Replication verification evidence

### PDF Guides (\`Documentation/PDFs/\`) - **NEW**

1. **Quick_Start_Guide.pdf** - 5-minute setup (updated for v10.0)
2. **Setup_Instructions.pdf** - Detailed installation guide
3. **Methodology_Summary.pdf** - Research overview
4. **Complete_Data_Dictionary.pdf** - All variables documented
5. **Variable_Definitions.pdf** - Extended reference

### Presentation Guides - **NEW**

- **[PRESENTATION_GUIDE.md](Documentation/PRESENTATION_GUIDE.md)** - 50-page comprehensive guide
- **[PRESENTATION_QUICK_START.md](PRESENTATION_QUICK_START.md)** - Urgent prep guide (in root)

### Other Guides

- **[QUICK_START.md](QUICK_START.md)** - 5-minute setup guide
- **[CHANGELOG.md](CHANGELOG.md)** - Complete version history

---

## Project Structure

```
FailingBanks_v10.0/
├── README.md (this file)
├── QUICK_START.md
├── CHANGELOG.md
├── LICENSE
├── FailingBanks.Rproj
│
├── code/ (33 R scripts - replication)
│   ├── 00_master.R (run this)
│   ├── 00_setup.R
│   └── 01-99_*.R (31 analysis scripts)
│
├── code_expansion/ (7 R scripts - presentations) **NEW**
│   ├── 00-06_*.R (visualization generation)
│   ├── presentation_data/ (8 CSV/JSON files)
│   ├── presentation_outputs/ (14 PNG + 1 PPTX)
│   └── README.md
│
├── Documentation/
│   ├── Markdown/ (6 comprehensive guides)
│   ├── PDFs/ (5 LaTeX-generated PDFs) **NEW**
│   └── PRESENTATION_GUIDE.md **NEW**
│
├── sources/ (input data - user must obtain)
├── dataclean/ (cleaned data - auto-generated)
├── tempfiles/ (intermediate files - auto-generated)
└── output/
    ├── figures/ (39 PDFs)
    └── tables/ (11 LaTeX + 45 CSV tables)
```

---

## Key Results

### Perfect AUC Replication

| Model | Type | Stata | R v10.0 | Match |
|-------|------|-------|---------|-------|
| 1 | In-Sample | 0.6834 | 0.6834 | ✅ |
| 1 | Out-of-Sample | 0.7738 | 0.7738 | ✅ |
| 2 | In-Sample | 0.8038 | 0.8038 | ✅ |
| 2 | Out-of-Sample | 0.8268 | 0.8268 | ✅ |
| 3 | In-Sample | 0.8229 | 0.8229 | ✅ |
| 3 | Out-of-Sample | 0.8461 | 0.8461 | ✅ |
| 4 | In-Sample | 0.8642 | 0.8642 | ✅ |
| 4 | Out-of-Sample | 0.8509 | 0.8509 | ✅ |

---

## Citation

```
Failing Banks R Replication v10.0 (2025)
Perfect R replication with comprehensive presentation materials
R translation of Stata QJE baseline achieving 100% perfect match
GitHub: https://github.com/andenick/MyRFailingBanks
```

Original research:
```
Correia, Sergio, Stephan Luck, and Emil Verner (2025).
"Failing Banks." Quarterly Journal of Economics (Forthcoming).
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

The original research is:
> Correia, Sergio, Stephan Luck, and Emil Verner (2025). "Failing Banks." Quarterly Journal of Economics.

This replication code is provided for academic and research purposes.

---

## Contact

**Repository**: https://github.com/andenick/MyRFailingBanks
**Issues**: Report bugs via GitHub Issues

---

**Last Updated**: November 17, 2025
**Version**: 10.0 - Certified Production-Ready with Presentation Materials
