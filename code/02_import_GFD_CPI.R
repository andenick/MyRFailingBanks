# ===========================================================================
# Import CPI from GFD (back to 1790)
# Replicates: 02_import_GFD_CPI.do from QJE Stata replication kit
# ===========================================================================

library(readr)
library(haven)
library(dplyr)
library(here)
library(lubridate)

# Source the setup script for directory paths

# --------------------------------------------------------------------------
# Load GFD CPI data
# --------------------------------------------------------------------------

message("Loading GFD CPI data...")

# Load CSV data (skip first 2 rows as per Stata code)
cpi_raw <- read_csv(
  file.path(sources_dir, "GFD", "US_CPI_GFD_202504.csv"),
  skip = 3,
  col_names = c("date_str", "ticker", "open", "high", "low", "cpi_gfd"),
  col_types = "ccnnnd",
  na = "NA"
) %>%
  filter(!is.na(cpi_gfd))

# --------------------------------------------------------------------------
# Parse dates and create annual series
# --------------------------------------------------------------------------

message("Processing dates and creating annual CPI series...")

cpi_data <- cpi_raw %>%
  # Parse date string using lubridate
  mutate(
    date = as.Date(date_str, format = "%Y/%m/%d"),
    year = as.integer(format(date, "%Y")),
    month = as.integer(format(date, "%m")),
    day = as.integer(format(date, "%d"))
  ) %>%
  select(year, month, day, date, cpi_gfd) %>%
  # Keep only December 31 observations for annual series
  filter(month == 12, day == 31) %>%
  arrange(year) %>%
  # Create inflation measures
  mutate(
    inf_cpi_1years = cpi_gfd / lag(cpi_gfd, 1) - 1,
    inf_cpi_2years = cpi_gfd / lag(cpi_gfd, 2) - 1,
    inf_cpi_3years = cpi_gfd / lag(cpi_gfd, 3) - 1,
    inf_cpi_5years = cpi_gfd / lag(cpi_gfd, 5) - 1
  ) %>%
  select(year, cpi_gfd, starts_with("inf_cpi_"))

# --------------------------------------------------------------------------
# Save processed CPI data
# --------------------------------------------------------------------------

message("Saving processed CPI data...")
# Debug: Check data before saving
message(sprintf("  - CPI data has %d rows", nrow(cpi_data)))
if (nrow(cpi_data) > 0) {
  message(sprintf("  - Year range: %d to %d", min(cpi_data$year, na.rm = TRUE), max(cpi_data$year, na.rm = TRUE)))
}

# Save to sources/GFD/ (this becomes an input for later scripts)
write_dta(
  cpi_data,
  file.path(sources_dir, "GFD", "US_CPI_GFD_annual.dta")
)

# Also save to dataclean for convenience
saveRDS(
  cpi_data,
  file.path(dataclean_dir, "cpi_data.rds")
)

message("02_import_GFD_CPI.R completed successfully")
message(sprintf("  - Years covered: %d to %d", min(cpi_data$year, na.rm = TRUE), max(cpi_data$year, na.rm = TRUE)))
message(sprintf("  - Observations: %d", nrow(cpi_data)))
message(sprintf("  - Saved to: %s", file.path(sources_dir, "GFD", "US_CPI_GFD_annual.dta")))
