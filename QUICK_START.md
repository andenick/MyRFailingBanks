# Quick Start Guide (5 Minutes)

## Step 1: Install R (2 min)

Download R 4.4.1+ from https://cran.r-project.org

## Step 2: Install Packages (2 min)

```r
install.packages(c("tidyverse", "haven", "fixest", "lubridate",
                   "scales", "readxl", "here", "pROC", "sandwich", "lmtest"))
```

## Step 3: Obtain Data (user responsibility)

Download and place in `sources/` directory:
1. OCC call reports (historical & modern)
2. Receivership records
3. GFD macro data (CPI, yields, stocks)
4. FRED GDP data

See `sources/README.md` for details.

## Step 4: Run Analysis (1 min to start)

```r
setwd("path/to/FailingBanks_v9.0")
source("code/00_master.R")
```

**Runtime**: 2-3 hours
**Output**: 356 files

## Step 5: Verify Results

```r
# Check sample size
data <- readRDS("tempfiles/temp_reg_data.rds")
nrow(data)  # Should be 964,053

# Check AUC
auc <- readRDS("tempfiles/auc_results.rds")
round(auc$model1_is, 4)  # Should be 0.6834
```

---

## Need Help?

See comprehensive documentation in `Documentation/` folder.

---

**Last Updated**: November 16, 2025
