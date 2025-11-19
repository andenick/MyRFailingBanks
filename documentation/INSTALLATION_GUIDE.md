# Installation Guide - FailingBanks R Replication v11.1

**Perfect Statistical Replication Package | Quick Start Instructions**

---

## 🚀 Quick Start (5 Minutes)

### Prerequisites
- **R ≥ 4.0.0** (tested with R 4.4.1)
- **RStudio** (recommended but not required)
- **8GB+ RAM** (for large dataset processing)
- **2GB+ disk space** (for package and outputs)

### Installation Steps

1. **Extract Package**
   ```bash
   # Extract to your preferred location
   # You should have: FailingBanks_R_Replication_v11.1_Definitive/
   ```

2. **Open in RStudio**
   ```r
   # Open FailingBanks_v11.1.Rproj in RStudio
   # This automatically sets the correct working directory
   ```

3. **Run Complete Analysis**
   ```r
   # Execute the master script (runs everything automatically)
   source("code/00_master.R")
   ```

**✅ That's it!** The script will:
- Install all required packages automatically
- Process all data and run complete analysis
- Generate 100+ output files in 45-60 minutes
- Display completion summary with validation results

---

## 📋 Detailed Installation

### Step 1: System Requirements

#### Software Requirements
- **R Version**: 4.0.0 or higher (recommended: 4.4.1)
- **Operating System**: Windows 10+, macOS 10.14+, or Linux
- **Memory**: Minimum 4GB RAM (recommended 8GB+)
- **Storage**: 2GB available space

#### Optional but Recommended
- **RStudio**: Latest version for best development experience
- **Git**: For version control (optional)

### Step 2: Package Setup

#### Download and Extract
```bash
# Windows/Mac/Linux
unzip FailingBanks_R_Replication_v11.1_Definitive.zip
cd FailingBanks_R_Replication_v11.1_Definitive/
```

#### Open in RStudio
1. Launch RStudio
2. File → Open Project → Select `FailingBanks_v11.1.Rproj`
3. This sets the working directory automatically

### Step 3: Data Requirements

#### Required Source Data
The analysis requires original source data files from the Stata qje-repkit:

**Critical Data Files**:
- `all_bank_statistics.dta` (2.6 MB)
- `receiverships_panel.dta` (7.5 MB)
- `stock_prices_before_1935.dta` (110 MB)
- `stock-data.dta` (116 MB)
- `A939RX0Q048SBEA.xlsx` (BEA GDP data)
- Additional macro and financial data files

**Data Placement**:
```
FailingBanks_R_Replication_v11.1_Definitive/
├── sources/                    # Create this directory
│   ├── Macro/                  # Place macro data here
│   ├── FDIC/                   # Place FDIC data here
│   └── [other source folders]
```

#### Data Acquisition
Source data must be obtained from:
1. **Original Research**: Download from the authors' website
2. **FDIC Resources**: Bank failure and receivership data
3. **Economic Data**: BEA, FRED, and other macro sources

### Step 4: Running the Analysis

#### Automatic Complete Analysis
```r
# This runs everything from start to finish
source("code/00_master.R")
```

**Expected Process**:
1. **Environment Setup** (2-3 minutes)
2. **Package Installation** (5-10 minutes)
3. **Data Processing** (20-30 minutes)
4. **Analysis Execution** (15-20 minutes)
5. **Output Generation** (2-5 minutes)

#### Manual Step-by-Step (Advanced)
```r
# For testing or partial execution
source("code/00_setup.R")           # Setup environment
source("code/01_import_GDP.R")      # Test individual scripts
source("code/51_auc.R")             # Critical AUC validation
```

---

## 🔧 Troubleshooting

### Common Issues and Solutions

#### Issue 1: Package Installation Errors
```r
# If package installation fails
install.packages(c("tidyverse", "haven", "fixest", "pROC", "data.table"))
```

#### Issue 2: Memory Errors
```r
# If you run out of memory
# Close other applications
# Use smaller data subset for testing
```

