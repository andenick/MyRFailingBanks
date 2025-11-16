# Changelog: Version History

## v9.0 (November 16, 2025) - CURRENT

**Status**: ✅ CERTIFIED PRODUCTION-READY

**Changes**:
- Reorganized to exactly match Stata qje-repkit structure
- Consolidated to 31 core scripts (matching Stata)
- Merged helper functions into 00_setup.R
- Simplified 00_master.R (matches Stata 00_master.do)
- Rewrote all documentation from scratch (6 comprehensive files)

**Structure**: 33 scripts (00_master + 00_setup + 31 core)

---

## v8.0 (November 16, 2025)

**Achievement**: Receivership data fixed

**Critical Fix**: Script 06 line 133
- Changed `inner_join()` to `left_join()`
- Recovered 2,937 receiverships (N=24 → N=2,961)
- 99.2% data recovery

**Impact**: All recovery scripts (81-87) now work with full sample

---

## v7.0 (November 15, 2025)

**Achievement**: Quintiles & TPR/FPR fixed

**Fixes**:
- Script 53: Added Inf filtering → All 10 quintiles working
- Script 54: Added Inf filtering → All 4 TPR/FPR tables working

**Known Issue**: Receivership N=24 (discovered in v8.0)

---

## v6.0 (November 14, 2025)

**Achievement**: Perfect AUC match

**Fix**: Created `safe_max()` wrapper
- R's max() returns -Inf for all-NA
- Stata's max() returns missing
- Solution: Custom wrapper in 00_setup.R

**Result**: All 8 AUC values matched Stata exactly

---

## v1.0-5.0 (November 9-13, 2025)

**Development Phase**: Data pipeline construction

**Milestones**:
- v1.0: Project setup
- v2.0: Macro data import (GDP, CPI, Yields)
- v3.0: Historical panel (N=294,555)
- v4.0: Modern panel (N=664,812)
- v5.0: Combined panel (N=964,053)

---

**Last Updated**: November 16, 2025
