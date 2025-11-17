# Visualization Catalog - v10.2

**FailingBanks Replication Package**
**Date**: November 17, 2025
**Total Visualizations**: 20 (300 DPI PNG files)
**Color Scheme**: Tableau 10 Classic (standardized across all outputs)

---

## Table of Contents

1. [FDIC Bank Runs Analysis](#fdic-bank-runs-analysis) (2 visualizations)
2. [Assets Side Fundamentals](#assets-side-fundamentals) (3 visualizations)
3. [Liabilities Side Fundamentals](#liabilities-side-fundamentals) (3 visualizations)
4. [1937 Friedman Critique](#1937-friedman-critique) (1 visualization)
5. [Receivership Analysis](#receivership-analysis) (6 visualizations)
6. [Asset Growth Dynamics](#asset-growth-dynamics) (2 visualizations)
7. [Risk and Prediction Analysis](#risk-and-prediction-analysis) (3 visualizations from v10.1)

---

## FDIC Bank Runs Analysis

### 22. Bank Run Incidence Pre vs Post-FDIC
**File**: `22_bank_run_incidence_fdic.png`
**Script**: `code_expansion/22_bank_run_incidence_fdic.R`
**Data Source**: `deposits_before_failure_historical.dta` (1880-1933), `deposits_before_failure_modern.dta` (1993-2024)
**Key Finding**: Bank runs virtually eliminated after FDIC establishment (1934)
**Variables**: `run`, `year`, `growth_deposits`
**Visualization**: Line graph with FDIC establishment vertical marker
**Dimensions**: 12" × 8"

### 23. Deposit Outflow Dynamics by Era
**File**: `23_deposit_outflow_dynamics.png`
**Script**: `code_expansion/23_deposit_outflow_dynamics.R`
**Data Source**: Same as script 22
**Key Finding**: Pre-FDIC volatility vs post-FDIC stability in deposit dynamics
**Variables**: `growth_deposits`, `deposit_outflow`, `era`
**Visualization**: Violin + box plots by 5 eras
**Dimensions**: 14" × 9"

---

## Assets Side Fundamentals

### 24. Asset Growth - Failed vs Non-Failed Banks
**File**: `24_asset_growth_failed_vs_nonfailed.png`
**Script**: `code_expansion/24_asset_growth_failed_vs_nonfailed.R`
**Data Source**: `combined-data.rds` (N≈964,053)
**Key Finding**: Failed banks show excessive asset growth before failure across all periods
**Variables**: `growth`, `failed_bank`, period
**Visualization**: Grouped bar chart with 95% CI by 5 periods
**Dimensions**: 12" × 8"

### 25. Total Assets Evolution by Risk Quintile
**File**: `25_total_assets_risk_quintile.png`
**Script**: `code_expansion/25_total_assets_risk_quintile.R`
**Data Source**: `temp_reg_data.rds` (with predicted probabilities)
**Key Finding**: High-risk banks are smaller and more volatile
**Variables**: `assets`, `pred_prob_F1` (creates quintiles), `year`
**Visualization**: Multi-line time series (1863-2024), log scale
**Dimensions**: 12" × 8"

### 26. Loan Ratio & Liquidity - Failed vs Non-Failed
**File**: `26_loan_liquidity_failed_vs_nonfailed.png`
**Script**: `code_expansion/26_loan_liquidity_failed_vs_nonfailed.R`
**Data Source**: `combined-data.rds`
**Key Finding**: Failed banks have lower liquidity, higher loan concentration
**Variables**: `loan_ratio`, `liquid_ratio`, `failed_bank`, period
**Visualization**: Faceted bar charts (2 panels) with 95% CI
**Dimensions**: 12" × 10"

---

## Liabilities Side Fundamentals

### 27. Noncore Funding Ratio - Failed vs Non-Failed
**File**: `27_noncore_funding_failed_vs_nonfailed.png`
**Script**: `code_expansion/27_noncore_funding_failed_vs_nonfailed.R`
**Data Source**: `combined-data.rds`
**Key Finding**: Failed banks rely more on volatile noncore funding
**Variables**: `noncore_ratio`, `failed_bank`, period
**Visualization**: Grouped bar chart with 95% CI by 5 periods
**Dimensions**: 12" × 8"

### 28. Leverage Dynamics by Period
**File**: `28_leverage_dynamics_by_period.png`
**Script**: `code_expansion/28_leverage_dynamics_by_period.R`
**Data Source**: `combined-data.rds`
**Key Finding**: Failed banks are more leveraged (lower equity ratios) across all eras
**Variables**: `leverage` (equity/assets), `failed_bank`, period
**Visualization**: Line graph with ribbons (95% CI) by period
**Dimensions**: 12" × 8"

### 29. Deposit Structure Evolution
**File**: `29_deposit_structure_evolution.png`
**Script**: `code_expansion/29_deposit_structure_evolution.R`
**Data Source**: `combined-data.rds` (modern era: 1959-2024)
**Key Finding**: Failed banks show different deposit mix (more volatile time deposits)
**Variables**: `deposits`, `deposits_time` (demand vs time deposits)
**Visualization**: Stacked area chart, faceted by bank status
**Dimensions**: 12" × 10"

---

## 1937 Friedman Critique

### 30. 1937 Recession - Solvency vs Reserve Requirements
**File**: `30_1937_friedman_solvency_critique.png`
**Script**: `code_expansion/30_1937_friedman_solvency_critique.R`
**Data Source**: `combined-data.rds` filtered to 1936-1939
**Key Finding**: Failed banks had lower solvency BEFORE reserve requirement increases
**Key Argument**: Challenges Friedman & Schwartz's monetary explanation
**Variables**: `leverage`, `liquid_ratio`, `surplus_ratio`, `failed`, `year`
**Visualization**: Multi-panel time series (3 panels: leverage, liquidity, capital adequacy)
**Dimensions**: 12" × 12"

---

## Receivership Analysis

### 07. Recovery Rate Distribution by Era
**File**: `07_recovery_distribution_by_era.png`
**Script**: `code_expansion/07_recovery_distribution_by_era.R`
**Data Source**: `receivership_dataset_tmp.rds` (N≈2,961)
**Key Finding**: Recovery rates vary widely across eras
**Variables**: `dividends`, `era` (6 historical eras)
**Visualization**: Faceted density plots (6 panels)
**Dimensions**: 12" × 10"

### 08. Asset Quality vs Recovery Outcomes
**File**: `08_asset_quality_vs_recovery.png`
**Script**: `code_expansion/08_asset_quality_vs_recovery.R`
**Data Source**: `receivership_dataset_tmp.rds`
**Key Finding**: 0.69 correlation between "good" assets and collection rates
**Variables**: `share_good`, `share_collected`, `era`
**Visualization**: Scatter plot with regression line
**Dimensions**: 12" × 8"

### 09. Recovery Rates by Size Quintile
**File**: `09_recovery_by_size_quintile.png`
**Script**: `code_expansion/09_recovery_by_size_quintile.R`
**Data Source**: `receivership_dataset_tmp.rds`
**Key Finding**: Larger banks achieve higher recovery rates
**Variables**: `dividends`, `assets_at_suspension` (creates quintiles), `era`
**Visualization**: Grouped bar chart with 95% CI
**Dimensions**: 12" × 8"

### 11. Solvency Ratio vs Depositor Recovery
**File**: `11_solvency_vs_depositor_recovery.png`
**Script**: `code_expansion/11_solvency_vs_depositor_recovery.R`
**Data Source**: `receivership_dataset_tmp.rds`
**Key Finding**: Solvency ratio >1.0 predicts full recovery
**Variables**: `solvency_ratio` (collections/claims), `dividends`, `full_recov`
**Visualization**: Scatter plot with regression line + marginal histograms
**Dimensions**: 12" × 8"

### 31. Recovery Rates - Failed vs Non-Failed Comparison
**File**: `31_recovery_failed_vs_nonfailed.png`
**Script**: `code_expansion/31_recovery_failed_vs_nonfailed.R`
**Data Source**: `receivership_dataset_tmp.rds`
**Key Finding**: Failed banks recover less than non-failed banks retain (value destruction)
**Variables**: `dividends`, `era` (collapsed to 3 periods)
**Visualization**: Grouped bar chart: failed banks vs 100% retention
**Dimensions**: 12" × 8"

### 32. Recovery Rates Pre-FDIC vs Post-FDIC
**File**: `32_recovery_pre_post_fdic.png`
**Script**: `code_expansion/32_recovery_pre_post_fdic.R`
**Data Source**: `receivership_dataset_tmp.rds`
**Key Finding**: Modern FDIC era shows better recovery outcomes
**Variables**: `dividends`, FDIC era (pre/post 1934)
**Visualization**: Violin + box plots with statistical test
**Dimensions**: 12" × 8"

### 33. Post-Receivership Solvency Deterioration
**File**: `33_post_receivership_solvency_deterioration.png`
**Script**: `code_expansion/33_post_receivership_solvency_deterioration.R`
**Data Source**: `receivership_dataset_tmp.rds`
**Key Finding**: Asset quality at suspension strongly predicts recovery (reveals true solvency)
**Variables**: `share_good`, `share_doubtful`, `share_worthless`, `dividends`
**Visualization**: Scatter plot with regression line, colored by era
**Dimensions**: 12" × 8"

---

## Asset Growth Dynamics

### 34. Asset Growth by Decade (Last Call to Failure)
**File**: `34_asset_growth_by_decade.png`
**Script**: `code_expansion/34_asset_growth_by_decade.R`
**Data Source**: `combined-data.rds` (failed banks only)
**Key Finding**: Boom-bust pattern consistent across all decades (1860s-2020s)
**Variables**: `growth`, `year` (creates decade), `failed_bank`
**Visualization**: Box plots by decade
**Dimensions**: 14" × 9"

### 35. Asset Growth by Crisis Period
**File**: `35_asset_growth_by_crisis.png`
**Script**: `code_expansion/35_asset_growth_by_crisis.R`
**Data Source**: `combined-data.rds` (failed banks only)
**Key Finding**: Consistent boom-bust pattern across all major crises (120 years)
**Variables**: `growth`, crisis period (1893, 1907, Depression, S&L, GFC)
**Visualization**: Faceted line plots (5 panels) with ribbons (95% CI)
**Dimensions**: 14" × 10"

---

## Risk and Prediction Analysis

### 14. Funding Structure Evolution (1863-2024)
**File**: `14_funding_structure_evolution.png`
**Script**: `code_expansion/14_funding_structure_evolution.R`
**Data Source**: `combined-data.rds`
**Key Finding**: Deposits remain dominant, noncore grows in modern era
**Variables**: `deposit_ratio`, `noncore_ratio`, `leverage` (equity)
**Visualization**: Stacked area chart over 160 years
**Dimensions**: 12" × 8"

### 18. Great Depression Asset Composition
**File**: `18_great_depression_asset_composition.png`
**Script**: `code_expansion/18_great_depression_asset_composition.R`
**Data Source**: `receivership_dataset_tmp.rds`
**Key Finding**: Depression banks had 52.4% "doubtful" assets vs 39.2% pre-Depression
**Variables**: `share_good`, `share_doubtful`, `share_worthless`, era
**Visualization**: Stacked bar chart comparing Depression vs other eras
**Dimensions**: 12" × 8"

### Visualization Portfolio Summary (from v10.0)
Scripts 01-06 from v10.0 created the original 14 visualizations including:
- Risk multiplier visualizations (18x-25x finding)
- AUC progression and ROC curves
- Coefficient story panels
- Summary dashboard
- PowerPoint presentation (auto-generated, 10 slides)

---

## Color Scheme Standardization

All visualizations use the **Tableau 10 Classic** color palette for consistency:

- **Blue** (#1f77b4): Modern Era, Primary
- **Orange** (#ff7f0e): Historical, Pre-FDIC
- **Green** (#2ca02c): Success, Non-Failed, Low Risk
- **Red** (#d62728): Failure, Failed Banks, High Risk
- **Purple** (#9467bd): Great Depression
- **Brown** (#8c564b): National Banking Era
- **Pink** (#e377c2): Transitions
- **Gray** (#7f7f7f): Neutral, Reference
- **Yellow-Green** (#bcbd22): Early Fed/WWI
- **Cyan** (#17becf): Financial Crisis

**Standard Theme**: `theme_failing_banks()` ensures consistent styling across all outputs.

---

## Data Sources Reference

| File | Description | Observations | Coverage |
|------|-------------|--------------|----------|
| `combined-data.rds` | Main panel dataset | ~964,053 | 1863-2024 |
| `receivership_dataset_tmp.rds` | Failed bank receiverships | ~2,961 | 1863-2023 |
| `temp_reg_data.rds` | Regression subset with predictions | ~228k | Analysis sample |
| `deposits_before_failure_historical.dta` | Historical deposit outflows | ~14 years | 1880-1933 |
| `deposits_before_failure_modern.dta` | Modern deposit outflows | ~27 years | 1993-2024 |

---

## Usage

All visualization scripts are in `code_expansion/` and can be run independently:

```r
# Run individual visualization
source("code_expansion/22_bank_run_incidence_fdic.R")

# Or run all visualizations
scripts <- list.files("code_expansion", pattern = "^[0-9]{2}_.*\\.R$", full.names = TRUE)
lapply(scripts, source)
```

**Output Directory**: `code_expansion/presentation_outputs/`
**Format**: 300 DPI PNG files (print-ready)

---

## Version History

- **v10.0** (Nov 17, 2025): Initial 14 visualizations + PowerPoint presentation
- **v10.1** (Nov 17, 2025): Added 6 receivership visualizations (scripts 07-18)
- **v10.2** (Nov 17, 2025): Added 14 new visualizations (scripts 22-35) with Tableau color standardization

---

**For Questions**: See `PRESENTATION_GUIDE.md` for detailed interpretation guidance.
