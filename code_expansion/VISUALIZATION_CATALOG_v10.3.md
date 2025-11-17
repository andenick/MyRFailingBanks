# Visualization Catalog - v10.3

**Date**: 2025-11-17
**Version**: 10.3
**Total Visualizations**: 40 (20 from v10.2 + 20 new in v10.3)

---

## Overview

This catalog documents all 40 presentation-quality visualizations created in the `code_expansion/` directory. All visualizations use **Tableau 10 Classic color palette** for professional consistency and follow standardized theming via `theme_failing_banks()`.

---

## Color Standards (Tableau 10 Classic)

All scripts source: `code_expansion/00_tableau_colors.R`

**Standard Palettes**:
- `tableau_colors`: 10-color main palette
- `era_colors`: 6 historical eras (National Banking through Financial Crisis)
- `comparison_colors`: Failed (red) vs Non-Failed (blue)
- `fdic_colors`: Pre-FDIC (orange) vs Post-FDIC (blue)
- `color_failure`: Red (#E15759)
- `color_success`: Green (#59A14F)
- `color_depression`: Orange (#F28E2B)
- `color_neutral`: Gray (#BAB0AC)

---

## v10.2 Visualizations (Scripts 07-09, 11, 14, 18, 22-35)

### Updated Core Analysis Scripts

**07_recovery_distribution_by_era.R**
- **Output**: `07_recovery_distribution_by_era.png` (12" × 10", 300 DPI)
- **Purpose**: Recovery rate distributions across 6 historical eras
- **Key Finding**: Modern era shows tighter distribution around higher recovery rates
- **Data Source**: `receivership_dataset_tmp.rds`

**08_asset_quality_vs_recovery.R**
- **Output**: `08_asset_quality_vs_recovery.png` (12" × 10", 300 DPI)
- **Purpose**: Relationship between asset quality at failure and depositor recovery
- **Key Finding**: Higher share of good assets → higher recovery rates
- **Data Source**: `receivership_dataset_tmp.rds`

**09_recovery_by_size_quintile.R**
- **Output**: `09_recovery_by_size_quintile.png` (12" × 10", 300 DPI)
- **Purpose**: Recovery rates by bank size quintile across eras
- **Key Finding**: Larger banks generally have higher recovery rates
- **Data Source**: `receivership_dataset_tmp.rds`

**11_solvency_vs_depositor_recovery.R**
- **Output**: `11_solvency_vs_depositor_recovery.png` (12" × 10", 300 DPI)
- **Purpose**: Direct relationship between solvency ratio and recovery outcomes
- **Key Finding**: Strong positive correlation between solvency and dividends
- **Data Source**: `receivership_dataset_tmp.rds`

**14_funding_structure_evolution.R**
- **Output**: `14_funding_structure_evolution.png` (12" × 10", 300 DPI)
- **Purpose**: Evolution of funding mix (core deposits vs noncore) over time
- **Key Finding**: Noncore funding definition change in 1941, modern increase post-1980
- **Data Source**: `combined-data.rds`

**18_great_depression_asset_composition.R**
- **Output**: `18_great_depression_asset_composition.png` (12" × 10", 300 DPI)
- **Purpose**: Asset composition changes during Great Depression (1929-1935)
- **Key Finding**: Flight to liquidity during crisis years
- **Data Source**: `combined-data.rds`

### New Presentation Scripts (v10.2)

**22_era_failure_rates_comparison.R**
- **Output**: `22_era_failure_rates_comparison.png` (12" × 8", 300 DPI)
- **Purpose**: Bar chart comparing failure rates across 6 historical eras
- **Key Finding**: Pre-FDIC era had 5-10× higher failure rates
- **Data Source**: `combined-data.rds`

**23_coefficient_magnitude_comparison.R**
- **Output**: `23_coefficient_magnitude_comparison.png` (12" × 10", 300 DPI)
- **Purpose**: Forest plot showing key regression coefficients with confidence intervals
- **Key Finding**: Asset growth, income ratio, noncore funding are strongest predictors
- **Data Source**: Regression coefficients from `tempfiles/`

**24_auc_across_eras.R**
- **Output**: `24_auc_across_eras.png` (12" × 8", 300 DPI)
- **Purpose**: Model discrimination (AUC) across historical eras
- **Key Finding**: Consistent 0.85-0.92 AUC across all periods
- **Data Source**: `tempfiles/auc_results.rds`

**25_predicted_probability_distribution.R**
- **Output**: `25_predicted_probability_distribution.png` (12" × 10", 300 DPI)
- **Purpose**: Distribution of predicted failure probabilities for failed vs non-failed banks
- **Key Finding**: Clear separation with minimal overlap
- **Data Source**: `temp_reg_data.rds`

**26_failure_rate_time_series_smooth.R**
- **Output**: `26_failure_rate_time_series_smooth.png` (14" × 8", 300 DPI)
- **Purpose**: Smoothed failure rate over 160 years with era shading
- **Key Finding**: Dramatic post-FDIC stability
- **Data Source**: `combined-data.rds`

**27_leverage_trajectory_failed_vs_nonfailed.R**
- **Output**: `27_leverage_trajectory_failed_vs_nonfailed.png` (12" × 8", 300 DPI)
- **Purpose**: Equity/assets ratio over time for failed vs non-failed banks
- **Key Finding**: Failed banks show declining capital 3-5 years before failure
- **Data Source**: `temp_reg_data.rds`

**28_deposit_outflows_pre_failure.R**
- **Output**: `28_deposit_outflows_pre_failure.png` (12" × 8", 300 DPI)
- **Purpose**: Deposit behavior in quarters leading to failure
- **Key Finding**: Accelerating outflows in final year
- **Data Source**: `temp_reg_data.rds`

**29_noncore_funding_risk_multiplier.R**
- **Output**: `29_noncore_funding_risk_multiplier.png` (10" × 8", 300 DPI)
- **Purpose**: Relative risk by noncore funding quintile
- **Key Finding**: 5-10× higher failure probability in highest quintile
- **Data Source**: `temp_reg_data.rds`

**30_income_volatility_failed_vs_nonfailed.R**
- **Output**: `30_income_volatility_failed_vs_nonfailed.png` (12" × 8", 300 DPI)
- **Purpose**: Income stability comparison over time
- **Key Finding**: Failed banks have 2-3× higher income volatility
- **Data Source**: `temp_reg_data.rds`

**31_asset_growth_bins_failure_rate.R**
- **Output**: `31_asset_growth_bins_failure_rate.png` (12" × 8", 300 DPI)
- **Purpose**: Failure rates by asset growth category
- **Key Finding**: U-shaped relationship - both rapid growth and contraction risky
- **Data Source**: `temp_reg_data.rds`

**32_roc_curve_comparison_eras.R**
- **Output**: `32_roc_curve_comparison_eras.png` (10" × 10", 300 DPI)
- **Purpose**: ROC curves overlaid for all 6 eras
- **Key Finding**: Consistent discrimination across time
- **Data Source**: `tempfiles/` regression outputs

**33_calibration_plot.R**
- **Output**: `33_calibration_plot.png` (10" × 10", 300 DPI)
- **Purpose**: Predicted vs observed failure rates (model calibration)
- **Key Finding**: Well-calibrated predictions across probability spectrum
- **Data Source**: `temp_reg_data.rds`

**34_size_distribution_failed_vs_nonfailed.R**
- **Output**: `34_size_distribution_failed_vs_nonfailed.png` (12" × 8", 300 DPI)
- **Purpose**: Bank size distributions comparing failed vs surviving banks
- **Key Finding**: Failed banks skew smaller but failures span all sizes
- **Data Source**: `combined-data.rds`

**35_fdic_before_after_comparison.R**
- **Output**: `35_fdic_before_after_comparison.png` (14" × 10", 300 DPI)
- **Purpose**: Multi-panel comparison of key metrics pre/post FDIC (1934)
- **Key Finding**: FDIC stabilized failures, volatility, and funding structure
- **Data Source**: `combined-data.rds`

---

## v10.3 NEW Visualizations (Scripts 36-55)

### Time Period Deep Dives

**36_national_banking_era_deep_dive.R**
- **Output**: `36_national_banking_era_deep_dive.png` (12" × 10", 300 DPI)
- **Purpose**: Comprehensive view of National Banking Era (1863-1913)
- **Key Metrics**: Failure patterns, leverage, liquidity during first 50 years
- **Data Source**: `combined-data.rds`

**37_world_war_i_banking_dynamics.R**
- **Output**: `37_world_war_i_banking_dynamics.png` (12" × 10", 300 DPI)
- **Purpose**: Banking sector response to WWI shock (1914-1920)
- **Key Finding**: War bond holdings, credit expansion, post-war adjustment
- **Data Source**: `combined-data.rds`

**38_savings_and_loan_crisis_anatomy.R**
- **Output**: `38_savings_and_loan_crisis_anatomy.png` (12" × 10", 300 DPI)
- **Purpose**: S&L Crisis characteristics (1986-1992)
- **Key Finding**: Regulatory forbearance, interest rate risk, FIRREA impact
- **Data Source**: `combined-data.rds`

**39_great_depression_subperiods.R** ✓ TESTED
- **Output**: `39_great_depression_subperiods.png` (12" × 12", 300 DPI)
- **Purpose**: Break Depression into 4 acts: Stock Crash → Banking Panics → Bank Holiday → FDIC Recovery
- **Key Finding**: Failure rate drops from 39.8% (1929-1930) to 2.94% (1933-1935)
- **Data Source**: `combined-data.rds`

**40_great_financial_crisis_timeline.R**
- **Output**: `40_great_financial_crisis_timeline.png` (14" × 10", 300 DPI)
- **Purpose**: GFC month-by-month progression (2007-2009)
- **Key Events**: Bear Stearns, Lehman, TARP, stress tests
- **Data Source**: `combined-data.rds`

### Pre-FDIC vs Post-FDIC Comparisons

**41_fundamental_stability_pre_post_fdic.R** ✓ TESTED
- **Output**: `41_fundamental_stability_pre_post_fdic.png` (12" × 10", 300 DPI)
- **Purpose**: Show FDIC stabilized ALL fundamentals via rolling 5-year volatility
- **Key Finding**: Leverage volatility down 67%, deposit volatility down 49%
- **Data Source**: `combined-data.rds`

**42_capital_adequacy_pre_post_fdic.R**
- **Output**: `42_capital_adequacy_pre_post_fdic.png` (12" × 10", 300 DPI)
- **Purpose**: Evolution of equity/assets ratio pre/post deposit insurance
- **Key Finding**: Lower but more stable capitalization post-1934
- **Data Source**: `combined-data.rds`

**43_failure_rate_time_series_log_scale.R**
- **Output**: `43_failure_rate_time_series_log_scale.png` (14" × 8", 300 DPI)
- **Purpose**: Long-term failure rates on log scale to show magnitude
- **Key Finding**: 90%+ reduction in failure rate post-FDIC
- **Data Source**: `combined-data.rds`

**44_loan_portfolio_composition_pre_post_fdic.R**
- **Output**: `44_loan_portfolio_composition_pre_post_fdic.png` (12" × 10", 300 DPI)
- **Purpose**: Asset allocation shifts after deposit insurance
- **Key Finding**: Less liquidity hoarding post-FDIC, more lending
- **Data Source**: `combined-data.rds`

**45_income_volatility_pre_post_fdic.R**
- **Output**: `45_income_volatility_pre_post_fdic.png` (12" × 8", 300 DPI)
- **Purpose**: Profitability stability comparison
- **Key Finding**: Smoother earnings post-1934
- **Data Source**: `combined-data.rds`

### Three Main Regressors (TOP PRIORITY - User Request)

**46_asset_growth_trajectory.R** ✓ TESTED
- **Output**: `46_asset_growth_trajectory.png` (12" × 8", 300 DPI)
- **Purpose**: Asset growth from t-5 to failure, failed vs non-failed banks
- **Pattern**: Boom-bust cycle visible in failed banks
- **Data Source**: `temp_reg_data.rds` (contains `growth` variable)
- **Note**: Some data quality issues with NaN/Inf values

**47_income_ratio_trajectory.R** ✓ TESTED
- **Output**: `47_income_ratio_trajectory.png` (12" × 8", 300 DPI)
- **Purpose**: Net income/assets from t-5 to failure
- **Key Finding**: Income declines from +0.68% (t-5) to -4.48% (t-1)
- **Data Source**: `temp_reg_data.rds`

**48_noncore_funding_trajectory.R**
- **Output**: `48_noncore_funding_trajectory.png` (12" × 8", 300 DPI)
- **Purpose**: Noncore funding ratio from t-5 to failure
- **Key Finding**: Rises from 21.2% (t-5) to 53.5% at failure
- **Data Source**: `temp_reg_data.rds`

**49_three_regressors_combined.R** ✓ TESTED (User's #1 Priority)
- **Output**: `49_three_regressors_combined.png` (12" × 12", 300 DPI)
- **Purpose**: Comprehensive 3-panel view of all main predictors
- **Metrics**: Asset growth, income ratio, noncore funding
- **Design**: Stacked panels with confidence intervals, non-failed baselines
- **Data Source**: `temp_reg_data.rds`

**50_regressor_interactions_heatmap.R**
- **Output**: `50_regressor_interactions_heatmap.png` (10" × 10", 300 DPI)
- **Purpose**: Correlation matrix showing how predictors relate
- **Key Finding**: Some interactions amplify risk
- **Data Source**: `temp_reg_data.rds`

**51_regressor_stability_over_time.R**
- **Output**: `51_regressor_stability_over_time.png` (12" × 10", 300 DPI)
- **Purpose**: Coefficient stability across rolling 10-year windows
- **Key Finding**: Consistent predictor importance across eras
- **Data Source**: `temp_reg_data.rds`

### Case Studies

**52_typical_failed_bank_lifecycle.R** ✓ TESTED
- **Output**: `52_typical_failed_bank_lifecycle.png` (16" × 12", 300 DPI)
- **Purpose**: Definitive "what does a failing bank look like" across 8 metrics
- **Metrics**: Growth, income, leverage, liquidity, loans, noncore, deposits, NPLs
- **Design**: 4×2 faceted grid showing median trajectories t-5 to failure
- **Key Finding**: Deterioration visible across ALL dimensions
- **Data Source**: `temp_reg_data.rds`

**53_case_study_size_based_patterns.R**
- **Output**: `53_case_study_size_based_patterns.png` (12" × 10", 300 DPI)
- **Purpose**: Compare small vs large bank failure patterns
- **Key Finding**: Different signatures - small = liquidity, large = wholesale funding
- **Data Source**: `temp_reg_data.rds`

**54_case_study_crisis_specific_signatures.R**
- **Output**: `54_case_study_crisis_specific_signatures.png` (14" × 10", 300 DPI)
- **Purpose**: Unique failure patterns in Depression vs S&L vs GFC
- **Key Finding**: Era-specific dominant risks
- **Data Source**: `temp_reg_data.rds`

**55_case_study_receivership_prediction.R**
- **Output**: `55_case_study_receivership_prediction.png` (12" × 10", 300 DPI)
- **Purpose**: Predict recovery values from pre-failure fundamentals
- **Key Finding**: Asset quality 3 months before failure predicts dividends
- **Data Source**: `receivership_dataset_tmp.rds` + `temp_reg_data.rds`

---

## Output Standards

**All visualizations follow these standards**:

1. **Resolution**: 300 DPI (publication quality)
2. **Format**: PNG with white background
3. **Color Palette**: Tableau 10 Classic (loaded from `00_tableau_colors.R`)
4. **Theme**: `theme_failing_banks()` for consistent appearance
5. **Titles**: Descriptive with clear subtitles
6. **Captions**: Data source and key methodological notes
7. **Location**: `code_expansion/presentation_outputs/`

**Typography**:
- Title: Bold, 14pt
- Subtitle: Regular, 11pt
- Axis labels: 10pt
- Caption: Italic, 8pt

**Color Usage**:
- Failed banks: Red (#E15759)
- Non-failed banks: Blue (#4E79A7)
- Pre-FDIC: Orange (#F28E2B)
- Post-FDIC: Blue (#4E79A7)
- Success/Recovery: Green (#59A14F)

---

## Usage Notes

**To regenerate all visualizations**:

```r
# Set working directory
setwd("D:/Arcanum/Projects/FailingBanks/FailingBanks_v9.0_Clean")

# Source all scripts in order
scripts <- c(
  sprintf("%02d", 7:9), "11", "14", "18",  # Updated core scripts
  sprintf("%02d", 22:55)                    # All presentation scripts
)

for (s in scripts) {
  script_file <- list.files("code_expansion",
                           pattern = paste0("^", s, "_"),
                           full.names = TRUE)
  if (length(script_file) > 0) {
    cat("\n=== Running", s, "===\n")
    source(script_file[1])
  }
}
```

**Individual script execution**:

```bash
Rscript code_expansion/49_three_regressors_combined.R
```

---

## Data Dependencies

**Primary datasets used across visualizations**:

1. **combined-data.rds** (964,053 obs, 131 variables)
   - Full panel dataset 1863-2024
   - Bank-quarter observations
   - Scripts: 07-09, 11, 14, 18, 22, 26, 34-45

2. **temp_reg_data.rds** (~228 MB)
   - Regression analysis subset
   - Contains `growth`, `time_to_fail`, failure predictors
   - Scripts: 25, 27-31, 46-54

3. **receivership_dataset_tmp.rds** (2,961 obs)
   - Failed bank receivership data
   - Recovery rates, asset quality, solvency
   - Scripts: 07-09, 11, 55

4. **tempfiles/auc_results.rds**
   - Model discrimination metrics
   - Scripts: 24, 32

---

## Key Insights from Visualizations

**Three Main Failure Signatures** (Scripts 46-49):
1. **Asset Growth**: Boom-bust pattern in failed banks
2. **Income Ratio**: Profitability collapse from +0.7% to -4.5%
3. **Noncore Funding**: Dependence rises from 21% to 54%

**FDIC Impact** (Scripts 35, 41-45):
- 90%+ reduction in failure rates
- 50-67% reduction in fundamental volatility
- Structural shift in banking stability

**Era-Specific Patterns** (Scripts 36-40, 54):
- National Banking: High leverage variability
- Great Depression: Liquidity crisis dominant
- S&L Crisis: Interest rate mismatch
- GFC: Wholesale funding dependence

**Recovery Determinants** (Scripts 07-09, 11, 55):
- Asset quality at failure strongest predictor
- Size effects: Larger banks → higher recovery
- Era effects: Modern FDIC → faster resolution

---

## Version History

**v10.3** (2025-11-17)
- Added 20 new visualizations (scripts 36-55)
- Focus on time periods, pre/post FDIC, three main regressors, case studies
- Total: 40 visualizations

**v10.2** (2025-11-17)
- Tableau 10 Classic color standardization
- Created 14 new presentation scripts (22-35)
- Updated 6 core scripts (07-09, 11, 14, 18)
- Established `theme_failing_banks()`
- Total: 20 visualizations

**v10.1 and earlier**
- Core analysis scripts 00-21, 81-87, 99
- Initial visualization development

---

## Contact

**Project**: Failing Banks Analysis
**Location**: `D:/Arcanum/Projects/FailingBanks/FailingBanks_v9.0_Clean`
**Documentation**: See `README.md` for full project overview

---

*Last updated: 2025-11-17*
*Catalog maintained as part of v10.3 release*
