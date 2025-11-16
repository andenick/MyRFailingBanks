# ===========================================================================
# Helper Functions for Failing Banks R Replication
# ===========================================================================

# Print functions for script output
print_header <- function(text) {
    cat(sprintf("\n%s\n", text))
}

print_complete <- function(script_name) {
    cat(sprintf("\n%s completed successfully\n", script_name))
}
