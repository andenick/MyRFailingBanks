# FFIEC/NIC/FDIC Data Downloaders

This directory contains scripts for downloading publicly available banking regulatory data.

## Quick Start

```bash
# Download all available data
python ffiec_nic_downloader.py --all

# List available data sources
python ffiec_nic_downloader.py --list

# Download specific sources
python ffiec_nic_downloader.py --fdic          # FDIC failed banks
python ffiec_nic_downloader.py --nic           # NIC bulk data
python ffiec_nic_downloader.py --chicago-fed   # Chicago Fed instructions
python ffiec_nic_downloader.py --cdr           # FFIEC CDR instructions
```

## Data Sources

### 1. FDIC Failed Banks
**Direct Download Available: Yes**

| Dataset | URL | Format |
|---------|-----|--------|
| Failed Bank List | https://www.fdic.gov/bank-failures/download-data.csv | CSV |
| BankFind API | https://banks.data.fdic.gov/api/failures | JSON |

Contents: All FDIC-insured banks that have failed since October 1, 2000.

### 2. FFIEC National Information Center (NIC)
**Direct Download Available: Yes**

| Dataset | Description | Format |
|---------|-------------|--------|
| Attributes (Active) | Entity characteristics for active institutions | ZIP/CSV |
| Attributes (Closed) | Entity characteristics for closed institutions | ZIP/CSV |
| Attributes (Branches) | Branch office attributes | ZIP/CSV |
| Relationships | Ownership relationships between institutions | ZIP/CSV |
| Transformations | Mergers, acquisitions, transformation events | ZIP/CSV |

Base URL: `https://www.ffiec.gov/npw/StaticData/DataDownload/CSV/`

Key fields:
- `ID_RSSD` - Unique institution identifier (never changes, never reused)
- `CTRL_IND = 1` - Indicates controlled relationship
- `BROAD_REG_CD = 1` - Indicates bank holding company

### 3. Chicago Fed Historical Data (1976-2000)
**Direct Download Available: Partial (requires navigation)**

- Format: SAS XPORT (.xpt)
- Coverage: Quarterly, 1976-2000
- URL: https://www.chicagofed.org/banking/financial-institution-reports/commercial-bank-data

To read SAS XPORT files:
```python
import pyreadstat
df, meta = pyreadstat.read_xport('filename.xpt')
```

### 4. FFIEC CDR (2001-Present)
**Direct Download Available: No (requires browser interaction)**

- URL: https://cdr.ffiec.gov/public/pws/downloadbulkdata.aspx
- Requires JavaScript and session cookies
- Programmatic access via SOAP API or Selenium

For programmatic access, see:
- https://github.com/call-report/ffiec-data-connect (Python wrapper for SOAP API)
- https://github.com/call-report/data-collector (Docker-based downloader)

## Output Structure

```
data/downloads/
├── fdic/
│   ├── fdic_failed_banks.csv
│   ├── fdic_failed_banks_legacy.csv
│   └── fdic_failures_api.json
├── nic/
│   ├── NIC_Attributes_Active.zip
│   ├── NIC_Attributes_Active/
│   │   └── *.csv
│   ├── NIC_Attributes_Closed.zip
│   ├── NIC_Relationships.zip
│   ├── NIC_Transformations.zip
│   └── NPW_Data_Dictionary.pdf
├── chicago_fed/
│   └── DOWNLOAD_INSTRUCTIONS.md
└── metadata/
    ├── download_manifest.json
    └── FFIEC_CDR_INSTRUCTIONS.md
```

## Requirements

```bash
pip install requests
```

Optional (for reading SAS files):
```bash
pip install pyreadstat
```

## NIC Data Dictionary

The NIC Data Dictionary (PDF) documents all fields in the bulk data tables:

### Attributes Table Fields (Key)
| Field | Description |
|-------|-------------|
| ID_RSSD | Unique institution identifier |
| NM_LGL | Legal name |
| ENTITY_TYPE | Institution type code |
| BROAD_REG_CD | Broad regulator code |
| CHTR_TYPE_CD | Charter type |
| INSUR_PRI_CD | Primary insurer |
| CITY | City |
| STATE | State code |
| ZIP_CD | ZIP code |
| OPEN_DT | Date opened |
| CLOSE_DT | Date closed |

### Relationships Table Fields (Key)
| Field | Description |
|-------|-------------|
| ID_RSSD_PARENT | Parent institution ID |
| ID_RSSD_OFFSPRING | Subsidiary institution ID |
| CTRL_IND | Control indicator (1=controlled) |
| EQUITY_IND | Equity ownership indicator |
| PCT_EQUITY | Percentage equity owned |
| START_DT | Relationship start date |
| END_DT | Relationship end date |

### Transformations Table Fields (Key)
| Field | Description |
|-------|-------------|
| ID_RSSD_PREDECESSOR | Predecessor institution ID |
| ID_RSSD_SUCCESSOR | Successor institution ID |
| TRNSFM_CD | Transformation type code |
| DT_TRANS | Transaction date |
| ACCT_METHOD | Accounting method |

## Related Documentation

- [FFIEC_CALL_REPORT_CODES.csv](../../Documentation/FFIEC_CALL_REPORT_CODES.csv) - MDRM code mappings
- [OCC_FAILURE_CAUSE_CODES.csv](../../Documentation/OCC_FAILURE_CAUSE_CODES.csv) - Historical failure classifications
- [FFIEC_DATA_SOURCES_REFERENCE.md](../../Documentation/FFIEC_DATA_SOURCES_REFERENCE.md) - Comprehensive reference

## Sources

- [FDIC Bank Failures](https://www.fdic.gov/bank-failures)
- [FFIEC NIC Data Download](https://www.ffiec.gov/npw/FinancialReport/DataDownload)
- [FFIEC CDR](https://cdr.ffiec.gov/public/)
- [Chicago Fed Commercial Bank Data](https://www.chicagofed.org/banking/financial-institution-reports/commercial-bank-data)
- [Federal Reserve MDRM](https://www.federalreserve.gov/apps/mdrm/)
