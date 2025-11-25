#!/usr/bin/env python3
"""
FFIEC/NIC/FDIC Data Downloader
==============================

Downloads publicly available banking regulatory data from:
1. FDIC - Failed bank list and BankFind API data
2. FFIEC NIC - National Information Center bulk data (Attributes, Relationships, Transformations)
3. Chicago Fed - Historical call report data (1976-2000) in SAS format
4. FFIEC CDR - Call report data (requires browser/selenium for bulk downloads)

Author: Failing Banks R Replication Project
Date: November 2025
License: MIT

Usage:
    python ffiec_nic_downloader.py --all           # Download all available data
    python ffiec_nic_downloader.py --fdic          # Download FDIC failed banks list
    python ffiec_nic_downloader.py --nic           # Download NIC bulk data
    python ffiec_nic_downloader.py --chicago-fed   # Download Chicago Fed historical data
    python ffiec_nic_downloader.py --list          # List available downloads

Sources:
    - FDIC Failed Banks: https://www.fdic.gov/bank-failures/download-data.csv
    - FFIEC NIC Data: https://www.ffiec.gov/npw/FinancialReport/DataDownload
    - Chicago Fed: https://www.chicagofed.org/banking/financial-institution-reports/commercial-bank-data
    - FFIEC CDR: https://cdr.ffiec.gov/public/pws/downloadbulkdata.aspx
"""

import os
import sys
import argparse
import requests
import zipfile
import io
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict
import json
import time

# Configuration
DEFAULT_OUTPUT_DIR = Path("./data/downloads")
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

# =============================================================================
# DATA SOURCE DEFINITIONS
# =============================================================================

DATA_SOURCES = {
    "fdic_failed_banks": {
        "name": "FDIC Failed Bank List",
        "description": "List of all FDIC-insured banks that have failed since October 1, 2000",
        "url": "https://www.fdic.gov/bank-failures/download-data.csv",
        "format": "csv",
        "direct_download": True,
        "filename": "fdic_failed_banks.csv"
    },
    "fdic_failed_banks_legacy": {
        "name": "FDIC Failed Bank List (Legacy URL)",
        "description": "Alternative URL for failed bank list",
        "url": "https://www.fdic.gov/resources/resolutions/bank-failures/failed-bank-list/banklist.csv",
        "format": "csv",
        "direct_download": True,
        "filename": "fdic_failed_banks_legacy.csv"
    },
    "nic_data_dictionary": {
        "name": "NIC Data Dictionary",
        "description": "Documentation for NIC bulk data tables (Attributes, Relationships, Transformations)",
        "url": "https://www.ffiec.gov/npw/StaticData/DataDownload/NPW%20Data%20Dictionary.pdf",
        "format": "pdf",
        "direct_download": True,
        "filename": "NPW_Data_Dictionary.pdf"
    },
    "nic_attributes_csv": {
        "name": "NIC Attributes Table (CSV)",
        "description": "Institution attributes data - entity characteristics",
        "url": "https://www.ffiec.gov/npw/StaticData/DataDownload/CSV/CSV_ATTRIBUTES_ACTIVE.zip",
        "format": "zip",
        "direct_download": True,
        "filename": "NIC_Attributes_Active.zip"
    },
    "nic_attributes_closed_csv": {
        "name": "NIC Attributes Table - Closed Institutions (CSV)",
        "description": "Attributes for closed/failed institutions",
        "url": "https://www.ffiec.gov/npw/StaticData/DataDownload/CSV/CSV_ATTRIBUTES_CLOSED.zip",
        "format": "zip",
        "direct_download": True,
        "filename": "NIC_Attributes_Closed.zip"
    },
    "nic_attributes_branches_csv": {
        "name": "NIC Attributes Table - Branches (CSV)",
        "description": "Branch office attributes",
        "url": "https://www.ffiec.gov/npw/StaticData/DataDownload/CSV/CSV_ATTRIBUTES_BRANCHES.zip",
        "format": "zip",
        "direct_download": True,
        "filename": "NIC_Attributes_Branches.zip"
    },
    "nic_relationships_csv": {
        "name": "NIC Relationships Table (CSV)",
        "description": "Ownership relationships between institutions",
        "url": "https://www.ffiec.gov/npw/StaticData/DataDownload/CSV/CSV_RELATIONSHIPS.zip",
        "format": "zip",
        "direct_download": True,
        "filename": "NIC_Relationships.zip"
    },
    "nic_transformations_csv": {
        "name": "NIC Transformations Table (CSV)",
        "description": "Mergers, acquisitions, and other transformation events",
        "url": "https://www.ffiec.gov/npw/StaticData/DataDownload/CSV/CSV_TRANSFORMATIONS.zip",
        "format": "zip",
        "direct_download": True,
        "filename": "NIC_Transformations.zip"
    }
}

