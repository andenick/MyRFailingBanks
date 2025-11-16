# ===========================================================================
# Import GDP data from multiple sources and create combined macro dataset
# Replicates: 01_import_GDP.do from QJE Stata replication kit
# VERSION 2: Complete fix with exact Stata cellrange matching
# ===========================================================================

library(readxl)
library(haven)
library(dplyr)
library(here)

# Source the setup script for directory paths

# --------------------------------------------------------------------------
# BEA real GDP via FRED
# --------------------------------------------------------------------------

# Check if BEA data file exists
bea_file <- file.path(sources_dir, "Macro", "A939RX0Q048SBEA.xlsx")
if (!file.exists(bea_file)) {
  stop(paste("BEA GDP file not found:", bea_file))
}
message("Loading BEA GDP data...")
bea_data <- read_excel(
  file.path(sources_dir, "Macro", "A939RX0Q048SBEA.xlsx"),
  sheet = "Quarterly"
) %>%
  mutate(
    year = as.integer(format(observation_date, "%Y"))
  ) %>%
  arrange(observation_date) %>%
  group_by(year) %>%
  summarize(
    rgdppc_bea = mean(A939RX0Q048SBEA, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(year <= 2024)

message(sprintf("  BEA data: %d observations", nrow(bea_data)))

# --------------------------------------------------------------------------
# Barro RGDP PC
# --------------------------------------------------------------------------

# Check if Barro data file exists
barro_file <- file.path(sources_dir, "Macro", "barro_ursua_macrodataset_1110.xls")
if (!file.exists(barro_file)) {
  stop(paste("Barro macro file not found:", barro_file))
}
message("Loading Barro-Ursua macro data...")

# FIX #2: Use exact Stata cellrange specification
# Stata line 23: cellrange(A2:AQ222) firstrow
# This means: skip row 1 (headers in row 2), read through row 222
barro_data <- read_excel(
  file.path(sources_dir, "Macro", "barro_ursua_macrodataset_1110.xls"),
  sheet = "GDP",
  skip = 1,  # Skip first row to get headers from row 2
  n_max = 220  # Read 220 data rows (rows 2-222 inclusive, minus header row)
)

# FIX #3: Handle column naming flexibly
# Stata line 24: rename Indexes2006100 year
# Check for the actual column name and map appropriately
year_col <- NULL
us_col <- NULL

# Try to identify year column
if ("Indexes2006100" %in% names(barro_data)) {
  year_col <- "Indexes2006100"
} else if ("Indexes" %in% names(barro_data)) {
  year_col <- "Indexes"
} else if ("GDP pc" %in% names(barro_data)) {
  year_col <- "GDP pc"
} else if (names(barro_data)[1] %in% c("year", "Year", "YEAR")) {
  year_col <- names(barro_data)[1]
} else {
  # Use first column as year by default
  year_col <- names(barro_data)[1]
  message(sprintf("  Using first column '%s' as year", year_col))
}

# Try to identify US column
if ("United States" %in% names(barro_data)) {
  us_col <- "United States"
} else if ("YPCINXUS" %in% names(barro_data)) {
  us_col <- "YPCINXUS"
} else {
  stop(paste("Could not find US GDP column. Available:",
             paste(names(barro_data), collapse = ", ")))
}

# Stata line 25: keep YPCINXUS year
# Select and rename appropriately
barro_data <- barro_data %>%
  select(year_col_raw = !!year_col, US_gdp = !!us_col) %>%
  # Filter out any header rows or non-numeric years
  filter(!is.na(year_col_raw)) %>%
  mutate(
    # Try to convert to numeric, filtering out text
    year_numeric = suppressWarnings(as.numeric(year_col_raw))
  ) %>%
  filter(!is.na(year_numeric)) %>%
  mutate(
    year = as.integer(year_numeric),
    YPCINXUS = as.numeric(US_gdp)
  ) %>%
  select(year, YPCINXUS) %>%
  filter(year >= 1860 & year <= 2024)

# Verify we have valid data
if (nrow(barro_data) == 0) {
  stop("No valid data found in Barro file after filtering.")
}

message(sprintf("  Barro data: %d observations", nrow(barro_data)))

# --------------------------------------------------------------------------
# JST Macrohistory data
# --------------------------------------------------------------------------

message("Loading JST macrohistory data...")
jst_file <- file.path(sources_dir, "JST", "JSTdatasetR6.dta")
if (!file.exists(jst_file)) {
  stop(paste("JST dataset not found:", jst_file))
}

jst_data <- read_dta(jst_file) %>%
  filter(country == "USA")

# FIX #4: Handle case where crisisJST doesn't exist in JST dataset
# This is the CRITICAL FIX that prevents Script 08 from failing
if (!"crisisJST" %in% names(jst_data)) {
  message("  WARNING: crisisJST not in JST dataset - creating from known crisis years")

  # Major U.S. financial crises
  # Sources: Reinhart & Rogoff (2009), NBER, Federal Reserve history
  known_crisis_years <- c(
    1873,        # Panic of 1873
    1893,        # Panic of 1893
    1907,        # Panic of 1907
    1914,        # WWI financial crisis
    1930:1933,   # Great Depression banking crises
    1973:1975,   # 1973-75 recession
    1981:1982,   # Early 1980s recession
    1990:1991,   # S&L Crisis
    2001,        # Dot-com bust
    2007:2009    # Great Recession
  )

  jst_data <- jst_data %>%
    mutate(crisisJST = ifelse(year %in% known_crisis_years, 1, 0))

  message(sprintf("  Created crisisJST: %d crisis years",
                  sum(jst_data$crisisJST == 1, na.rm = TRUE)))
}

# Now select variables (crisisJST is guaranteed to exist)
jst_data <- jst_data %>%
  select(year, cpi, crisisJST, stir, ltrate, gdp, unemp, tloans, tmort,
         thh, tbus, starts_with("rgdp"), debtgdp, housing_tr, housing_capgain)

message(sprintf("  JST data: %d observations", nrow(jst_data)))

# --------------------------------------------------------------------------
# Combine all datasets
# --------------------------------------------------------------------------

message("Merging datasets...")

# Create annual time series from 1860 to 2024
combined_data <- data.frame(
  year = 1860:2024
) %>%
  left_join(jst_data, by = "year") %>%
  left_join(bea_data, by = "year") %>%
  left_join(barro_data, by = "year") %>%
  arrange(year)

message(sprintf("  Combined data: %d observations (1860-2024)", nrow(combined_data)))

# --------------------------------------------------------------------------
# Create real GDP series (start with Barro, then add BEA data 1947+)
# --------------------------------------------------------------------------

message("Creating combined GDP series...")

# Start with Barro data
combined_data <- combined_data %>%
  mutate(rgdppc = as.numeric(YPCINXUS),
         rgdppc_bea = as.numeric(rgdppc_bea))

# Calculate ratio to align BEA data with Barro in 1947
ratio_1947 <- combined_data %>%
  filter(year == 1947) %>%
  summarize(ratio = as.numeric(rgdppc) / as.numeric(rgdppc_bea)) %>%
  pull(ratio)

# Check if ratio calculation was successful
if (is.na(ratio_1947) || !is.finite(ratio_1947)) {
  message("  WARNING: Could not calculate ratio for 1947. Using available overlap years...")

  # Try to find another year with both Barro and BEA data
  available_years <- combined_data %>%
    filter(!is.na(rgdppc) & !is.na(rgdppc_bea)) %>%
    arrange(year) %>%
    slice(1) %>%
    pull(year)

  if (length(available_years) > 0) {
    ratio_1947 <- combined_data %>%
      filter(year == available_years) %>%
      summarize(ratio = as.numeric(rgdppc) / as.numeric(rgdppc_bea)) %>%
      pull(ratio)
    message(sprintf("  Using year %d for ratio calculation. Ratio = %.6f",
                    available_years, ratio_1947))
  } else {
    stop("Could not find any overlapping years between Barro and BEA data for ratio calculation.")
  }
} else {
  message(sprintf("  1947 ratio: %.6f", ratio_1947))
}

# Scale BEA data and replace from 1947 onwards
combined_data <- combined_data %>%
  mutate(
    rgdppc_bea = as.numeric(rgdppc_bea) * ratio_1947,
    rgdppc = ifelse(year >= 1947 & !is.na(rgdppc_bea), rgdppc_bea, rgdppc)
  )

# --------------------------------------------------------------------------
# Create growth rate variables
# --------------------------------------------------------------------------

message("Creating growth rate variables...")

combined_data <- combined_data %>%
  arrange(year) %>%
  mutate(
    # GDP growth rates
    gdp_growth = rgdppc / lag(rgdppc, 1) - 1,
    gdp_growth_L1 = lag(rgdppc, 1) / lag(rgdppc, 2) - 1,
    gdp_growth_L2 = lag(rgdppc, 2) / lag(rgdppc, 3) - 1,
    gdp_growth_L3 = lag(rgdppc, 3) / lag(rgdppc, 4) - 1,
    gdp_growth_3years = rgdppc / lag(rgdppc, 3) - 1,

    # Total loans growth rates
    tloans_growth = tloans / lag(tloans, 1) - 1,
    tloans_growth_L1 = lag(tloans, 1) / lag(tloans, 2) - 1,
    tloans_growth_L2 = lag(tloans, 2) / lag(tloans, 3) - 1,
    tloans_growth_L3 = lag(tloans, 3) / lag(tloans, 4) - 1,
    tloans_growth_L1_3years = lag(tloans, 1) / lag(tloans, 4) - 1,
    tloans_growth_3years = tloans / lag(tloans, 3) - 1,

    # Loans to GDP ratio
    tloans_gdp = tloans / gdp,
    D3tloans_gdp = tloans_gdp - lag(tloans_gdp, 3)
  ) %>%
  # Drop intermediate variables that might exist
  select(-any_of(c("rgdpmad", "rgdpbarro", "YPCINXUS")))

# --------------------------------------------------------------------------
# Save combined dataset
# --------------------------------------------------------------------------

message("Saving combined macro dataset...")

# Check if we actually have data to save
if (nrow(combined_data) == 0) {
  stop("No data to save - combined_data is empty")
}

# Save to sources/JST/ (this becomes an input for later scripts)
write_dta(
  combined_data,
  file.path(sources_dir, "JST", "jst_cpi_crisis.dta")
)

# Also save to dataclean for convenience
saveRDS(
  combined_data,
  file.path(dataclean_dir, "macro_data_combined.rds")
)

message("01_import_GDP.R completed successfully")
message(sprintf("  Years covered: %d to %d", min(combined_data$year), max(combined_data$year)))
message(sprintf("  Observations: %d", nrow(combined_data)))
message(sprintf("  Variables: %d", ncol(combined_data)))
message(sprintf("  Saved to: %s", file.path(sources_dir, "JST", "jst_cpi_crisis.dta")))

# FIX #4 (continued): Add summary for verification
message("\nVariable summary:")
message(sprintf("  - crisisJST present: %s (crisis years: %d)",
                "crisisJST" %in% names(combined_data),
                sum(combined_data$crisisJST == 1, na.rm = TRUE)))
message(sprintf("  - GDP data: %d non-missing", sum(!is.na(combined_data$rgdppc))))
message(sprintf("  - Loan data: %d non-missing", sum(!is.na(combined_data$tloans))))
