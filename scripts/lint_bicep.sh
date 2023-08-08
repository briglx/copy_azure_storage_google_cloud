#!/usr/bin/env bash
###################################################################
# Run bicep linting on passed in files or glob patterns.
# Usage: bicep_glob.sh [OPTIONS] SRC 
#
# Params
#   files     One or more bicep files.
###################################################################

# Stop on errors
# set -e

# Enable globstar to support the pattern **/*.bicep for recursive searching
shopt -s globstar

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color


lint_file() {
  local file="$1"
  local output
  
  # Check the exit status of the command directly
  if output=$(az bicep build --file "$file" --stdout 2>&1); then
    # Print in green color for success
    echo -e "${GREEN}Pass: $file${NC}"
    return 0
  else
    # Print in red color for failure
    echo -e "${RED}Failed: $file${NC}"
    error=$(echo "$output" | grep -E "ERROR:|error")
    echo -e "${RED}$error${NC}"
    return 1
  fi
}

process_file_or_directory() {
  local path="$1"
  local failed=0

  if [ -f "$path" ]; then
    # Process the single file
    lint_file "$path" || failed=1

  elif [ -d "$path" ]; then
    # Find all matching .bicep files and test the output
    local bicep_files=( "$path"/**/*.bicep )
    for file in "${bicep_files[@]}"; do
      lint_file "$file" || failed=1
    done

  else
    echo "Error: '$path' is not a valid file or directory."
    failed=1
  fi

  if [ "$failed" -eq 1 ]; then
    echo "Error: failed."
    exit 1
  fi
}

lint_bicep() {
  local paths=("$@")
  local failed=0

  for path in "${paths[@]}"; do
    if [ "$path" = "/" ]; then
      echo -e "${RED}Error: The root directory / is not allowed as the search path.${NC}"
      exit 1
    fi
  done

  for path in "$@"; do

    # Check if the path is a directory or a file
    if [ -d "$path" ]; then
      process_file_or_directory "$path"
    elif [ -f "$path" ]; then
      process_file_or_directory "$path"
    else
      echo -e "${RED}Error: '$path' is not a valid file or directory.${NC}"
      exit 1
    fi
  done

}