# Chicago Fed historical data - SAS XPORT format (1976-2000)
CHICAGO_FED_YEARS = list(range(1976, 2001))
CHICAGO_FED_QUARTERS = ['0331', '0630', '0930', '1231']

# FDIC BankFind API endpoints
FDIC_API_BASE = "https://banks.data.fdic.gov/api"
FDIC_API_ENDPOINTS = {
    "failures": "/failures",
    "institutions": "/institutions",
    "financials": "/financials",
    "history": "/history",
    "locations": "/locations"
}


# =============================================================================
# DOWNLOADER CLASS
# =============================================================================

class FFIECDownloader:
    """Main downloader class for FFIEC/NIC/FDIC data."""

    def __init__(self, output_dir: Path = DEFAULT_OUTPUT_DIR, verbose: bool = True):
        self.output_dir = Path(output_dir)
        self.verbose = verbose
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": USER_AGENT})

        # Create output directories
        self.output_dir.mkdir(parents=True, exist_ok=True)
        (self.output_dir / "fdic").mkdir(exist_ok=True)
        (self.output_dir / "nic").mkdir(exist_ok=True)
        (self.output_dir / "chicago_fed").mkdir(exist_ok=True)
        (self.output_dir / "metadata").mkdir(exist_ok=True)

    def log(self, message: str):
        """Print log message if verbose mode is on."""
        if self.verbose:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            print(f"[{timestamp}] {message}")

    def download_file(self, url: str, output_path: Path, description: str = "") -> bool:
        """Download a file from URL to output path."""
        try:
            self.log(f"Downloading: {description or url}")
            response = self.session.get(url, stream=True, timeout=120)
            response.raise_for_status()

            total_size = int(response.headers.get('content-length', 0))
            downloaded = 0

            with open(output_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        if self.verbose and total_size > 0:
                            pct = (downloaded / total_size) * 100
                            print(f"\r  Progress: {pct:.1f}%", end="", flush=True)

            if self.verbose and total_size > 0:
                print()  # New line after progress

            self.log(f"  Saved to: {output_path}")
            return True

        except requests.exceptions.RequestException as e:
            self.log(f"  ERROR: Failed to download {url}: {e}")
            return False

    def extract_zip(self, zip_path: Path, extract_dir: Path) -> List[Path]:
        """Extract a zip file and return list of extracted files."""
        extracted = []
        try:
            with zipfile.ZipFile(zip_path, 'r') as zf:
                zf.extractall(extract_dir)
                extracted = [extract_dir / name for name in zf.namelist()]
            self.log(f"  Extracted {len(extracted)} files to {extract_dir}")
        except zipfile.BadZipFile as e:
            self.log(f"  ERROR: Bad zip file {zip_path}: {e}")
        return extracted

    # -------------------------------------------------------------------------
    # FDIC Downloads
    # -------------------------------------------------------------------------

    def download_fdic_failed_banks(self) -> bool:
        """Download FDIC failed banks list."""
        self.log("=" * 60)
        self.log("Downloading FDIC Failed Banks Data")
        self.log("=" * 60)

        success = True
        for key in ["fdic_failed_banks", "fdic_failed_banks_legacy"]:
            source = DATA_SOURCES[key]
            output_path = self.output_dir / "fdic" / source["filename"]
            if not self.download_file(source["url"], output_path, source["name"]):
                success = False

        return success

    def download_fdic_api_data(self, endpoint: str, params: Dict = None,
                                limit: int = 10000) -> Optional[Dict]:
        """Download data from FDIC BankFind API."""
        url = f"{FDIC_API_BASE}{endpoint}"
        params = params or {}
        params["limit"] = limit
        params["format"] = "json"

        try:
            self.log(f"Fetching from FDIC API: {endpoint}")
            response = self.session.get(url, params=params, timeout=60)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            self.log(f"  ERROR: API request failed: {e}")
            return None

    def download_fdic_failures_api(self) -> bool:
        """Download comprehensive failure data from FDIC API."""
        self.log("Downloading FDIC Failures via API...")

        data = self.download_fdic_api_data("/failures", limit=10000)
        if data:
            output_path = self.output_dir / "fdic" / "fdic_failures_api.json"
            with open(output_path, 'w') as f:
                json.dump(data, f, indent=2)
            self.log(f"  Saved API data to: {output_path}")

            # Also save as CSV if possible
            if "data" in data:
                self._json_to_csv(data["data"], self.output_dir / "fdic" / "fdic_failures_api.csv")
            return True
        return False

    def _json_to_csv(self, records: List[Dict], output_path: Path):
        """Convert list of dictionaries to CSV."""
        if not records:
            return

        import csv
        headers = list(records[0].keys())

        with open(output_path, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=headers)
            writer.writeheader()
            writer.writerows(records)

        self.log(f"  Saved CSV: {output_path}")

    # -------------------------------------------------------------------------
    # NIC Downloads
    # -------------------------------------------------------------------------

    def download_nic_data(self) -> bool:
        """Download all NIC bulk data files."""
        self.log("=" * 60)
        self.log("Downloading FFIEC NIC Bulk Data")
        self.log("=" * 60)

        success = True
        nic_sources = [k for k in DATA_SOURCES if k.startswith("nic_")]

        for key in nic_sources:
            source = DATA_SOURCES[key]
            output_path = self.output_dir / "nic" / source["filename"]

            if self.download_file(source["url"], output_path, source["name"]):
                # Extract if it's a zip file
                if source["format"] == "zip":
                    extract_dir = self.output_dir / "nic" / Path(source["filename"]).stem
                    extract_dir.mkdir(exist_ok=True)
                    self.extract_zip(output_path, extract_dir)
            else:
                success = False

        return success

    # -------------------------------------------------------------------------
    # Chicago Fed Downloads
    # -------------------------------------------------------------------------

    def download_chicago_fed_data(self, years: List[int] = None) -> bool:
        """
        Download Chicago Fed historical call report data (1976-2000).

        Note: These files are in SAS XPORT format (.xpt).
        Use the sas7bdat or pyreadstat Python libraries to read them.
        """
        self.log("=" * 60)
        self.log("Downloading Chicago Fed Historical Data (1976-2000)")
        self.log("=" * 60)

        years = years or CHICAGO_FED_YEARS
        base_url = "https://www.chicagofed.org/banking/financial-institution-reports/commercial-bank-data"

        # Note: Chicago Fed data requires navigating their website
        # The actual download URLs are dynamically generated
        self.log("NOTE: Chicago Fed historical data (1976-2000) is in SAS XPORT format.")
        self.log("      Direct download URLs are not available - visit:")
        self.log("      https://www.chicagofed.org/banking/financial-institution-reports/commercial-bank-data")
        self.log("")
        self.log("To read SAS XPORT files in Python, use:")
        self.log("  pip install pyreadstat")
        self.log("  import pyreadstat")
        self.log("  df, meta = pyreadstat.read_xport('filename.xpt')")

        # Create a reference file with download instructions
        instructions = """# Chicago Fed Commercial Bank Data (1976-2000)

## Overview
Historical call report data from the Federal Reserve Bank of Chicago.
Data is available quarterly from 1976 to 2000.

## Format
Files are in SAS XPORT format (.xpt)

## How to Download
1. Visit: https://www.chicagofed.org/banking/financial-institution-reports/commercial-bank-data-complete-1976-2000
2. Select the year and quarter you need
3. Download the compressed zip file containing SAS XPORT files

## How to Read in Python
```python
import pyreadstat

# Read SAS XPORT file
df, meta = pyreadstat.read_xport('call_report_1990q4.xpt')

# View column labels
print(meta.column_names_to_labels)
```

## How to Read in R
```r
library(haven)
df <- read_xpt("call_report_1990q4.xpt")
```

## Available Years
1976, 1977, 1978, 1979, 1980, 1981, 1982, 1983, 1984, 1985,
1986, 1987, 1988, 1989, 1990, 1991, 1992, 1993, 1994, 1995,
1996, 1997, 1998, 1999, 2000

## Quarters
- Q1: March 31 (0331)
- Q2: June 30 (0630)
- Q3: September 30 (0930)
- Q4: December 31 (1231)

## Alternative: FFIEC CDR for 2001+
For data from 2001 onwards, use the FFIEC CDR:
https://cdr.ffiec.gov/public/pws/downloadbulkdata.aspx
"""

        instructions_path = self.output_dir / "chicago_fed" / "DOWNLOAD_INSTRUCTIONS.md"
        with open(instructions_path, 'w') as f:
            f.write(instructions)
        self.log(f"  Saved instructions to: {instructions_path}")

        return True

    # -------------------------------------------------------------------------
    # FFIEC CDR Downloads
    # -------------------------------------------------------------------------

    def download_cdr_info(self) -> bool:
        """
        Provide information about FFIEC CDR downloads.

        Note: CDR bulk downloads require browser interaction (JavaScript/cookies).
        This method provides instructions for manual download or using Selenium.
        """
        self.log("=" * 60)
        self.log("FFIEC CDR Bulk Download Information")
        self.log("=" * 60)

        instructions = """# FFIEC Central Data Repository (CDR) Bulk Downloads

## Overview
The FFIEC CDR provides bulk downloads of Call Report data (FFIEC 031, 041, 051).

## Important Note
**Direct URL downloads are NOT possible** for CDR bulk data.
The website requires JavaScript interaction and session cookies.

## How to Download Manually
1. Visit: https://cdr.ffiec.gov/public/pws/downloadbulkdata.aspx
2. Select the report type (e.g., "Call Reports - Single Period")
3. Select the time period
4. Select the format (CSV recommended)
5. Click Download

## Available Data Types
1. **Balance Sheet, Income Statement, Past Due** (Schedules RC, RI, RC-N)
   - Tab delimited format
   - All filers for selected year(s)

2. **Call Reports - Single Period**
   - All filers for a single quarter
   - XBRL or CSV format

## Programmatic Access Options

### Option 1: FFIEC Webservice (SOAP API)
```python
pip install ffiec-data-connect

from ffiec_data_connect import methods, credentials

creds = credentials.WebserviceCredentials(username="user", password="pass")
# Note: Requires FFIEC webservice account registration
```

### Option 2: Docker-based Data Collector
See: https://github.com/call-report/data-collector

### Option 3: Selenium Automation
```python
from selenium import webdriver
from selenium.webdriver.common.by import By

driver = webdriver.Chrome()
driver.get("https://cdr.ffiec.gov/public/pws/downloadbulkdata.aspx")
# ... navigate and download
```

## Data Coverage
- 2001 - Present (quarterly)
- All FDIC-insured commercial banks
- Schedules: RC, RC-A through RC-V, RI, RI-A through RI-E

## Related Resources
- CDR Help: https://cdr.ffiec.gov/public/HelpFiles/DownloadHelp.htm
- Taxonomy: https://cdr.ffiec.gov/public/DownloadTaxonomy.aspx
"""

        instructions_path = self.output_dir / "metadata" / "FFIEC_CDR_INSTRUCTIONS.md"
        with open(instructions_path, 'w') as f:
            f.write(instructions)
        self.log(f"  Saved CDR instructions to: {instructions_path}")

        return True

    # -------------------------------------------------------------------------
    # Main Download Methods
    # -------------------------------------------------------------------------

    def download_all(self) -> Dict[str, bool]:
        """Download all available data sources."""
        results = {}

        results["fdic_failed_banks"] = self.download_fdic_failed_banks()
        results["fdic_api"] = self.download_fdic_failures_api()
        results["nic_data"] = self.download_nic_data()
        results["chicago_fed_info"] = self.download_chicago_fed_data()
        results["cdr_info"] = self.download_cdr_info()

        # Save download manifest
        self._save_manifest(results)

        return results

    def _save_manifest(self, results: Dict[str, bool]):
        """Save download manifest with timestamps."""
        manifest = {
            "download_date": datetime.now().isoformat(),
            "output_directory": str(self.output_dir),
            "results": results,
            "data_sources": {k: v["description"] for k, v in DATA_SOURCES.items()}
        }

        manifest_path = self.output_dir / "metadata" / "download_manifest.json"
        with open(manifest_path, 'w') as f:
            json.dump(manifest, f, indent=2)
        self.log(f"Saved manifest to: {manifest_path}")

    def list_sources(self):
        """List all available data sources."""
        print("\n" + "=" * 70)
        print("AVAILABLE DATA SOURCES")
        print("=" * 70)

        print("\n[FDIC - Federal Deposit Insurance Corporation]")
        for key, source in DATA_SOURCES.items():
            if key.startswith("fdic"):
                print(f"  • {source['name']}")
                print(f"    {source['description']}")
                print(f"    URL: {source['url']}")
                print()

        print("\n[NIC - National Information Center]")
        for key, source in DATA_SOURCES.items():
            if key.startswith("nic"):
                print(f"  • {source['name']}")
                print(f"    {source['description']}")
                print(f"    URL: {source['url']}")
                print()

        print("\n[Chicago Fed - Historical Data]")
        print("  • Commercial Bank Data (1976-2000)")
        print("    Quarterly call report data in SAS XPORT format")
        print("    URL: https://www.chicagofed.org/banking/financial-institution-reports/commercial-bank-data")
        print()

        print("\n[FFIEC CDR - Central Data Repository]")
        print("  • Call Reports Bulk Download (2001-present)")
        print("    Requires browser interaction - no direct download URL")
        print("    URL: https://cdr.ffiec.gov/public/pws/downloadbulkdata.aspx")
        print()


# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Download FFIEC/NIC/FDIC banking regulatory data",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python ffiec_nic_downloader.py --all
  python ffiec_nic_downloader.py --fdic --nic
  python ffiec_nic_downloader.py --output-dir ./my_data
  python ffiec_nic_downloader.py --list

Data Sources:
  FDIC:       Failed bank lists and BankFind API
  NIC:        Institution attributes, relationships, transformations
  Chicago Fed: Historical call reports (1976-2000) - SAS format
  FFIEC CDR:  Modern call reports (2001+) - requires browser
        """
    )

    parser.add_argument("--all", action="store_true",
                        help="Download all available data")
    parser.add_argument("--fdic", action="store_true",
                        help="Download FDIC failed banks data")
    parser.add_argument("--nic", action="store_true",
                        help="Download NIC bulk data (attributes, relationships, transformations)")
    parser.add_argument("--chicago-fed", action="store_true",
                        help="Get Chicago Fed download instructions")
    parser.add_argument("--cdr", action="store_true",
                        help="Get FFIEC CDR download instructions")
    parser.add_argument("--list", action="store_true",
                        help="List all available data sources")
    parser.add_argument("--output-dir", type=str, default=str(DEFAULT_OUTPUT_DIR),
                        help=f"Output directory (default: {DEFAULT_OUTPUT_DIR})")
    parser.add_argument("--quiet", action="store_true",
                        help="Suppress progress output")

    args = parser.parse_args()

    # Initialize downloader
    downloader = FFIECDownloader(
        output_dir=Path(args.output_dir),
        verbose=not args.quiet
    )

    # Handle commands
    if args.list:
        downloader.list_sources()
        return

    if args.all:
        results = downloader.download_all()
        print("\n" + "=" * 50)
        print("DOWNLOAD SUMMARY")
        print("=" * 50)
        for source, success in results.items():
            status = "✓ Success" if success else "✗ Failed"
            print(f"  {source}: {status}")
        return

    # Individual downloads
    if args.fdic:
        downloader.download_fdic_failed_banks()
        downloader.download_fdic_failures_api()

    if args.nic:
        downloader.download_nic_data()

    if args.chicago_fed:
        downloader.download_chicago_fed_data()

    if args.cdr:
        downloader.download_cdr_info()

    # If no specific option, show help
    if not any([args.all, args.fdic, args.nic, args.chicago_fed, args.cdr]):
        parser.print_help()


if __name__ == "__main__":
    main()
