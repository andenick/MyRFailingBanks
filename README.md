# Bank Failure Prediction: Post-2000 Analysis

## A Comprehensive Validation of the Correia Framework Using Modern Period Data (2000-2023)

This repository contains a complete analysis of bank failure prediction models for the post-2000 period, building on the Correia et al. (2025) solvency-funding interaction framework.

---

## Key Findings

### 1. Structural Break Confirmed (Chow Test)
- **F-statistic: 827.89, p < 2.2e-16**
- The post-2000 period represents a fundamentally different regime
- Coefficient on income_ratio declined 75.4% (0.427 → 0.105)
- Interaction term declined 41.4% (-5.37 → -3.15)

### 2. Excellent Predictive Performance
| Model | In-Sample AUC | K-Fold CV AUC | Degradation |
|-------|---------------|---------------|-------------|
| Model 1 (Solvency Only) | 0.958 | 0.959 | ~0% |
| Model 2 (Funding Only) | 0.888 | 0.887 | ~0% |
| Model 3 (Interaction) | 0.965 | 0.965 | ~0% |

### 3. Critical Finding: Noncore Funding DECREASED Post-Crisis
- Pre-Crisis (2000-2007): 35.8% mean noncore ratio
- Post-Crisis (2011-2023): **28.5%** (-20.2% decrease)
- Driven by Basel III LCR/NSFR regulations
- **This VALIDATES the regression results**

### 4. Decile Concentration
- **Top decile captures 94.9% of all failures**
- Model effectively ranks banks by failure risk

---

## Repository Structure

```
MyRFailingBanks/
├── README.md                           # This file
├── METHODOLOGY.md                      # Detailed methodology
├── FINDINGS_SUMMARY.md                 # Executive summary of findings
│
├── data/                               # Data files (see data/README.md)
│   ├── README.md
│   └── processed/
│
├── R/                                  # R analysis scripts
│   ├── 01_data_prep_2000.R
│   ├── 02_model_estimation_2000.R
│   ├── 03_auc_analysis_2000.R
│   ├── 04_create_outputs_2000.R
│   ├── 05_structural_break_test.R
│   ├── 06_kfold_cross_validation.R
│   ├── 07_marginal_effects.R
│   ├── 08_predicted_probability_analysis.R
│   ├── 09_noncore_funding_investigation.R
│   ├── 10_rolling_windows.R
│   └── 11_out_of_sample_validation.R
│
├── output/                             # Analysis outputs
│   ├── tables/                         # CSV results
│   └── figures/                        # Plots
│
├── reports/                            # LaTeX reports
│   ├── comprehensive_analysis.pdf      # Main report (15 pages)
│   ├── historical_context.pdf          # Regulatory context (13 pages)
│   └── comparison_report.pdf           # Full vs 2000+ comparison (16 pages)
│
└── docs/                               # Additional documentation
    ├── regulatory_timeline.md
    └── variable_definitions.md
```

---

## Sample Characteristics

| Characteristic | Value |
|----------------|-------|
| Observations | 158,477 |
| Unique Banks | 10,727 |
| Failures | 489 (0.31%) |
| Time Period | 2000Q1 - 2023Q4 |

---

## Model Specifications

### Model 1: Solvency Only
```
P(Failure) = α + β₁·income_ratio + γ·log(age)
```

### Model 2: Funding Only
```
P(Failure) = α + β₂·noncore_ratio + γ·log(age)
```

### Model 3: Solvency × Funding Interaction
```
P(Failure) = α + β₁·income_ratio + β₂·noncore_ratio
           + δ·(income_ratio × noncore_ratio) + γ·log(age)
```

### Model 4: Full with Macro Controls
Adds GDP growth, inflation, and bank growth categories to Model 3.

---

## Key Economic Insight

**The Solvency-Funding Interaction**:

Profitability (income_ratio) protects banks with fragile funding structures:

| Noncore Level | Marginal Effect of Income |
|---------------|---------------------------|
| P10 (15%) | -0.36 (protective) |
| P50 (37%) | -1.06 (strongly protective) |
| P90 (57%) | -1.69 (very strongly protective) |

**Interpretation**: Banks with high noncore funding benefit MORE from profitability. This explains why SVB (2023) failed despite apparent profitability - small income shocks couldn't offset the funding run.

---

## Validation Results

### Chow Test for Structural Break
- **H₀**: No structural break at year 2000
- **H₁**: Structural break exists
- **Result**: F = 827.89, p < 2.2e-16
- **Conclusion**: REJECT H₀ - Strong evidence of structural break

### K-Fold Cross-Validation
- 5-fold, 10-fold, and repeated (5×5) CV performed
- Average AUC degradation: **~0%**
- Models show excellent generalization

### Decile Analysis
- Top decile (highest predicted risk) captures **94.9%** of failures
- Model effectively concentrates risk identification

---

## Historical Context

### Why Did Noncore Funding Decrease?

1. **Basel III LCR** (2015-2018): Required banks to hold high-quality liquid assets
2. **Basel III NSFR** (2021): Penalized short-term wholesale funding
3. **Dodd-Frank Stress Testing** (2011+): Revealed funding vulnerabilities
4. **Market Lessons**: Banks learned from WaMu's $16.7B run (2008)

### 2008 vs 2023 Crisis Comparison

| Aspect | 2008 (WaMu) | 2023 (SVB) |
|--------|-------------|------------|
| Primary Cause | Bad loans + funding run | Duration risk + deposit flight |
| Run Speed | 10 days | **1 day** |
| Key Vulnerability | Wholesale funding | Uninsured deposits (86%) |

---

## Requirements

### R Packages
```r
install.packages(c(
  "tidyverse",
  "haven",
  "pROC",
  "lmtest",
  "sandwich",
  "broom"
))
```

### Data Sources
- FDIC Call Reports (RC forms)
- FDIC Failures Database
- Federal Reserve Economic Data (FRED)

---

## Reports

1. **Comprehensive Analysis Report** (`reports/comprehensive_analysis.pdf`)
   - 15 pages
   - Full regression results, validation, interpretation

2. **Historical Context Report** (`reports/historical_context.pdf`)
   - 13 pages
   - Regulatory timeline, crisis comparison, noncore funding investigation

3. **Comparison Report** (`reports/comparison_report.pdf`)
   - 16 pages
   - Full period (1959-2024) vs 2000+ comparison

---

## Citation

If you use this analysis, please cite:

```
@misc{failing_banks_2000_analysis,
  title={Bank Failure Prediction: Post-2000 Analysis Using the Correia Framework},
  author={Failing Banks Research Project},
  year={2025},
  url={https://github.com/yourusername/MyRFailingBanks}
}
```

Based on:
```
Correia, A., et al. (2025). Bank Failure Prediction: A Solvency-Funding
Interaction Framework. Working Paper.
```

---

## License

MIT License - See LICENSE file for details.

---

## Contact

For questions or collaboration inquiries, please open an issue on GitHub.