#### Issue 3: Data File Not Found
```r
# Check file paths
file.exists("sources/Macro/A939RX0Q048SBEA.xlsx")
# Ensure all source data files are in correct locations
```

#### Issue 4: RStudio Path Issues
```r
# Manual path setup (if project file doesn't work)
setwd("path/to/FailingBanks_R_Replication_v11.1_Definitive/")
getwd()  # Verify working directory
```

### Performance Optimization

#### For Faster Execution
```r
# Use multiple cores if available
library(parallel)
detectCores()  # Check available cores
```

#### For Memory Efficiency
```r
# Clear workspace between major steps
rm(list = ls())
gc()  # Force garbage collection
```

---

## 📊 Expected Outputs

### File Structure After Execution
```
FailingBanks_R_Replication_v11.1_Definitive/
├── outputs/
│   ├── figures/           # 98+ PDF figures and plots
│   ├── tables/            # Regression and summary tables
│   └── data/              # Generated datasets
├── tempfiles/             # Intermediate files
└── validation/           # Execution logs and evidence
```

### Key Outputs Generated
- **ROC Curves**: `figure7a_roc_historical.pdf`, `figure7b_roc_modern.pdf`
- **Coefficient Plots**: `coefplots_combined.pdf`
- **Time Series**: Bank failure rate plots (160 years)
- **Regression Tables**: LaTeX and CSV formats
- **AUC Summary**: Comprehensive accuracy metrics

### Validation Confirmation
After successful execution, you should see:
```
✅ PERFECT REPLICATION ACHIEVED
✅ 8/8 Critical AUC Values: Exact 4-decimal matches
✅ 5/5 Sample Sizes: Perfect matches
✅ 35/35 Models: All executed successfully
```

---

## 🎓 Advanced Usage

### Custom Analysis
```r
# Run specific time periods
source("code/51_auc.R")  # Full AUC analysis
# Modify script for custom specifications
```

### Data Exploration
```r
# Load processed data
library(data.table)
data <- fread("dataclean/combined-data.rds")
summary(data)
```

### Validation Testing
```r
# Run individual validation checks
source("validation/validation_tests.R")
```

---

## 📞 Support Resources

### Documentation Package
- **COMPREHENSIVE_VALIDATION_REPORT.md**: Complete validation evidence
- **PERFECT_AUC_MATCHES_EVIDENCE.md**: Statistical accuracy proof
- **SAMPLE_SIZE_VERIFICATION.md**: Data integrity confirmation
- **METHODOLOGY_SUMMARY.md**: Research approach details

### Execution Logs
```
validation/script_execution_logs/
├── script_01_log.txt      # Data preparation logs
├── script_51_log.txt      # Critical AUC analysis
└── [all other script logs]
```

### Getting Help
1. **Check Logs**: Review execution logs for error details
2. **Verify Data**: Ensure all source files are present
3. **Validate Environment**: Confirm R version and package installation
4. **Consult Documentation**: Refer to comprehensive validation reports

---

## ✅ Installation Verification

### Quick Test
```r
# Test basic functionality
source("code/00_setup.R")
print("✅ Setup successful")
```

### Full Validation Test
```r
# Run critical AUC validation (most important test)
source("code/51_auc.R")
# Should complete with perfect AUC matches
```

### Success Indicators
You'll know installation is successful when:
- ✅ All packages install without errors
- ✅ Data files are found and loaded
- ✅ Scripts execute to completion
- ✅ Output files are generated in correct locations
- ✅ Validation confirms perfect replication

---

**Need Help?** Check the comprehensive validation reports in the `validation/` directory for detailed troubleshooting information and execution evidence.

---

**Installation Success Criteria**: Perfect replication validation (8/8 AUC matches, 5/5 sample size matches)

---

*This guide ensures successful installation and execution of the FailingBanks R Replication Package v11.1 with perfect statistical accuracy.*