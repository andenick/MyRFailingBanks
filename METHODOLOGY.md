# Methodology

## Bank Failure Prediction: Post-2000 Analysis

---

## 1. Data Sources

### 1.1 Primary Data
- **FDIC Call Reports**: Quarterly regulatory filings (Schedule RC) containing balance sheet and income statement data for all FDIC-insured commercial banks
- **FDIC Failures Database**: Official failure dates, resolution types, and failure costs
- **FRED (Federal Reserve Economic Data)**: Macroeconomic variables (GDP growth, CPI inflation)

### 1.2 Sample Construction

Starting sample: All FDIC-insured commercial banks, 2000Q1-2023Q4

**Filters Applied:**
1. **Post-failure exclusion**: Observations after a bank's failure date are removed to prevent data leakage
2. **Charter class restrictions**: Savings & Loans (S&Ls) and Savings Associations excluded; focus on commercial banks only
3. **TARP exclusion**: Banks receiving Troubled Asset Relief Program funds excluded (different resolution mechanisms)
4. **Temporal filter**: year >= 2000

**Final Sample:**
- 158,477 bank-quarter observations
- 10,727 unique banks
- 489 failures (0.31% failure rate)

---

## 2. Variable Definitions

### 2.1 Dependent Variable

**F1_failure**: Binary indicator = 1 if bank fails within the next quarter (t+1), 0 otherwise

### 2.2 Key Independent Variables

| Variable | Definition | Economic Interpretation |
|----------|------------|------------------------|
| `income_ratio` | Net income / Total assets | Solvency/profitability measure |
| `noncore_ratio` | (Total deposits - Core deposits) / Total assets | Funding fragility measure |
| `log_age` | ln(bank age in years) | Bank maturity/experience |

### 2.3 Macro Controls (Model 4)

| Variable | Definition |
|----------|------------|
| `gdp_growth_3y` | 3-year trailing GDP growth rate |
| `inflation_3y` | 3-year trailing CPI inflation rate |
| `growth_cat` | Bank asset growth quintile (1-5) |

---

## 3. Model Specifications

### Model 1: Solvency Only
$$P(\text{Failure}_{i,t+1} = 1) = \alpha + \beta_1 \cdot \text{income\_ratio}_{i,t} + \gamma \cdot \log(\text{age}_{i,t}) + \varepsilon_{i,t}$$

**Purpose**: Test whether profitability alone predicts failure

### Model 2: Funding Only
$$P(\text{Failure}_{i,t+1} = 1) = \alpha + \beta_2 \cdot \text{noncore\_ratio}_{i,t} + \gamma \cdot \log(\text{age}_{i,t}) + \varepsilon_{i,t}$$

**Purpose**: Test whether funding fragility alone predicts failure

### Model 3: Solvency × Funding Interaction
$$P(\text{Failure}_{i,t+1}) = \alpha + \beta_1 \cdot \text{income\_ratio} + \beta_2 \cdot \text{noncore\_ratio} + \delta \cdot (\text{income} \times \text{noncore}) + \gamma \cdot \log(\text{age})$$

**Purpose**: Test whether solvency and funding interact in predicting failure

### Model 4: Full with Macro Controls
$$P(\text{Failure}_{i,t+1}) = \text{Model 3} + \sum_{j=2}^{5} \theta_j \cdot \mathbb{1}(\text{growth\_cat} = j) + \phi_1 \cdot \text{gdp\_growth} + \phi_2 \cdot \text{inflation}$$

**Purpose**: Control for macroeconomic conditions and bank growth

---

## 4. Estimation Methods

### 4.1 Linear Probability Model (LPM)
- OLS regression with binary dependent variable
- **Standard Errors**: Driscoll-Kraay (3-quarter lag) to account for:
  - Heteroskedasticity
  - Autocorrelation within banks
  - Cross-sectional dependence across banks

### 4.2 Logit Model
- Maximum likelihood estimation
- **Standard Errors**: HC1 robust (heteroskedasticity-consistent)
- Log-likelihood, AIC, BIC reported

### 4.3 Probit Model
- Maximum likelihood estimation
- **Standard Errors**: HC1 robust
- Pseudo-R² (McFadden) reported

