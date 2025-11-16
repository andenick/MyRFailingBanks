# R-Stata Perfect Replication Verification Findings
**Date**: 2025-11-15
**Status**: IN PROGRESS - Systematic Verification Phase

---

## Executive Summary

Initial verification reveals **3 CRITICAL DISCREPANCIES** that must be fixed to achieve perfect replication:

1. ❌ **Script 53**: Historical Quintile 4 missing (9/10 quintiles = 90% complete)
2. ❌ **Script 54**: Historical TPR/FPR tables missing (2/4 tables = 50% complete)
3. ❌ **Scripts 81-87**: Receivership data N=24 instead of N=2,961 (0.8% of expected sample)

---

## Detailed Findings by Category

### **DATA PREPARATION (Scripts 01-08)**

| Script | Status | Finding |
|--------|--------|---------|
| 01-03 | ⚠️ Cannot verify | Scripts error without setup file, but outputs exist from previous runs |
| 04-05 | ✅ Assumed OK | Panel data file exists (218MB), used by all downstream scripts successfully |
| 06 | ⚠️ Needs investigation | Creates receivership files but sample size unknown |
| 06b | ❌ **CRITICAL ISSUE** | Creates receivership_dataset_tmp.rds with N=24 instead of N=2,961 |
| 07 | ✅ Assumed OK | Panel combination works (downstream scripts use it) |
| 08 | ✅ Assumed OK | temp_reg_data.rds exists and is used by all analysis scripts |

**Action Required**: Investigate Script 06/06b to fix receivership sample size.

---

### **ANALYSIS OUTPUTS VERIFICATION**

####  Script 53: AUC by Size Quintiles

**Stata Baseline**: 10 quintile files expected (5 historical + 5 modern)

**R Output Files Found**:
- ✅ `auc_by_size_hist_q1_predictions.rds`
- ✅ `auc_by_size_hist_q2_predictions.rds`
- ✅ `auc_by_size_hist_q3_predictions.rds`
- ❌ `auc_by_size_hist_q4_predictions.rds` **MISSING**
- ✅ `auc_by_size_hist_q5_predictions.rds`
- ✅ `auc_by_size_mod_q1_predictions.rds`
- ✅ `auc_by_size_mod_q2_predictions.rds`
- ✅ `auc_by_size_mod_q3_predictions.rds`
- ✅ `auc_by_size_mod_q4_predictions.rds`
- ✅ `auc_by_size_mod_q5_predictions.rds`

**Result**: 9/10 files (90% complete)

**Root Cause**: Historical Q4 contains Inf values in leverage ratios that crash R's lm() function

**Fix Required**: Add Inf value preprocessing before lm() call in Script 53

---

#### Script 54: TPR/FPR Analysis

**Stata Baseline**: 4 LaTeX tables expected

**R Output Files Found**:
- ❌ `99_TPR_FPR_TNR_FNR_historical_ols.tex` **MISSING**
- ❌ `99_TPR_FPR_TNR_FNR_historical_logit.tex` **MISSING**
- ✅ `99_TPR_FPR_TNR_FNR_modern_ols.tex`
- ✅ `99_TPR_FPR_TNR_FNR_modern_logit.tex`

**Result**: 2/4 tables (50% complete)

**Root Cause**: Historical output sections are commented out in R code (lines 555-585, 664-676, 696-702)

**Fix Required**:
1. Add Inf value preprocessing (similar to fix being applied now)
2. Uncomment historical output sections
3. Fix syntax error on line 672 (duplicate `#`)

---

#### Scripts 81-87: Recovery Analysis

**Stata Baseline Sample Sizes**:
- Script 81: N=44 observations
- Script 84: N=413 observations
- Script 86: N=196 observations

**R Actual Sample Sizes**:
- receivership_dataset_tmp.rds: N=**24** observations
- This is only 0.8% of Stata's N=2,961 baseline

**Result**: ❌ **CRITICAL DISCREPANCY**

