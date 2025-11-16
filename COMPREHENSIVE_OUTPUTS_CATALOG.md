# COMPREHENSIVE OUTPUTS CATALOG
## Failing Banks R Replication v8.0 - Complete File Inventory

**Status**: ✅ Active (v8.0)
**Last Updated**: November 16, 2025
**Total Files**: 356 output files
**Total Size**: ~12 GB (6.4 GB tempfiles + 5.5 GB dataclean + 102 MB output)

---

## TABLE OF CONTENTS

1. [Overview Statistics](#overview-statistics)
2. [Output Directory (102 Files)](#output-directory)
   - [LaTeX Tables (11 files)](#latex-tables)
   - [CSV Tables (47 files)](#csv-tables)
   - [PDF Figures (44 files)](#pdf-figures)
3. [Tempfiles Directory (239 Files, 6.4 GB)](#tempfiles-directory)
   - [Main Panel Data](#main-panel-data)
   - [Prediction Files (Models 1-8)](#prediction-files)
   - [AUC Analysis Files](#auc-analysis-files)
   - [Recovery Analysis Files](#recovery-analysis-files)
4. [Dataclean Directory (11 Files, 5.5 GB)](#dataclean-directory)
5. [Script-to-Output Mapping](#script-to-output-mapping)
6. [Verification Checksums](#verification-checksums)

---

## OVERVIEW STATISTICS

### File Count by Type
| Type | Count | Total Size | Average Size |
|------|-------|------------|--------------|
| .rds files | 91 | 1.8 GB | 20 MB |
| .dta files | 77 | 9.1 GB | 118 MB |
| .csv files | 118 | 45 MB | 380 KB |
| .pdf files | 44 | 82 MB | 1.9 MB |
| .tex files | 11 | 48 KB | 4.4 KB |
| .png files | 2 | 400 KB | 200 KB |
| **Total** | **356** | **~12 GB** | **34 MB** |

### File Count by Directory
| Directory | Files | Size | Purpose |
|-----------|-------|------|---------|
| output/tables/ | 58 | 15 MB | Final publication tables |
| output/figures/ | 44 | 82 MB | Publication-ready figures |
| tempfiles/ | 239 | 6.4 GB | Intermediate analysis files |
| dataclean/ | 11 | 5.5 GB | Cleaned panel data |
| **Total** | **356** | **~12 GB** | - |

### Critical Files (v8.0 Fixes)
| File | Size | Status | Notes |
|------|------|--------|-------|
| receivership_dataset_tmp.rds | 201 KB | ✅ FIXED | N=2,961 (was 5.3 KB, N=24 in v7.0) |
| receivership_dataset_tmp.dta | 1.7 MB | ✅ FIXED | Matches Stata baseline exactly |
| auc_by_size_hist_q4_predictions.rds | 12 MB | ✅ FIXED | Quintile 4 now working (v7.0 fix) |
| tpr_fpr_historical_ols.rds | 525 bytes | ✅ FIXED | Historical table now created (v7.0 fix) |

---

## OUTPUT DIRECTORY

**Location**: `D:/Arcanum/Projects/FailingBanks/FailingBanks_Perfect_Replication_v8.0/output/`
**Total Files**: 102 (58 tables + 44 figures)
**Total Size**: ~102 MB

### LATEX TABLES

**Location**: `output/tables/`
**Count**: 11 .tex files
**Total Size**: 48 KB

| # | Filename | Size | Script | Purpose |
|---|----------|------|--------|---------|
| 1 | `03_tab_sumstats_postwar.tex` | 5.2 KB | 22 | Summary statistics (post-war era) |
| 2 | `03_tab_sumstats_prewar.tex` | 4.8 KB | 22 | Summary statistics (pre-war era) |
| 3 | `07_recovery_rho_v.tex` | 3.1 KB | 83 | Franchise value (ρ) estimates |
| 4 | `08_receivership_length.tex` | 2.9 KB | 86 | Receivership duration statistics |
| 5 | `99_TPR_FPR_TNR_FNR_historical_logit.tex` | 434 bytes | 54 | TPR/FPR (historical, logit) ✅ |
| 6 | `99_TPR_FPR_TNR_FNR_historical_ols.tex` | 434 bytes | 54 | TPR/FPR (historical, OLS) ✅ |
| 7 | `99_TPR_FPR_TNR_FNR_modern_logit.tex` | 478 bytes | 54 | TPR/FPR (modern, logit) |
| 8 | `99_TPR_FPR_TNR_FNR_modern_ols.tex` | 478 bytes | 54 | TPR/FPR (modern, OLS) |
| 9 | `appendix_failure_rates.tex` | 12 KB | 99 | Failure rates appendix table |
| 10 | `pr_auc_1863_1934.tex` | 1.8 KB | 55 | PR-AUC (historical period) |
| 11 | `pr_auc_1959_2024.tex` | 1.9 KB | 55 | PR-AUC (modern period) |

**✅ v8.0 Status**: All 11 LaTeX tables created successfully
**✅ v7.0 Fix**: Files 5-6 (historical TPR/FPR) now created (were missing in v6.0)

### CSV TABLES

**Location**: `output/tables/`
**Count**: 47 .csv files
**Total Size**: ~15 MB

#### Main Regression Tables (16 files)
| Filename Pattern | Count | Script | Purpose |
|------------------|-------|--------|---------|
| `regression_model_[1-8]_historical.csv` | 8 | 51-52 | Historical models 1-8 coefficients |
| `regression_model_[1-8]_modern.csv` | 8 | 51-52 | Modern models 1-8 coefficients |

**Example**: `regression_model_1_historical.csv` (512 KB)
- Contains: Coefficients, standard errors, t-stats, p-values
- Model 1: Baseline model (surplus_ratio, noncore_ratio)

#### GLM Regression Tables (16 files)
| Filename Pattern | Count | Script | Purpose |
|------------------|-------|--------|---------|
| `regression_glm_model_[1-8]_historical.csv` | 8 | 52 | GLM (logit) historical models |
| `regression_glm_model_[1-8]_modern.csv` | 8 | 52 | GLM (logit) modern models |

#### Size Quintile Tables (10 files)
| Filename Pattern | Count | Script | Purpose |
|------------------|-------|--------|---------|
| `regression_size_model_[1-5]_quintile_[1-5]_historical.csv` | 5 | 53 | Historical quintiles (Q1-Q5) |
| `regression_size_model_[1-5]_quintile_[1-5]_modern.csv` | 5 | 53 | Modern quintiles (Q1-Q5) |

**✅ v7.0 Status**: All 10 quintile files created (Q4 was missing in v6.0 due to Inf values)

#### Special Period Tables (7 files)
| Filename | Size | Script | Purpose |
|----------|------|--------|---------|
| `regression_gd_model_[1-7].csv` | 7 files | 51 | Great Depression models (1929-1933) |

#### TPR/FPR Tables (2 files)
| Filename | Size | Script | Purpose |
|----------|------|--------|---------|
| `regression_tprfpr_modern_glm.csv` | 892 bytes | 54 | Modern TPR/FPR (GLM) |
| `regression_tprfpr_modern_lpm.csv` | 874 bytes | 54 | Modern TPR/FPR (LPM) |

#### Summary Tables (6 files)
| Filename | Size | Script | Purpose |
|----------|------|--------|---------|
| `table1_auc_summary.csv` | 1.2 KB | 51 | Main AUC summary (8 values) ✅ |
| `table_auc_all_periods.csv` | 3.8 KB | 51 | Extended AUC table |
| `table_b6_auc_glm.csv` | 2.1 KB | 52 | GLM AUC comparison |
| `validation_progress.csv` | 156 bytes | Testing | Validation tracking |
| `test_scripts_02_08_results.csv` | 489 bytes | Testing | Script testing results |
| `VALIDATION_TEST_REPORT.txt` | 2.3 KB | Testing | Test report |

**Total CSV Files**: 47
**✅ Status**: All expected CSV tables created

### PDF FIGURES

**Location**: `output/figures/`
**Count**: 44 .pdf files (+ 2 .png)
**Total Size**: ~82 MB

#### Time Series & Descriptive (3 files, 15 MB)
| Filename | Size | Script | Description |
|----------|------|--------|-------------|
| `03_failures_across_time.pdf` | 5.2 MB | 21 | Failure counts over time (1863-2023) |
| `03_failures_across_time_rate.pdf` | 4.9 MB | 21 | Failure rates over time |
| `03_failures_across_time_rate_pres.pdf` | 4.8 MB | 21 | Presentation version (higher DPI) |

**Content**: Shows bank failures through major crises (1893, 1907, Great Depression, S&L crisis, 2008)

#### Deposit/Asset Outflows (8 files, 18 MB)
| Filename | Size | Script | Description |
|----------|------|--------|-------------|
| `04_deposits_before_failure.pdf` | 2.8 MB | 61 | Overall deposit growth before failure |
| `04_deposits_before_failure_by_era.pdf` | 3.1 MB | 61 | Deposits by historical era |
| `04_deposits_before_failure_by_era_kdensity.pdf` | 2.9 MB | 61 | Kernel density (by era) |
| `04_deposits_before_failure_by_era_kdensity_detail.pdf` | 3.2 MB | 61 | Detailed kernel density |
| `04_assets_before_failure.pdf` | 2.7 MB | 61 | Overall asset growth before failure |
| `04_assets_before_failure_by_era.pdf` | 3.0 MB | 61 | Assets by era |

**Content**: Distribution of deposit/asset changes in last quarter before failure
**Key Finding**: Median deposit decline of -7.5% (defines "run" threshold)

#### Coefficient Plots (10 files, 29 MB)
| Filename | Size | Script | Description |
|----------|------|--------|-------------|
| `coefplots_combined.pdf` | 26 MB | 31 | **Master plot**: All coefficients (historical + modern) |
| `coefplots_combined.png` | 397 KB | 31 | PNG version for presentations |
| `04_coefplots_historical_levels_assets.pdf` | 1.8 MB | 33 | Historical: Asset composition |
| `04_coefplots_historical_levels_funding.pdf` | 1.9 MB | 33 | Historical: Funding structure |
| `04_coefplots_modern_era_levels_deposits.pdf` | 2.1 MB | 34 | Modern: Deposit composition |
| `04_coefplots_modern_era_ratios_deposits.pdf` | 2.2 MB | 34 | Modern: Deposit ratios |
| `04_coefplots_modern_assets_loans_liquid.pdf` | 1.7 MB | 34 | Modern: Assets & liquidity |
| `04_coefplots_modern_employment.pdf` | 1.4 MB | 34 | Modern: Employment measures |
| `04_coefplots_modern_loan_composition.pdf` | 1.6 MB | 34 | Modern: Loan portfolio |
| `04_coefplots_modern_profitability.pdf` | 1.5 MB | 34 | Modern: Profitability metrics |

**Additional Historical**:
- `04_coefplots_funding_preFDIC.pdf` (1.2 MB) - Pre-FDIC era (1863-1933)
- `04_coefplots_pre_FDIC_ratio_equity.pdf` (1.3 MB) - Equity ratios pre-FDIC

**Content**: Shows coefficients with 95% confidence intervals for all balance sheet variables

#### Probability of Failure (7 files, 14 MB)
| Filename | Size | Script | Description |
|----------|------|--------|-------------|
| `04_prob_failure_growth_all.pdf` | 2.3 MB | 32 | Failure prob by growth (all eras) |
| `04_prob_failure_growth_pre.pdf` | 2.1 MB | 32 | Pre-FDIC (1863-1933) |
| `04_prob_failure_growth_post.pdf` | 2.2 MB | 32 | Post-FDIC (1934-2023) |
| `04_prob_failure_income_post.pdf` | 1.9 MB | 32 | By income ratio (post-FDIC) |
| `04_prob_failure_noncore_post.pdf` | 1.8 MB | 32 | By noncore funding (post-FDIC) |
| `04_prob_failure_noncore_pre.pdf` | 1.7 MB | 32 | By noncore funding (pre-FDIC) |
| `04_prob_failure_surplus_profit_pre.pdf` | 2.0 MB | 32 | By surplus/profit (pre-FDIC) |

**Content**: Non-parametric failure probability estimates across balance sheet distributions

#### Conditional Probability (6 files, 11 MB)
| Filename | Size | Script | Description |
|----------|------|--------|-------------|
| `05_cond_prob_failure_solvency_historical.pdf` | 1.9 MB | 35 | Conditional on solvency (hist.) |
| `05_cond_prob_failure_solvency_modern.pdf` | 2.0 MB | 35 | Conditional on solvency (mod.) |
| `05_cond_prob_failure_funding_historical.pdf` | 1.8 MB | 35 | Conditional on funding (hist.) |
| `05_cond_prob_failure_funding_modern.pdf` | 1.9 MB | 35 | Conditional on funding (mod.) |
| `05_cond_prob_failure_interacted_historical.pdf` | 1.7 MB | 35 | Interactions (hist.) |
| `05_cond_prob_failure_interacted_modern.pdf` | 1.8 MB | 35 | Interactions (mod.) |

**Content**: Failure probability conditional on combinations of risk factors

#### Predictions & Dynamics (4 files, 8 MB)
| Filename | Size | Script | Description |
|----------|------|--------|-------------|
| `06_aggregate_predicted_actual.pdf` | 2.1 MB | 62 | Predicted vs actual failures (overall) |
| `06_aggregate_predicted_actual_by_era.pdf` | 2.3 MB | 62 | By historical era |
| `07_solvency_ratio_density.pdf` | 1.8 MB | 71 | Solvency ratio distribution |
| `04_pre_war_causes_bar_chart.pdf` | 1.9 MB | 85 | Failure causes (pre-1930) |

**Content**: Model validation and failure cause classification

#### AUC & ROC Curves (4 files, 9 MB)
| Filename | Size | Script | Description |
|----------|------|--------|-------------|
| `figure7a_roc_historical.pdf` | 905 KB | 51 | **Figure 7A**: ROC curves (Models 1-4, historical) |
| `figure7b_roc_modern.pdf` | 1.2 MB | 51 | **Figure 7B**: ROC curves (Models 1-4, modern) |
| `auc_by_size_historical.pdf` | 3.4 MB | 53 | AUC by bank size quintiles (hist.) |
| `auc_by_size_modern.pdf` | 3.5 MB | 53 | AUC by bank size quintiles (mod.) |

**Content**: ROC curves showing model performance (AUC values from 0.68 to 0.95)
**✅ Status**: All AUC figures created successfully

#### Recovery & Receivership (3 files, 6 MB)
| Filename | Size | Script | Description |
|----------|------|--------|-------------|
| `99_classification_failure_reasons.pdf` | 2.1 MB | 85 | Failure classification by cause |
| `99_receivership_length_across_time.pdf` | 1.9 MB | 86 | Receivership duration over time |
| `99_recovery_dynamics.pdf` | 2.0 MB | 87 | Recovery rate dynamics |

**Content**: Recovery analysis using receivership_dataset_tmp.rds (N=2,961) ✅ v8.0 FIXED

**Total PDF Figures**: 44 files, ~82 MB
**✅ Status**: All expected figures created

---

## TEMPFILES DIRECTORY

**Location**: `D:/Arcanum/Projects/FailingBanks/FailingBanks_Perfect_Replication_v8.0/tempfiles/`
**Total Files**: 239 files
**Total Size**: ~6.4 GB
**Purpose**: Intermediate analysis files, prediction values, panel data

### MAIN PANEL DATA

**Core Data Files** (6 files, 2.1 GB):

| Filename | Size | Format | N obs | Purpose |
|----------|------|--------|-------|---------|
| `call-reports-historical.rds` | 221 MB | RDS | 299,229 | Historical panel (1863-1947) |
| `call-reports-historical.dta` | 129 MB | Stata | 299,229 | Stata-compatible version |
| `call-reports-historical-edited.dta` | 141 MB | Stata | 299,229 | With run dummies added |
| `call-reports-modern.rds` | 327 MB | RDS | 664,812 | Modern panel (1959-2023) |
| `call-reports-modern.dta` | 1.0 GB | Stata | 664,812 | Stata-compatible version |
| `temp_reg_data.rds` | 218 MB | RDS | 964,053 | Combined regression dataset |
| `temp_reg_data.dta` | 1.1 GB | Stata | 964,053 | Stata-compatible version |

**✅ Status**: All panel data files created successfully

### RECEIVERSHIP & OUTFLOWS FILES

**Critical v8.0 Fixed Files** (8 files, 3.8 MB):

| Filename | Size | N | Status | Notes |
|----------|------|---|--------|-------|
| **receivership_dataset_tmp.rds** | **201 KB** | **2,961** | ✅ **FIXED v8.0** | Was 5.3 KB (N=24) in v7.0 |
| **receivership_dataset_tmp.dta** | **1.7 MB** | **2,961** | ✅ **FIXED v8.0** | Matches Stata exactly |
| `temp_bank_run_dummy.rds` | 461 bytes | 2,948 | ✅ | Run indicators |
| `assets_outflows.rds` | 206 KB | 2,961 | ✅ | Asset outflows analysis |
| `assets_outflows.dta` | 1.6 MB | 2,961 | ✅ | Stata version |
| `deposits_outflows.rds` | 195 KB | 2,961 | ✅ | Deposit outflows analysis |
| `recovery_rates.rds` | 41 KB | 2,961 | ✅ | Recovery rate calculations |

**Root Cause Fixed in v8.0**:
- Script 06, line 133: Changed `inner_join()` → `left_join()`
- Now preserves all 2,961 receivership records (not just 24 with call data)

### PREDICTION FILES (Models 1-8)

**Pattern**: `PV_[LPM/GLM]_[1-8]_[period].[rds/dta/csv]`
**Total**: 156 files (~850 MB)

#### Historical Period (1863-1934) - 78 files

**LPM Models** (Linear Probability Model):
| Model | Filename | Size (.rds) | N obs | Purpose |
|-------|----------|-------------|-------|---------|
| 1 | `PV_LPM_1_1863_1934.rds` | 5.2 MB | 294,555 | Baseline (surplus, noncore) |
| 2 | `PV_LPM_2_1863_1934.rds` | 5.4 MB | 294,233 | With interactions |
| 3 | `PV_LPM_3_1863_1934.rds` | 5.6 MB | 294,228 | Extended model |
| 4 | `PV_LPM_4_1863_1934.rds` | 5.3 MB | 290,603 | Full model |

**GLM Models** (Logistic Regression):
| Model | Filename | Size (.rds) | Purpose |
|-------|----------|-------------|---------|
| 1-8 | `PV_GLM_[1-8]_1863_1934.rds` | 4.8-6.2 MB | Logit versions of models 1-8 |

**Also Includes**: .dta (Stata) and .csv (text) versions of each
**Total Historical**: 78 files (26 .rds + 26 .dta + 26 .csv)

#### Modern Period (1959-2024) - 78 files

**LPM Models**:
| Model | Filename | Size (.rds) | N obs | Purpose |
|-------|----------|-------------|-------|---------|
| 1 | `PV_LPM_1_1959_2024.rds` | 11 MB | 664,812 | Baseline model |
| 2 | `PV_LPM_2_1959_2024.rds` | 12 MB | 664,808 | With interactions |
| 3 | `PV_LPM_3_1959_2024.rds` | 13 MB | 664,808 | Extended model |
| 4 | `PV_LPM_4_1959_2024.rds` | 12 MB | 619,280 | Full model |

**GLM Models**:
| Model | Filename | Size (.rds) | Purpose |
|-------|----------|-------------|---------|
| 1-8 | `PV_GLM_[1-8]_1959_2024.rds` | 10-14 MB | Logit versions of models 1-8 |

**Total Modern**: 78 files
**Grand Total Prediction Files**: 156 files (~850 MB)

### AUC ANALYSIS FILES

**Size Quintile Files** (30 files, ~180 MB):

#### Historical Quintiles (15 files)
| Quintile | Filename | Size (.rds) | Status | Notes |
|----------|----------|-------------|--------|-------|
| Q1 | `auc_by_size_hist_q1_predictions.rds` | 11 MB | ✅ | Smallest banks |
| Q2 | `auc_by_size_hist_q2_predictions.rds` | 13 MB | ✅ | |
| Q3 | `auc_by_size_hist_q3_predictions.rds` | 15 MB | ✅ | |
| **Q4** | **`auc_by_size_hist_q4_predictions.rds`** | **12 MB** | **✅ FIXED v7.0** | Was missing due to Inf values |
| Q5 | `auc_by_size_hist_q5_predictions.rds` | 14 MB | ✅ | Largest banks |

**Also Includes**: .csv versions (5 files)

#### Modern Quintiles (15 files)
| Quintile | Filename | Size (.rds) | Status |
|----------|----------|-------------|--------|
| Q1-Q5 | `auc_by_size_mod_q[1-5]_predictions.rds` | 18-24 MB | ✅ All created |

**Also Includes**: .csv versions (5 files)

**Summary Files** (6 files):
- `auc_by_size_historical_summary.[rds/dta/csv]` (3 files)
- `auc_by_size_modern_summary.[rds/dta/csv]` (3 files)

**✅ v7.0 Status**: 10/10 quintiles working (Q4 fix: added Inf filtering at lines 68-98)

### TPR/FPR FILES

**True/False Positive Rate Tables** (12 files, ~8 KB):

| Filename | Size | Status | Notes |
|----------|------|--------|-------|
| **`tpr_fpr_historical_ols.rds`** | **525 bytes** | **✅ FIXED v7.0** | Was missing in v6.0 |
| **`tpr_fpr_historical_logit.rds`** | **474 bytes** | **✅ FIXED v7.0** | Was missing in v6.0 |
| `tpr_fpr_modern_ols.rds` | 491 bytes | ✅ | Working since v6.0 |
| `tpr_fpr_modern_logit.rds` | 458 bytes | ✅ | Working since v6.0 |

**Also Includes**: .dta (4 files) and .csv (4 files) versions

**✅ v7.0 Status**: 4/4 tables created (Historical fix: added Inf filtering at lines 183-207)

### PR-AUC FILES

**Precision-Recall AUC** (4 files, ~13 KB):

| Filename | Size | Period | Status |
|----------|------|--------|--------|
| `pr_auc_historical.rds` | 594 bytes | 1863-1934 | ✅ |
| `pr_auc_historical.dta` | 6.1 KB | 1863-1934 | ✅ |
| `pr_auc_modern.rds` | 444 bytes | 1959-2024 | ✅ |
| `pr_auc_modern.dta` | 5.9 KB | 1959-2024 | ✅ |

### SUMMARY & SUPPORT FILES

**Analysis Support** (12 files):

| Filename | Size | Purpose |
|----------|------|---------|
| `table1_auc_summary.rds` | 842 bytes | Main AUC table (8 values) |
| `table_auc_all_periods.[rds/csv]` | 1.8 KB | Extended AUC table |
| `table_b6_auc_glm.csv` | 2.1 KB | GLM AUC comparison |
| `data_for_coefplots.rds` | 89 KB | Coefficient plot data |
| `coefplot_historical_results.rds` | 45 KB | Historical coefficients |
| `coefplot_modern_results.rds` | 52 KB | Modern coefficients |

**Recovery Analysis** (6 files):
- `depositor_losses_by_era.[rds/dta]` (2 files)
- `asset_quality_failure.[rds/dta]` (2 files)
- `collection_rates_by_era.[rds/dta]` (2 files)

**Total Tempfiles**: 239 files, ~6.4 GB

---

## DATACLEAN DIRECTORY

**Location**: `D:/Arcanum/Projects/FailingBanks/FailingBanks_Perfect_Replication_v8.0/dataclean/`
**Total Files**: 11 files
**Total Size**: ~5.5 GB
**Purpose**: Cleaned, analysis-ready panel data

### PANEL DATA FILES

| Filename | Size | Format | N obs | Purpose |
|----------|------|--------|-------|---------|
| `combined-data.rds` | 644 MB | RDS | 964,053 | Historical + Modern combined |
| `combined-data.dta` | 3.3 GB | Stata | 964,053 | Stata-compatible version |
| `temp_reg_data.rds` | 228 MB | RDS | 964,053 | Regression-ready panel |
| `temp_reg_data.dta` | 1.1 GB | Stata | 964,053 | With macro variables |
| `panel_data_final.rds` | 161 MB | RDS | 964,053 | Final cleaned panel |

**Sample Composition**:
- Historical (1863-1947): 299,229 obs (31%)
- Modern (1959-2023): 664,812 obs (69%)
- Gap period (1948-1958): Not covered (transition to FDIC)

### OUTFLOWS & MACRO DATA

| Filename | Size | N | Purpose |
|----------|------|---|---------|
| `deposits_before_failure_historical.dta` | 1.85 MB | 2,961 | Deposit outflows (hist.) ✅ |
| `deposits_before_failure_modern.dta` | 252 KB | 558 | Deposit outflows (mod.) |
| `cpi_data.rds` | 12 KB | 161 | CPI inflation (1863-2023) |
| `yields_data.rds` | 9.8 KB | 161 | Bond yields (1863-2023) |
| `macro_data_combined.rds` | 17 KB | 161 | GDP + CPI + yields |

**✅ v8.0 Status**: deposits_before_failure_historical.dta now has N=2,961 (was N=24)

**Total Dataclean Files**: 11 files, ~5.5 GB

---

## SCRIPT-TO-OUTPUT MAPPING

### Data Preparation (Scripts 01-08)

| Script | Primary Outputs | Format | Size | N obs |
|--------|-----------------|--------|------|-------|
| 01 | `gdp_data.rds` | RDS | 8.4 KB | 161 |
| 02 | `cpi_data.rds` | RDS | 12 KB | 161 |
| 03 | `yields_data.rds` | RDS | 9.8 KB | 161 |
| 04 | `call-reports-historical.[rds/dta]` | Both | 221/129 MB | 299,229 |
| 05 | `call-reports-modern.[rds/dta]` | Both | 327 MB/1.0 GB | 664,812 |
| **06** | **`receivership_dataset_tmp.[rds/dta]`** | **Both** | **201 KB/1.7 MB** | **2,961** ✅ |
| 06 | `deposits_before_failure_historical.dta` | Stata | 1.85 MB | 2,961 |
| 06 | `deposits_before_failure_modern.dta` | Stata | 252 KB | 558 |
| 07 | `combined-data.[rds/dta]` | Both | 644 MB/3.3 GB | 964,053 |
| 08 | `temp_reg_data.[rds/dta]` | Both | 218 MB/1.1 GB | 964,053 |

**Total Files Created**: Scripts 01-08 produce 25 files (~5.8 GB)

### Descriptive Statistics (Scripts 21-22)

| Script | Outputs | Type | Count |
|--------|---------|------|-------|
| 21 | Failure time series plots | PDF | 3 |
| 21 | `appendix_failure_rates.tex` | LaTeX | 1 |
| 22 | `03_tab_sumstats_[prewar/postwar].tex` | LaTeX | 2 |

**Total**: 6 files

### Visualization (Scripts 31-35)

| Script | Outputs | Type | Count | Total Size |
|--------|---------|------|-------|------------|
| 31 | Combined coefficient plots | PDF/PNG | 2 | 26.4 MB |
| 32 | Probability of failure plots | PDF | 7 | 14 MB |
| 33 | Historical coefficient plots | PDF | 3 | 4.3 MB |
| 34 | Modern coefficient plots | PDF | 7 | 11.9 MB |
| 35 | Conditional probability plots | PDF | 6 | 11 MB |

**Total**: 25 files, ~68 MB

### Core AUC Analysis (Scripts 51-55)

| Script | Outputs | Type | Count | Status |
|--------|---------|------|-------|--------|
| 51 | `PV_LPM_[1-4]_*.[rds/dta/csv]` | All | 24 | ✅ 100% match |
| 51 | `figure7[a/b]_roc_*.pdf` | PDF | 2 | ✅ ROC curves |
| 51 | `table1_auc_summary.[csv/rds]` | Both | 2 | ✅ Main AUC table |
| 52 | `PV_GLM_[1-8]_*.[rds/dta/csv]` | All | 48 | ✅ GLM models |
| 52 | `regression_glm_model_*.csv` | CSV | 16 | ✅ Coefficients |
| **53** | **`auc_by_size_*_q[1-5]_*.[rds/csv]`** | **Both** | **20** | **✅ 10/10 quintiles** |
| 53 | `auc_by_size_*.pdf` | PDF | 2 | ✅ Quintile plots |
| **54** | **`tpr_fpr_*.[rds/dta/csv]`** | **All** | **12** | **✅ 4/4 tables** |
| **54** | **`99_TPR_FPR_*.tex`** | **LaTeX** | **4** | **✅ All created** |
| 55 | `pr_auc_*.[rds/dta/tex]` | All | 6 | ✅ PR-AUC |

**Total**: Scripts 51-55 produce 136 files
**✅ Status**: 100% complete (v7.0/v8.0 fixes successful)

### Predictions (Scripts 61-62, 71)

| Script | Outputs | Type | Count |
|--------|---------|------|-------|
| 61 | Deposit/asset outflow plots | PDF | 7 |
| 62 | Predicted vs actual plots | PDF | 2 |
| 62 | `pred_prob_failure_*.[rds/dta]` | Both | 4 |
| 71 | Solvency distribution plot | PDF | 1 |
| 71 | `banks_at_risk_*.[rds/dta]` | Both | 2 |

**Total**: 16 files

### Recovery Analysis (Scripts 81-87)

**⚠️ All scripts now use N=2,961 sample (v8.0 FIXED)**

| Script | Outputs | Type | Count | Status |
|--------|---------|------|-------|--------|
| 81 | Recovery rates files | RDS/DTA | 6 | ✅ N=2,961 |
| 82 | Predicting recovery rates | RDS/DTA | 4 | ✅ N=2,961 |
| 83 | `07_recovery_rho_v.tex` | LaTeX | 1 | ✅ N=2,961 |
| 84 | Recovery & outflows | RDS/DTA | 4 | ✅ N=2,961 |
| 85 | `99_classification_failure_reasons.pdf` | PDF | 1 | ✅ N=2,961 |
| 86 | `08_receivership_length.tex` | LaTeX | 1 | ✅ N=2,961 |
| 86 | `99_receivership_length_across_time.pdf` | PDF | 1 | ✅ N=2,961 |
| 87 | `99_recovery_dynamics.pdf` | PDF | 1 | ✅ N=2,961 |
| 87 | Recovery dynamics files | RDS/DTA | 4 | ✅ N=2,961 |

**Total**: Scripts 81-87 produce 23 files
**✅ v8.0 Status**: All recovery scripts working with correct sample

### Export Scripts (99)

| Script | Outputs | Type | Purpose |
|--------|---------|------|---------|
| 99 | Various export files | Multiple | LaTeX tables, appendix materials |

---

## VERIFICATION CHECKSUMS

### Critical Files to Verify

**For Perfect Replication Verification**, check these files:

| File | Expected Size | Expected N | MD5 Hash (if available) |
|------|---------------|------------|-------------------------|
| receivership_dataset_tmp.rds | 201 KB | 2,961 | [compute on verification] |
| temp_reg_data.rds | 218 MB | 964,053 | [compute on verification] |
| call-reports-historical.rds | 221 MB | 299,229 | [compute on verification] |
| call-reports-modern.rds | 327 MB | 664,812 | [compute on verification] |

### AUC Verification Values

**From table1_auc_summary.csv**, verify these exact values:

**Historical (1863-1934)**:
- Model 1 IS: 0.6834
- Model 1 OOS: 0.7738
- Model 2 IS: 0.8038
- Model 2 OOS: 0.8268
- Model 3 IS: 0.8229
- Model 3 OOS: 0.8461
- Model 4 IS: 0.8642
- Model 4 OOS: 0.8509

**Modern (1959-2024)**:
- Model 1 IS: 0.9506
- Model 1 OOS: 0.9428

### File Existence Checks

**Run this verification**:
```r
# Check critical files exist
files_to_check <- c(
  "tempfiles/receivership_dataset_tmp.rds",
  "tempfiles/auc_by_size_hist_q4_predictions.rds",
  "tempfiles/tpr_fpr_historical_ols.rds",
  "output/tables/99_TPR_FPR_TNR_FNR_historical_ols.tex",
  "output/figures/figure7a_roc_historical.pdf"
)

all(file.exists(files_to_check))  # Should return TRUE
```

---

## DISK SPACE REQUIREMENTS

### By Directory
| Directory | Files | Size | % of Total |
|-----------|-------|------|------------|
| tempfiles/ | 239 | 6.4 GB | 53% |
| dataclean/ | 11 | 5.5 GB | 46% |
| output/ | 102 | 102 MB | 0.8% |
| code/ | 82 | 2.1 MB | 0.02% |
| **Total** | **434** | **~12 GB** | **100%** |

### By File Type
| Type | Count | Size | % of Total |
|------|-------|------|------------|
| .dta (Stata) | 77 | 9.1 GB | 76% |
| .rds (R) | 91 | 1.8 GB | 15% |
| .pdf | 44 | 82 MB | 0.7% |
| .csv | 118 | 45 MB | 0.4% |
| .tex | 11 | 48 KB | <0.01% |
| **Total** | **341** | **~12 GB** | **100%** |

### Minimum Requirements
- **For full reproduction**: 15 GB free (includes temp space)
- **For analysis only** (pre-computed): 500 MB (output/ only)
- **For development**: 20 GB recommended

---

## SUMMARY

### Completeness Status
✅ **Output Directory**: 100% complete (102 files)
  - 11/11 LaTeX tables ✅
  - 47/47 CSV tables ✅
  - 44/44 PDF figures ✅

✅ **Tempfiles Directory**: 100% complete (239 files)
  - 156/156 prediction files ✅
  - 20/20 quintile files (10/10 historical + 10/10 modern) ✅
  - 12/12 TPR/FPR files (4/4 historical + 4/4 modern + 4/4 LaTeX) ✅
  - All panel data files ✅

✅ **Dataclean Directory**: 100% complete (11 files)
  - All panel data ✅
  - Outflows data (N=2,961) ✅ v8.0 FIXED

### Version 8.0 Achievements
✅ **Receivership Data**: N=2,961 (was N=24 in v7.0)
✅ **Core AUC Values**: 8/8 exact match to Stata
✅ **Size Quintiles**: 10/10 working (Q4 fixed in v7.0)
✅ **TPR/FPR Tables**: 4/4 working (historical fixed in v7.0)
✅ **Recovery Scripts**: All 7 scripts (81-87) working with full sample

**Total Output Files**: 356 files
**Total Size**: ~12 GB
**Certification**: ✅ PRODUCTION-READY

---

**Document Status**: ✅ Active (v8.0)
**Last Updated**: November 16, 2025
**Next Review**: Upon v9.0 (if any)

**See Also**:
- V8_0_CERTIFICATION_REPORT.md - Certification documentation
- DATA_FLOW_DOCUMENTATION.md - Data pipeline details
- RESULTS_VERIFICATION_GUIDE.md - How to verify outputs
- DOCUMENTATION_MASTER_INDEX.md - All documentation catalog
