# ===========================================================================
# Logging Setup for Failing Banks R Replication
# ===========================================================================
# This script sets up comprehensive logging for all scripts
# All console output is captured to timestamped log files

library(here)

# Create log directory if it doesn't exist
log_dir <- here::here("..", "..", "test_logs")
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

# Generate timestamp for this run
run_timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")

# Master log file for complete run
master_log <- file.path(log_dir, paste0(run_timestamp, "_MASTER_RUN.log"))

# Function to create individual script log
create_script_log <- function(script_num, script_name = NULL) {
  if (is.null(script_name)) {
    script_name <- sprintf("script_%02d", script_num)
  }
  log_file <- file.path(log_dir, paste0(run_timestamp, "_", script_name, ".log"))
  return(log_file)
}

# Function to write header to log
log_header <- function(script_num, script_name, log_file) {
  cat(sprintf("=== Script %02d: %s ===\n", script_num, script_name), file = log_file)
  cat(sprintf("Start Time: %s\n", Sys.time()), file = log_file, append = TRUE)
  cat(sprintf("Working Directory: %s\n", getwd()), file = log_file, append = TRUE)
  cat(sprintf("R Version: %s\n", R.version.string), file = log_file, append = TRUE)
  cat(sprintf("User: %s\n", Sys.info()["user"]), file = log_file, append = TRUE)
  cat("\n--- Script Output ---\n\n", file = log_file, append = TRUE)
}

# Function to write footer to log
log_footer <- function(script_num, start_time, status, log_file, error_msg = NULL) {
  end_time <- Sys.time()
  runtime <- difftime(end_time, start_time, units = "secs")

  cat("\n\n--- Completion ---\n", file = log_file, append = TRUE)
  cat(sprintf("End Time: %s\n", end_time), file = log_file, append = TRUE)
  cat(sprintf("Runtime: %.2f seconds (%.2f minutes)\n", as.numeric(runtime), as.numeric(runtime)/60),
      file = log_file, append = TRUE)
  cat(sprintf("Status: %s\n", status), file = log_file, append = TRUE)

  if (!is.null(error_msg)) {
    cat(sprintf("Error: %s\n", error_msg), file = log_file, append = TRUE)
  }

  cat(paste0(rep("=", 70), collapse = ""), "\n\n", file = log_file, append = TRUE)
}

# Function to run a script with logging
run_with_logging <- function(script_num, script_file = NULL, script_name = NULL) {
  # Determine script file name if not provided
  if (is.null(script_file)) {
    # Look for the script
    script_pattern <- sprintf("^%02d_.*\\.R$", script_num)
    matching_files <- list.files(here::here("code"), pattern = script_pattern, full.names = TRUE)

    if (length(matching_files) == 0) {
      cat(sprintf("ERROR: No script found for number %02d\n", script_num))
      return(FALSE)
    }

    script_file <- matching_files[1]  # Use first match
  }

  # Extract script name from filename
  if (is.null(script_name)) {
    script_name <- gsub("\\.R$", "", basename(script_file))
  }

  # Create log file
  log_file <- create_script_log(script_num, script_name)

  # Write header
  log_header(script_num, script_name, log_file)

  # Record start time
  start_time <- Sys.time()

  cat(sprintf("\n=== Running Script %02d: %s ===\n", script_num, script_name))
  cat(sprintf("Log file: %s\n", log_file))

  # Capture both stdout and stderr to log file
  status <- "SUCCESS"
  error_msg <- NULL

  tryCatch({
    # Open file connection for logging
    log_conn <- file(log_file, open = "a")

    # Sink both output and messages to log file
    sink(log_conn, split = TRUE)  # split = TRUE also prints to console
    sink(log_conn, type = "message")

    # Source the script
    source(script_file, echo = TRUE, print.eval = TRUE)

    # Stop sinking and close connection
    sink(type = "message")
    sink()
    close(log_conn)

  }, error = function(e) {
    # Stop sinking on error
    try(sink(type = "message"), silent = TRUE)
    try(sink(), silent = TRUE)
    try(close(log_conn), silent = TRUE)

    status <<- "FAILED"
    error_msg <<- as.character(e$message)

    # Log the error
    cat(sprintf("\n\nERROR in Script %02d:\n%s\n", script_num, error_msg),
        file = log_file, append = TRUE)

    cat(sprintf("\n✗ Script %02d FAILED: %s\n", script_num, error_msg))
  }, finally = {
    # Ensure sinks are stopped and connection closed
    try(sink(type = "message"), silent = TRUE)
    try(sink(), silent = TRUE)
    try(if(exists("log_conn")) close(log_conn), silent = TRUE)

    # Write footer
    log_footer(script_num, start_time, status, log_file, error_msg)

    if (status == "SUCCESS") {
      cat(sprintf("✓ Script %02d completed successfully\n", script_num))
    }
  })

  return(status == "SUCCESS")
}

# Function to validate dataset dimensions
log_dataset_info <- function(dataset_name, data, log_file) {
  cat(sprintf("\n--- Dataset Info: %s ---\n", dataset_name), file = log_file, append = TRUE)
  cat(sprintf("Dimensions: %d rows × %d columns\n", nrow(data), ncol(data)),
      file = log_file, append = TRUE)
  cat(sprintf("Memory size: %.2f MB\n", as.numeric(object.size(data)) / 1024^2),
      file = log_file, append = TRUE)

  # Log column names (first 20)
  cols_to_show <- min(20, ncol(data))
  cat(sprintf("Columns (%d total): %s%s\n",
              ncol(data),
              paste(names(data)[1:cols_to_show], collapse = ", "),
              if (ncol(data) > 20) "..." else ""),
      file = log_file, append = TRUE)
}

# Function to check file creation
log_file_created <- function(file_path, log_file) {
  if (file.exists(file_path)) {
    file_info <- file.info(file_path)
    cat(sprintf("✓ Created: %s (%.2f MB)\n", basename(file_path), file_info$size / 1024^2),
        file = log_file, append = TRUE)
    cat(sprintf("✓ Created: %s\n", basename(file_path)))
    return(TRUE)
  } else {
    cat(sprintf("✗ MISSING: %s\n", basename(file_path)),
        file = log_file, append = TRUE)
    cat(sprintf("✗ MISSING: %s\n", basename(file_path)))
    return(FALSE)
  }
}

# Print startup message
cat("\n")
cat("==================================================================\n")
cat("  FAILING BANKS R REPLICATION - LOGGING ENABLED\n")
cat("==================================================================\n")
cat(sprintf("Run Timestamp: %s\n", run_timestamp))
cat(sprintf("Master Log: %s\n", master_log))
cat(sprintf("Script Logs: %s/\n", log_dir))
cat("==================================================================\n\n")

# Write to master log
cat(sprintf("Failing Banks R Replication - Master Log\n"), file = master_log)
cat(sprintf("Run started: %s\n", Sys.time()), file = master_log, append = TRUE)
cat(sprintf("R Version: %s\n", R.version.string), file = master_log, append = TRUE)
cat(sprintf("Working Directory: %s\n", getwd()), file = master_log, append = TRUE)
cat("\n", file = master_log, append = TRUE)

message("Logging system initialized successfully")
