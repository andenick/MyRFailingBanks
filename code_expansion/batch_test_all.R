# Batch Test All Visualization Scripts for v11.0 Verification
# Purpose: Systematically test every script and document results

library(here)

# Get list of all R scripts except this one and helper scripts
all_scripts <- list.files(here::here("code_expansion"), pattern = "^[0-9]{2}_.*\\.R$", full.names = FALSE)
all_scripts <- all_scripts[!grepl("00_", all_scripts)] # Exclude helper scripts

# Initialize results dataframe
results <- data.frame(
  script_number = integer(),
  script_name = character(),
  status = character(),
  runtime_sec = numeric(),
  png_output = character(),
  error_message = character(),
  stringsAsFactors = FALSE
)

cat("================================================================================\n")
cat("BATCH TESTING ALL VISUALIZATION SCRIPTS\n")
cat("================================================================================\n\n")
cat("Total scripts to test:", length(all_scripts), "\n\n")

# Test each script
for (i in seq_along(all_scripts)) {
  script_file <- all_scripts[i]
  script_num <- as.integer(sub("_.*", "", script_file))
  script_name <- sub("^[0-9]{2}_", "", sub("\\.R$", "", script_file))

  cat(sprintf("[%2d/%2d] Testing %s...", i, length(all_scripts), script_file))

  start_time <- Sys.time()
  status <- "UNKNOWN"
  error_msg <- ""
  png_created <- ""

  # Try to run the script
  result <- tryCatch({
    # Suppress output
    capture.output({
      source(here::here("code_expansion", script_file))
    })
    status <- "PASS"
    ""
  }, error = function(e) {
    status <<- "FAIL"
    conditionMessage(e)
  })

  runtime <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  # Check for PNG output
  png_pattern <- sprintf("^%02d_.*\\.png$", script_num)
  png_files <- list.files(here::here("code_expansion", "presentation_outputs"),
                          pattern = png_pattern, full.names = FALSE)

  if (length(png_files) > 0) {
    png_created <- paste(png_files, collapse = ", ")
  } else {
    if (status == "PASS") {
      status <- "PASS_NO_PNG"
    }
  }

  # Store results
  results <- rbind(results, data.frame(
    script_number = script_num,
    script_name = script_name,
    status = status,
    runtime_sec = round(runtime, 1),
    png_output = png_created,
    error_message = if (status == "FAIL") result else "",
    stringsAsFactors = FALSE
  ))

  # Print result
  if (status == "PASS") {
    cat(sprintf(" ✓ PASS (%.1fs, %d PNG%s)\n", runtime, length(png_files),
                if(length(png_files) != 1) "s" else ""))
  } else if (status == "PASS_NO_PNG") {
    cat(sprintf(" ⚠ PASS but no PNG (%.1fs)\n", runtime))
  } else {
    cat(sprintf(" ✗ FAIL (%.1fs): %s\n", runtime, substr(result, 1, 60)))
  }
}

cat("\n================================================================================\n")
cat("TESTING COMPLETE\n")
cat("================================================================================\n\n")

# Summary statistics
cat("SUMMARY:\n")
cat(sprintf("  Total scripts tested: %d\n", nrow(results)))
cat(sprintf("  ✓ Passed: %d\n", sum(results$status == "PASS")))
cat(sprintf("  ⚠ Passed (no PNG): %d\n", sum(results$status == "PASS_NO_PNG")))
cat(sprintf("  ✗ Failed: %d\n", sum(results$status == "FAIL")))
cat(sprintf("  Total PNG outputs: %d\n",
            sum(sapply(results$png_output, function(x) length(strsplit(x, ", ")[[1]])))))

cat("\n")

# Save results
saveRDS(results, here::here("code_expansion", "batch_test_results.rds"))
write.csv(results, here::here("code_expansion", "batch_test_results.csv"), row.names = FALSE)

cat("✓ Results saved to:\n")
cat("  - batch_test_results.rds\n")
cat("  - batch_test_results.csv\n\n")

# Print failures if any
if (sum(results$status == "FAIL") > 0) {
  cat("FAILED SCRIPTS:\n")
  failed <- results[results$status == "FAIL", ]
  for (i in 1:nrow(failed)) {
    cat(sprintf("  %02d: %s\n", failed$script_number[i], failed$script_name[i]))
    cat(sprintf("      Error: %s\n", substr(failed$error_message[i], 1, 100)))
  }
}

cat("\n✓ Batch testing complete!\n")
