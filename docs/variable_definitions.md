# Variable Definitions

## Dependent Variable

### F1_failure
- **Definition**: Binary indicator equal to 1 if the bank fails within the next quarter (t+1), 0 otherwise
- **Source**: FDIC Failures Database
- **Notes**: Failure is defined as the date of FDIC receivership or assisted transaction

---

## Key Independent Variables

### income_ratio
- **Definition**: Net income divided by total assets
- **Formula**: `Net Income / Total Assets`
- **Economic Interpretation**: Solvency/profitability measure
- **Call Report Items**: RIAD4340 (Net Income), RCFD2170 (Total Assets)
- **Units**: Decimal (e.g., 0.01 = 1%)
- **Expected Sign**: Negative (higher profitability → lower failure probability)

### noncore_ratio
- **Definition**: Non-core deposits divided by total assets
- **Formula**: `(Total Deposits - Core Deposits) / Total Assets`
- **Economic Interpretation**: Funding fragility measure
- **Notes**: Core deposits are typically defined as domestic deposits < $250K (insured limit)
- **Units**: Decimal (e.g., 0.35 = 35%)
- **Expected Sign**: Positive (higher noncore reliance → higher failure probability)

### log_age
- **Definition**: Natural logarithm of bank age in years
- **Formula**: `ln(Current Year - Charter Year + 1)`
- **Economic Interpretation**: Bank maturity/experience
- **Expected Sign**: Negative (older banks typically more stable)

---

## Interaction Term

### income_ratio:noncore_ratio
- **Definition**: Product of income_ratio and noncore_ratio
- **Formula**: `income_ratio × noncore_ratio`
- **Economic Interpretation**: Captures how profitability moderates the risk from funding fragility
- **Expected Sign**: Negative (profitability is more protective when funding is fragile)

---

## Control Variables

### gdp_growth_3y
- **Definition**: 3-year trailing annualized GDP growth rate
- **Source**: FRED series GDPC1
- **Units**: Decimal (e.g., 0.02 = 2%)
- **Expected Sign**: Negative (stronger economy → lower failure probability)

### inflation_3y
- **Definition**: 3-year trailing annualized CPI inflation rate
- **Source**: FRED series CPIAUCSL
- **Units**: Decimal (e.g., 0.03 = 3%)
- **Expected Sign**: Ambiguous (inflation can help or hurt depending on asset/liability structure)

### growth_cat
- **Definition**: Bank asset growth quintile (1-5)
- **Formula**: Quintiles of `(Total Assets_t / Total Assets_{t-4}) - 1`
- **Categories**:
  - 1: Lowest growth quintile (possible shrinkage)
  - 2-4: Intermediate growth
  - 5: Highest growth quintile (rapid expansion)
- **Expected Sign**: Positive for category 5 (rapid growth often precedes failure)

---

## Derived Variables (for Analysis)

### predicted_prob
- **Definition**: Predicted probability of failure from the estimated model
- **Range**: [0, 1]
- **Calculation**: Linear prediction for LPM, inverse link function for Logit/Probit

### risk_decile
- **Definition**: Decile ranking based on predicted probability
- **Range**: 1-10 (10 = highest risk)
- **Use**: Decile analysis and risk concentration metrics

---

## Summary Statistics (Post-2000 Sample)

| Variable | Mean | Std Dev | P10 | P50 | P90 |
|----------|------|---------|-----|-----|-----|
| F1_failure | 0.003 | 0.055 | 0 | 0 | 0 |
| income_ratio | 0.008 | 0.012 | -0.001 | 0.008 | 0.018 |
| noncore_ratio | 0.337 | 0.174 | 0.150 | 0.314 | 0.573 |
| log_age | 3.78 | 1.01 | 2.40 | 3.89 | 4.92 |

---

## Data Quality Notes

1. **Winsorization**: Income_ratio and noncore_ratio are typically winsorized at 1st/99th percentiles to reduce outlier influence
2. **Missing Values**: Observations with missing key variables are dropped
3. **Negative Values**: Negative noncore_ratio values (indicating excess core deposits) are rare but valid
4. **Extreme Values**: Some banks have very high noncore ratios (>80%) during crisis periods
