# ===========================================================================
# Import Corporate and Government Bond Yields from GFD
# Replicates: 03_import_GFD_Yields.do from QJE Stata replication kit
# ===========================================================================

library(readxl)
library(haven)
library(dplyr)
library(tidyr)
library(here)

# Source the setup script for directory paths

# --------------------------------------------------------------------------
# Load GFD Yields data
# --------------------------------------------------------------------------

message("Loading GFD bond yields data...")

# Load from "Price Data" sheet
yields_raw <- read_excel(
  file.path(sources_dir, "GFD", "GFD_Yields.xlsx"),
  sheet = "Price Data"
) %>%
  select(Ticker, Close, Date)

# --------------------------------------------------------------------------
# Process dates and convert to annual
# --------------------------------------------------------------------------

message("Processing dates and converting to annual frequency...")

yields_data <- yields_raw %>%
  # Parse date (format: MM/DD/YYYY)
  mutate(
    date_parts = strsplit(as.character(Date), "/"),
    month = as.integer(sapply(date_parts, function(x) x[1])),
    day = as.integer(sapply(date_parts, function(x) x[2])),
    year = as.integer(sapply(date_parts, function(x) x[3]))
  ) %>%
  select(month, day, year, Ticker, Close) %>%
  # Convert to annual (last non-missing observation per year)
  group_by(year, Ticker) %>%
  summarize(
    yield_value = last(Close[!is.na(Close)]),
    .groups = "drop"
  ) %>%
  # Reshape wide
  pivot_wider(
    names_from = Ticker,
    values_from = yield_value,
    names_prefix = "yield_"
  )

# --------------------------------------------------------------------------
# Create spread variables
# --------------------------------------------------------------------------

message("Creating spread variables...")

yields_final <- yields_data %>%
  mutate(
    # BAA-10Y Treasury spread
    spr_baa_10ytreas = yield_MOCBAAD - yield_IGUSA10D,
    
    # AAA-10Y Treasury spread
    spr_aaa_10ytreas = yield_MOCAAAD - yield_IGUSA10D,
    
    # High-yield railroad-10Y Treasury spread
    spr_HYrail_10ytreas_aug = yield_INUSAMRM - yield_IGUSA10D,
    
    # Term spread (10Y - 2Y)
    spr_10_2 = yield_IGUSA10D - yield_IGUSA2D
  )

# Add variable labels (as comments for documentation)
# yield_IGUSA10D: 10-year Govt Bond Constant Maturity Yield
# yield_IGUSA2D: 2-year Govt Bond Constant Maturity Yield
# yield_INUSADJD: Dow Jones Corporate Bond Yield
# yield_SPBCAAAW: S&P AAA Bond Composite Yield
# yield_SPBRAAAW: S&P AAA Railroad Bond Yield
# yield_MOCAAAD: Moody's Corporate AAA Yield (with GFD Extension)
# yield_MOCBAAD: Moody's Corporate BAA Yield
# yield_INUSAMRM: USA Macaulay High Grade Railroad Bond Yield

# --------------------------------------------------------------------------
# Save processed data
# --------------------------------------------------------------------------

message("Saving processed yields data...")

# Save to sources/GFD/ as Stata file (becomes input for later scripts)
write_dta(
  yields_final,
  file.path(sources_dir, "GFD", "GFD_US_Yields.dta")
)

# Also save to dataclean for convenience
saveRDS(
  yields_final,
  file.path(dataclean_dir, "yields_data.rds")
)

message("03_import_GFD_Yields.R completed successfully")
message(sprintf("  - Years covered: %d to %d", min(yields_final$year, na.rm = TRUE), max(yields_final$year, na.rm = TRUE)))
message(sprintf("  - Observations: %d", nrow(yields_final)))
message(sprintf("  - Saved to: %s", file.path(sources_dir, "GFD", "GFD_US_Yields.dta")))
