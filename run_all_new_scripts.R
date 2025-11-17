# Run all 15 new visualization scripts

scripts <- sprintf("%02d", 7:21)
success <- character()
failed <- character()

for (script_num in scripts) {
  script_files <- list.files("code_expansion", pattern = paste0("^", script_num, "_.*\.R$"), full.names = TRUE)
  if (length(script_files) > 0) {
    script_path <- script_files[1]
    cat("\n========================================\n")
    cat("Running:", basename(script_path), "\n")
    cat("========================================\n")
    
    result <- tryCatch({
      source(script_path)
      success <- c(success, basename(script_path))
      cat("✓ SUCCESS\n")
      TRUE
    }, error = function(e) {
      failed <- c(failed, basename(script_path))
      cat("✗ FAILED:", conditionMessage(e), "\n")
      FALSE
    })
  }
}

cat("\n\n=== SUMMARY ===\n")
cat("Successful:", length(success), "/", length(scripts), "\n")
cat(success, sep = "\n")
if (length(failed) > 0) {
  cat("\nFailed:", length(failed), "\n")
  cat(failed, sep = "\n")
}
