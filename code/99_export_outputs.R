# 99_export_outputs.R

# ... (header)

source(here::here("code", "00_setup.R"))
# --- Load Data ---
# Load all major datasets that need to be exported
panel_data <- readRDS(file.path(dataclean_dir, "panel_data_final.rds"))
modern_data <- readRDS(file.path(dataclean_dir, "modern_data.rds"))
historical_data <- readRDS(file.path(dataclean_dir, "historical_data.rds"))
outflows_receivership <- readRDS(file.path(dataclean_dir, "outflows_receivership.rds"))

# --- Create Export Directory ---
export_dir <- file.path(output_dir, "Export")
dir.create(export_dir, showWarnings = FALSE)

# --- Export to Stata (.dta) ---
# Clean data for Stata compatibility before export
panel_clean <- clean_for_stata(panel_data, verbose = FALSE)
modern_clean <- clean_for_stata(modern_data, verbose = FALSE)
historical_clean <- clean_for_stata(historical_data, verbose = FALSE)
outflows_clean <- clean_for_stata(outflows_receivership, verbose = FALSE)

haven::write_dta(panel_clean, here::here(export_dir, "panel_data_final.dta"))
haven::write_dta(modern_clean, here::here(export_dir, "modern_data.dta"))
haven::write_dta(historical_clean, here::here(export_dir, "historical_data.dta"))
haven::write_dta(outflows_clean, here::here(export_dir, "outflows_receivership.dta"))

# --- Export to CSV (.csv) ---
write_csv(panel_data, here::here(export_dir, "panel_data_final.csv"))
write_csv(modern_data, here::here(export_dir, "modern_data.csv"))
write_csv(historical_data, here::here(export_dir, "historical_data.csv"))
write_csv(outflows_receivership, here::here(export_dir, "outflows_receivership.csv"))

# --- Export to Excel (.xlsx) ---
openxlsx::write.xlsx(
    list(
        "panel_data" = panel_data,
        "modern_data" = modern_data,
        "historical_data" = historical_data,
        "outflows_receivership" = outflows_receivership
    ),
    file = here::here(export_dir, "failing_banks_datasets.xlsx")
)

cat("✓ All major datasets exported to Output/Export/\n")
