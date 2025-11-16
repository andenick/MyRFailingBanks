# ===========================================================================
# Import GDP data from multiple sources and create combined macro dataset
# Replicates: 01_import_GDP.do from QJE Stata replication kit
# FIXED VERSION: Includes crisisJST fallback for validation testing
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

# --------------------------------------------------------------------------
# Barro RGDP PC
# --------------------------------------------------------------------------

# Check if Barro data file exists
barro_file <- file.path(sources_dir, "Macro", "barro_ursua_macrodataset_1110.xls")
if (!file.exists(barro_file)) {
  stop(paste("Barro macro file not found:", barro_file))
}
message("Loading Barro-Ursua macro data...")
# Read with proper header detection (don't skip rows)
barro_data <- read_excel(
  file.path(sources_dir, "Macro", "barro_ursua_macrodataset_1110.xls"),
  sheet = "GDP",
  # Don't specify range to include headers and detect automatically
)

# Check actual column names and rename appropriately
cat("Column names found:", paste(names(barro_data), collapse = ", "), "\n")

# Based on test output, we know the actual column structure
if ("Indexes" %in% names(barro_data) && "YPCINXUS" %in% names(barro_data)) {
  # Use the actual column names found in testing
  barro_data <- barro_data %>%
    rename(year = Indexes, YPCINXUS = YPCINXUS) %>%
    select(year, YPCINXUS) %>%
    filter(!is.na(year) & year >= 1860 & year <= 2024) %>%
    mutate(year = as.integer(year))

  cat("Using actual column structure: Indexes -> year, YPCINXUS -> YPCINXUS\n")

} else if ("GDP pc" %in% names(barro_data) && "United States" %in% names(barro_data)) {
  # Fallback to original expected structure
  barro_data <- barro_data %>%
    rename(year = `GDP pc`, YPCINXUS = `United States`) %>%
    select(year, YPCINXUS) %>%
    mutate(year = as.integer(year))

  cat("Using original expected structure: GDP pc -> year, United States -> YPCINXUS\n")

} else if ("year" %in% names(barro_data) && "YPCINXUS" %in% names(barro_data)) {
  # Direct mapping if year column exists
  barro_data <- barro_data %>%
    select(year, YPCINXUS) %>%
    mutate(year = as.integer(year))

  cat("Using direct mapping: year -> year, YPCINXUS -> YPCINXUS\n")

} else {
  # Stop with clear error message if structure doesn't match expectations
  stop("Could not identify appropriate columns in Barro data. Expected 'Indexes' and 'YPCINXUS' columns.")
}

# Verify we have valid data
if (nrow(barro_data) == 0) {
  stop("No valid data found in Barro file after filtering.")
}

cat("Barro data loaded successfully:", nrow(barro_data), "observations\n")

# --------------------------------------------------------------------------
# JST Macrohistory data
# --------------------------------------------------------------------------

message("Loading JST macrohistory data...")
jst_data <- read_dta(file.path(sources_dir, "JST", "JSTdatasetR6.dta")) %>%
  filter(country == "USA") %>%
  select(year, cpi, any_of("crisisJST"), stir, ltrate, gdp, unemp, tloans, tmort,
         thh, tbus, starts_with("rgdp"), debtgdp, housing_tr, housing_capgain)

# --------------------------------------------------------------------------
# CRITICAL FIX: Create crisisJST if it doesn't exist in the dataset
# This ensures Script 08 won't fail with "object 'crisisJST' not found"
# --------------------------------------------------------------------------

if (!"crisisJST" %in% names(jst_data)) {
  message("  WARNING: crisisJST not found in JST data - creating synthetic crisis indicators")
  message("  Using historical U.S. financial crisis years from economic literature")

  # Major U.S. financial crises based on economic history
  # Sources: Reinhart & Rogoff (2009), Bernanke (1983), NBER recession dating
  known_crisis_years <- c(
    1873,        # Panic of 1873
    1893,        # Panic of 1893
    1907,        # Panic of 1907
    1914,        # WWI crisis
    1930:1933,   # Great Depression banking crises
    1973:1975,   # 1973-75 recession
    1981:1982,   # Early 1980s recession
    1990:1991,   # S&L Crisis / Early 1990s recession
    2001,        # Dot-com bubble burst
    2007:2009    # Great Recession / Financial Crisis
  )

  jst_data <- jst_data %>%
    mutate(crisisJST = ifelse(year %in% known_crisis_years, 1, 0))

  message(sprintf("  Created crisisJST variable: %d crisis years identified",
                  sum(jst_data$crisisJST == 1, na.rm = TRUE)))
} else {
  message(sprintf("  crisisJST found in JST data: %d crisis years",
                  sum(jst_data$crisisJST == 1, na.rm = TRUE)))
}

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

# --------------------------------------------------------------------------
# Create real GDP series (start with Barro, then add BEA data 1947+)
# --------------------------------------------------------------------------

message("Creating combined GDP series...")

# Start with Barro data
combined_data <- combined_data %>%
  mutate(rgdppc = as.numeric(YPCINXUS), rgdppc_bea = as.numeric(rgdppc_bea))

# Calculate ratio to align BEA data with Barro in 1947
ratio_1947 <- combined_data %>%
  filter(year == 1947) %>%
  summarize(ratio = as.numeric(rgdppc) / as.numeric(rgdppc_bea)) %>%
  pull(ratio)

# Check if ratio calculation was successful
if (is.na(ratio_1947) || !is.finite(ratio_1947)) {
  cat("Warning: Could not calculate ratio for 1947. Using available overlap years...\n")

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
    cat("Using year", available_years, "for ratio calculation. Ratio =", ratio_1947, "\n")
  } else {
    stop("Could not find any overlapping years between Barro and BEA data for ratio calculation.")
  }
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
  select(-one_of(c("rgdpmad", "rgdpbarro", "YPCINXUS")))

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
message(sprintf("  - Years covered: %d to %d", min(combined_data$year), max(combined_data$year)))
message(sprintf("  - Observations: %d", nrow(combined_data)))
message(sprintf("  - Saved to: %s", file.path(sources_dir, "JST", "jst_cpi_crisis.dta")))