---

## 5. Validation Procedures

### 5.1 Chow Test for Structural Break

**Hypothesis**:
- H₀: Coefficients are equal across pre-2000 and post-2000 periods
- H₁: Structural break exists at year 2000

**Method**:
1. Estimate pooled model (restricted): All observations 1959-2023
2. Estimate separate models (unrestricted): Pre-2000 and Post-2000
3. Compute F-statistic:
$$F = \frac{(RSS_{pooled} - RSS_{unrestricted}) / k}{RSS_{unrestricted} / (n - 2k)}$$

### 5.2 K-Fold Cross-Validation

**Purpose**: Robust out-of-sample AUC estimation

**Procedure**:
1. Randomly split data into K folds (K = 5 and K = 10)
2. For each fold:
   - Train on K-1 folds
   - Test on held-out fold
   - Calculate AUC
3. Average AUC across folds

**Repeated CV**: 5 repetitions of 5-fold CV with different random seeds

### 5.3 Out-of-Sample Validation (Train/Test Split)

**Design**:
- Training: 2000-2015 (117,000 obs, 470 failures)
- Test: 2016-2023 (41,000 obs, 19 failures)

**Limitation**: Small number of failures in test set

### 5.4 Rolling Window Analysis

**Purpose**: Examine coefficient stability over time

**Method**:
- 14 rolling 10-year windows (2000-2010, 2001-2011, ..., 2013-2023)
- Estimate Model 3 for each window
- Track coefficient evolution

---

## 6. Marginal Effects

### 6.1 Marginal Effect of Income Ratio
$$\frac{\partial P(\text{Failure})}{\partial \text{income\_ratio}} = \beta_1 + \delta \cdot \text{noncore\_ratio}$$

Evaluated at P10, P25, P50, P75, P90 of noncore_ratio distribution

### 6.2 Marginal Effect of Noncore Ratio
$$\frac{\partial P(\text{Failure})}{\partial \text{noncore\_ratio}} = \beta_2 + \delta \cdot \text{income\_ratio}$$

Evaluated at P10, P25, P50, P75, P90 of income_ratio distribution

### 6.3 Threshold Analysis
- Find noncore_ratio where ME(income) = 0
- Find income_ratio where ME(noncore) = 0

---

## 7. Model Evaluation

### 7.1 Area Under ROC Curve (AUC)
- Primary metric for discrimination ability
- AUC = 0.5: No discrimination (random guessing)
- AUC = 1.0: Perfect discrimination
- AUC > 0.9: Excellent discrimination

### 7.2 Decile Analysis
- Rank observations by predicted probability
- Calculate failure rate within each decile
- Measure concentration of failures in top deciles

### 7.3 Classification Thresholds
- Youden's J statistic: Maximize (Sensitivity + Specificity - 1)
- Cost-sensitive threshold: Weight false negatives higher than false positives

---

## 8. Software

### R Version
- R 4.4.1 (2024)

### Key Packages
```r
library(tidyverse)  # Data manipulation
library(haven)      # Read Stata files
library(pROC)       # ROC curves and AUC
library(lmtest)     # Chow test, Wald tests
library(sandwich)   # Robust standard errors
library(broom)      # Tidy model output
```

---

## 9. Reproducibility

All scripts are numbered sequentially:
1. `01_data_prep_2000.R` - Data loading and filtering
2. `02_model_estimation_2000.R` - Model estimation
3. `03_auc_analysis_2000.R` - AUC calculation
4. ... etc.

Run in order to reproduce all results.

---

## 10. References

### Academic
- Correia, A., et al. (2025). Bank Failure Prediction: A Solvency-Funding Interaction Framework. Working Paper.

### Regulatory
- Basel Committee on Banking Supervision. Basel III: The Liquidity Coverage Ratio. BIS, 2013.
- Basel Committee on Banking Supervision. Basel III: The Net Stable Funding Ratio. BIS, 2014.
- FDIC. Crisis and Response: An FDIC History, 2008-2013. 2017.

### Data
- FDIC Call Reports: https://www.fdic.gov/resources/resolutions/bank-failures/
- FRED: https://fred.stlouisfed.org/
