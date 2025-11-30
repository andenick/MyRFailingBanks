# Data Sources

## Primary Data Sources

### 1. FDIC Call Reports
- **Source**: Federal Deposit Insurance Corporation
- **URL**: https://www.fdic.gov/analysis/quarterly-banking-profile/
- **Content**: Quarterly regulatory filings (Schedule RC) containing balance sheet and income statement data
- **Format**: Originally in Stata (.dta) format from Correia replication package

### 2. FDIC Failures Database
- **Source**: Federal Deposit Insurance Corporation
- **URL**: https://www.fdic.gov/resources/resolutions/bank-failures/
- **Content**: Official failure dates, resolution types, and failure costs
- **Format**: CSV/Excel

### 3. FRED (Federal Reserve Economic Data)
- **Source**: Federal Reserve Bank of St. Louis
- **URL**: https://fred.stlouisfed.org/
- **Content**: Macroeconomic variables (GDP growth, CPI inflation)
- **Format**: CSV

---

## Processed Data Files

### `analysis_data_2000.rds`
**Description**: Main analysis dataset filtered for post-2000 period

| Column | Type | Description |
|--------|------|-------------|
| cert | integer | FDIC Certificate Number (bank identifier) |
| year | integer | Calendar year |
| quarter | integer | Calendar quarter (1-4) |
| F1_failure | binary | 1 if bank fails in next quarter, 0 otherwise |
| income_ratio | numeric | Net income / Total assets |
| noncore_ratio | numeric | (Total deposits - Core deposits) / Total assets |
| log_age | numeric | ln(bank age in years) |
| gdp_growth_3y | numeric | 3-year trailing GDP growth rate |
| inflation_3y | numeric | 3-year trailing CPI inflation rate |
| growth_cat | factor | Bank asset growth quintile (1-5) |

**Sample Characteristics**:
- Observations: 158,477
- Unique banks: 10,727
- Failures: 489 (0.31%)
- Time period: 2000Q1 - 2023Q4

---

## Data Availability

Due to licensing restrictions on the underlying FDIC Call Report data, the raw data files are not included in this repository. Researchers can:

1. **Request data directly from FDIC**: Contact the FDIC for access to Call Report data
2. **Use Correia replication package**: The underlying data comes from the Correia et al. (2025) replication files
3. **Download from FRED**: Macroeconomic variables are freely available at https://fred.stlouisfed.org/

---

## Filters Applied

The analysis dataset was created by applying the following filters:

1. **Temporal filter**: year >= 2000
2. **Post-failure exclusion**: Observations after a bank's failure date removed
3. **Charter class restrictions**: S&Ls and Savings Associations excluded
4. **TARP exclusion**: Banks receiving Troubled Asset Relief Program funds excluded

---

## Reproducing the Data

To reproduce the analysis data from raw FDIC files:

```r
# Run scripts in order
source("R/01_data_prep_2000.R")
```

This will create `data/processed/analysis_data_2000.rds` from the raw Call Report files.
