# FFIEC Call Report Data Sources Reference

**Project**: Failing Banks R Replication
**Last Updated**: November 24, 2025
**Purpose**: Reference documentation for FFIEC Call Report forms, schedules, and item codes used in the Correia, Luck, and Verner (2025) "Failing Banks" replication

---

## Table of Contents

1. [FFIEC Form History and Timeline](#ffiec-form-history-and-timeline)
2. [Current FFIEC Forms](#current-ffiec-forms)
3. [Key Schedules](#key-schedules)
4. [MDRM Code Structure](#mdrm-code-structure)
5. [Variable Mappings](#variable-mappings)
6. [OCC Cause of Failure Classifications](#occ-cause-of-failure-classifications)
7. [Data Sources](#data-sources)

---

## FFIEC Form History and Timeline

### Historical Forms (1959-1983)

| Form | Name | Period | Notes |
|------|------|--------|-------|
| FFIEC 010 | Consolidated Report of Condition (<$100M) | 1959-1983 | Formerly FR 105 & FR 2103 |
| FFIEC 011 | Consolidated Report of Income (<$100M) | 1960-1983 | Formerly FR 107 |
| FFIEC 012 | Consolidated Report of Condition (Domestic Only) | 1978-1983 | Formerly FR 2105 |
| FFIEC 013 | Consolidated Report of Income (Dom + Foreign) | 1978-1982 | Formerly FR 2107 |
| FFIEC 014 | Consolidated Report of Condition (Dom + Foreign) | 1969-1983 | Formerly FR 2106 |

### Transitional Period (1984-2001)

| Form | Description |
|------|-------------|
| FFIEC 031 | Banks with domestic and foreign offices |
| FFIEC 032 | Banks with domestic offices only (large) |
| FFIEC 033 | Banks with domestic offices only (medium) |
| FFIEC 034 | Banks with domestic offices only (small) |

### Modern Forms (2001-Present)

| Form | Introduced | Eligibility | Detail Level |
|------|------------|-------------|--------------|
| FFIEC 031 | Pre-2001 | Banks with foreign offices OR >$100B assets | Most detailed |
| FFIEC 041 | March 2001 | Domestic only, <$100B assets | Moderate |
| FFIEC 051 | March 2017 | Domestic only, <$5B assets | Streamlined |

---

## Current FFIEC Forms

### FFIEC 031
**Full Name**: Consolidated Reports of Condition and Income for a Bank with Domestic and Foreign Offices

**Required For**:
- Banks with foreign offices (branches, subsidiaries, IBFs)
- Banks with total consolidated assets ≥$100 billion

**Characteristics**:
- Most detailed reporting requirements
- Includes Schedule RC-E Part II (foreign office deposits)
- Uses RCFD codes for consolidated items

### FFIEC 041
**Full Name**: Consolidated Reports of Condition and Income for a Bank with Domestic Offices Only

**Required For**:
- Banks with domestic offices only
- Total consolidated assets <$100 billion
- Not eligible for FFIEC 051

**Characteristics**:
- Moderate detail level
- No foreign office schedules
- Uses RCON codes

### FFIEC 051
**Full Name**: Consolidated Reports of Condition and Income for a Bank with Domestic Offices Only (Small Bank Version)

**Required For**:
- Banks with domestic offices only
- Total assets <$5 billion
- Certain eligibility criteria

**Characteristics**:
- Streamlined version of FFIEC 041
- Reduced reporting burden for small banks
- Some schedules simplified or eliminated

---

## Key Schedules

### Report of Condition (Balance Sheet)

| Schedule | Name | Key Contents |
|----------|------|--------------|
| **RC** | Balance Sheet | Total assets, liabilities, equity |
| **RC-A** | Cash and Balances Due | Cash items, Fed balances |
| **RC-B** | Securities | AFS, HTM securities |
| **RC-C Part I** | Loans and Leases | Loan categories by type |
| **RC-C Part II** | Small Business/Farm Loans | CRA-related data |
| **RC-E** | Deposit Liabilities | Deposit breakdowns |
| **RC-K** | Quarterly Averages | Average balances |
| **RC-L** | Off-Balance Sheet Items | Derivatives, commitments |
| **RC-M** | Memoranda | Supplemental items |
| **RC-N** | Past Due and Nonaccrual | Credit quality |
| **RC-O** | Other Data | Uninsured deposits, etc. |
| **RC-R** | Regulatory Capital | Capital ratios |

### Report of Income (Income Statement)

| Schedule | Name | Key Contents |
|----------|------|--------------|
| **RI** | Income Statement | Interest income/expense, net income |
| **RI-A** | Changes in Equity | Equity movements |
| **RI-B Part I** | Charge-offs and Recoveries | Credit losses |
| **RI-B Part II** | Changes in ALLL | Allowance movements |
| **RI-E** | Explanations | Unusual items |

---

## MDRM Code Structure

### Code Prefixes

| Prefix | Meaning | Usage |
|--------|---------|-------|
| **RCFD** | Report of Condition - Fully Consolidated | Domestic + Foreign combined |
| **RCON** | Report of Condition - Domestic Only | Domestic offices only |
| **RCFN** | Report of Condition - Foreign Only | Foreign offices only |
| **RIAD** | Report of Income - All Data | Income statement items |
| **UBPR** | Uniform Bank Performance Report | Derived ratios |

### Code Format

```
[PREFIX][ITEM_NUMBER]

Examples:
- RCFD2170 = Consolidated Total Assets
- RCON2200 = Domestic Total Deposits
- RIAD4340 = Net Income
```

### Key Item Numbers

| Item # | Variable | Schedule |
|--------|----------|----------|
| 2170 | Total Assets | RC |
| 2200 | Total Deposits | RC |
| 3210 | Total Equity Capital | RC |
| 3300 | Total Liabilities + Equity | RC |
| 1410 | Loans Secured by Real Estate | RC-C |
| 1420 | Loans Secured by Farmland | RC-C |
| 6631 | Noninterest-bearing Deposits | RC-E |
| 6636 | Interest-bearing Deposits | RC-E |
| 4340 | Net Income | RI |
| 4301 | Total Interest Income | RI |

---

## Variable Mappings

### Balance Sheet Variables (Schedule RC)

| Variable Name | FFIEC 031 Code | FFIEC 041/051 Code | Description |
|---------------|----------------|-------------------|-------------|
| Total Assets | RCFD2170 | RCON2170 | Sum of all assets |
| Total Deposits | RCFD2200 | RCON2200 | All deposit liabilities |
| Total Equity | RCFD3210 | RCON3210 | Bank capital |
| Total Liabilities | RCFD2948 | RCON2948 | All liabilities |

### Loan Variables (Schedule RC-C)

| Variable Name | Code | Description |
|---------------|------|-------------|
| RE Loans Total | RCON1410 | All loans secured by real estate |
| 1-4 Family Construction | RCONF158 | Residential construction loans |
| Other Construction | RCONF159 | Commercial construction & land |
| Farmland Loans | RCON1420 | Agricultural real estate |
| Revolving Home Equity | RCON1460 | HELOCs |

### Deposit Variables (Schedule RC-E)

| Variable Name | Code | Description |
|---------------|------|-------------|
| Noninterest-bearing | RCON6631 | Demand deposits (domestic) |
| Interest-bearing | RCON6636 | Savings, time, NOW (domestic) |
| Time Deposits | RCON2604 | CDs and time deposits |
| Brokered Deposits | RCON2365 | Deposits from brokers |

### Income Variables (Schedule RI)

| Variable Name | Code | Description |
|---------------|------|-------------|
| Net Income | RIAD4340 | Bottom line profit/loss |
| Interest Income | RIAD4301 | Total interest earned |
| Interest Expense | RIAD4073 | Total interest paid |
| Provision for Losses | RIAD4230 | Loan loss provisions |

---

## OCC Cause of Failure Classifications

### Historical Classification System (1865-1937)

The Office of the Comptroller of the Currency classified causes of national bank failures in their Annual Reports to Congress. This data was recorded in "Tables of National Banks in Charge of Receivers."

### Categories and Prevalence

| Code | Category | % of Failures | Description |
|------|----------|---------------|-------------|
| ECON | Economic Conditions | 34% | Crop losses, local depression, deflation |
| LOSS | Losses | 22% | Asset losses, loan defaults |
| FRAUD | Fraud | 21% | Embezzlement, falsified records |
| GOV | Governance | 14% | Bad management, weak oversight |
| EXLEND | Excessive Lending | 5% | Concentration, limit violations |
| RUN | Run | 2% | Bank runs, liquidity crisis |
| OTHER | Other | 1% | Miscellaneous |

### Key Finding

Despite popular narratives about banking panics, **runs and liquidity issues account for less than 2%** of failures classified by the OCC. The predominant causes were fundamental weaknesses: economic conditions, asset losses, and fraud.

### Data Coverage

| Period | Coverage |
|--------|----------|
| 1865-1928 | Complete |
| 1929-1931 | Partial |
| 1932-1933 | Missing |
| 1934-1937 | Partial |

---

## Data Sources

### Primary Sources

1. **FFIEC Central Data Repository (CDR)**
   - URL: https://cdr.ffiec.gov/public/
   - Content: All Call Report data from 2001-present
   - Format: XML, CSV downloads available

2. **Federal Reserve MDRM**
   - URL: https://www.federalreserve.gov/apps/mdrm/
   - Content: Complete data dictionary for all MDRM codes
   - Download: https://www.federalreserve.gov/apps/mdrm/download_mdrm.htm

3. **FDIC Call Report Instructions**
   - URL: https://www.fdic.gov/resources/bankers/call-reports/
   - Content: Official reporting instructions and forms

### Historical Sources

4. **OCC Annual Reports**
   - Content: National bank receivership data (1863-1941)
   - Location: National Archives, FRASER

5. **Federal Reserve Historical Data**
   - URL: https://www.federalreserve.gov/apps/mdrm/pdf/Call_59.pdf (1959-1983)
   - URL: https://www.federalreserve.gov/apps/mdrm/pdf/Call_84.pdf (1984-2000)

### Academic References

6. **Correia, Luck, and Verner (2025)**
   - "Failing Banks" - QJE
   - Data Appendix C documents variable construction
   - Available: NBER WP 32907, NY Fed Staff Report 1117

---

## Related Files

- `FFIEC_CALL_REPORT_CODES.csv` - Machine-readable MDRM code mappings
- `OCC_FAILURE_CAUSE_CODES.csv` - OCC classification codes and definitions
- `DATA_FLOW_COMPLETE_GUIDE.md` - Data pipeline documentation

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-24 | 1.0 | Initial creation with FFIEC forms, MDRM codes, OCC classifications |

---

**Sources**:
- [FFIEC Reporting Forms](https://www.ffiec.gov/resources/reporting-forms)
- [Federal Reserve MDRM](https://www.federalreserve.gov/data/mdrm.htm)
- [NY Fed Liberty Street Economics](https://libertystreeteconomics.newyorkfed.org/2024/11/why-do-banks-fail-bank-runs-versus-solvency/)
- [Correia, Luck, Verner - Failing Banks](https://www.nber.org/papers/w32907)