**Impact**:
- All recovery rate estimates unreliable (tiny sample)
- Many statistics produce NaN (insufficient variation)
- Cannot replicate Stata results

**Root Cause**: Unknown - must investigate Script 06/06b data preparation logic

**Fix Required**:
1. Compare Stata `receivership_dataset_tmp.dta` structure
2. Check R filtering logic in Script 06b
3. Verify all OCC receivership source files are being read
4. Identify where 2,937 observations are being filtered out

---

### **AUC VALUES COMPARISON (Script 51)**

**Stata Baseline** (first 7 models from extracted JSON):

| Model | Type | Stata AUC | R AUC | Match? |
|-------|------|-----------|-------|--------|
| 1 | In-Sample | 0.6834 | TBD | ⏳ Running |
| 1 | Out-of-Sample | 0.7738 | TBD | ⏳ Running |
| 2 | In-Sample | 0.8038 | TBD | ⏳ Running |
| 2 | Out-of-Sample | 0.8268 | TBD | ⏳ Running |
| 3 | In-Sample | 0.8229 | TBD | ⏳ Running |
| 3 | Out-of-Sample | 0.8461 | TBD | ⏳ Running |
| 4 | In-Sample | 0.8641 | TBD | ⏳ Running |

**Status**: Script 51 currently running (started in background). Will update with comparison results.

---

## PRIORITY FIX LIST

### **PRIORITY 1: Script 54 Historical TPR/FPR** (30 min - IN PROGRESS)
- Status: Fix in progress (Inf cleaning added, uncommenting outputs)
- Impact: HIGH - Missing 2 critical tables
- Difficulty: LOW - Code structure exists, just commented out

### **PRIORITY 2: Script 06/06b Receivership Sample Size** (2-4 hours)
- Status: Not started
- Impact: CRITICAL - Affects 7 scripts (81-87)
- Difficulty: MEDIUM - Requires data investigation

### **PRIORITY 3: Script 53 Historical Quintile 4** (1 hour)
- Status: Not started
- Impact: MEDIUM - 1 missing quintile out of 10
- Difficulty: LOW - Same fix as Script 54 (Inf preprocessing)

---

## NEXT STEPS

1. ✅ Complete Script 54 fix (Inf cleaning + uncomment outputs)
2. ⏳ Wait for Script 51 to complete and extract AUC values
3. ❌ Investigate Script 06/06b receivership data issue
4. ❌ Fix Script 53 Historical Q4
5. ❌ Verify all AUC values match Stata (tolerance 0.0001)
6. ❌ Create final comparison matrix

---

## STATA BASELINE REFERENCE

**From `stata_results_extracted.json`**:

### Sample Sizes by Script:
- 01_import_GDP: 567 obs
- 02_import_GFD_CPI: 653 obs
- 21_descriptives: 34 obs
- 22_descriptives_table: 426 obs
- 51_auc: 796 obs
- 52_auc_glm: 796 obs
- 54_auc_tpr_fpr: 178 obs
- 55_pr_auc: 444 obs
- 61_deposits_assets: 6 obs
- 71_banks_at_risk: 626 obs
- 81_recovery_rates: 44 obs
- 84_recovery_outflows: 413 obs
- 85_causes_of_failure: 6 obs
- 86_receivership_length: 196 obs
- 87_recovery_dynamics: 4 obs
- 99_failures_rates: 25 obs

### AUC Values (Script 51 - First 14 values):
1. IS: 0.6834, OOS: 0.7738
2. IS: 0.8038, OOS: 0.8268
3. IS: 0.8229, OOS: 0.8461
4. IS: 0.8641, OOS: 0.8507
5. IS: 0.8643, OOS: 0.8488
6. IS: 0.7994, OOS: 0.8098
7. IS: 0.7390, OOS: 0.7760

---

**Document Status**: LIVE - Will be updated as verification proceeds
**Last Updated**: 2025-11-15 17:00 (Script 54 fix in progress, Script 51 running)
