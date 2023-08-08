#!/usr/bin/env bash
###################################################################
# Run bicep linting on passed in files.
#
# Params
#   Files. path to one or more json files separated by spaces
###################################################################


log_error_and_exit() {
    local file_name="$1"
    echo "Error processing file: $file_name"
    exit 1
}

process_files(){
    local search_pattern="$1"
    local file_count=0
    # local paths=("$@")
    local lint_script="./scripts/lint_bicep.sh"

    if [ -f "$lint_script" ]; then
        # shellcheck source=./scripts/lint_bicep.sh
        source "$lint_script"

        if [[ $search_pattern == *[*?]* ]]; then
            # It's a glob pattern, get the list of files that match the pattern
            while IFS= read -r -d '' file; do
                if ! lint_bicep "$file"; then
                    log_error_and_exit "$file"
                fi
                ((file_count++))

            done < <(find . -type f -name "$search_pattern" -print0)
        else
            # It's an array of files, loop through each file
            for file in "${search_pattern[@]}"; do
                if ! lint_bicep "$file"; then
                    log_error_and_exit "$file"
                fi
                ((file_count++))
            done
        fi
       
        # lint_bicep "${paths[@]}"

        # local exit_code=$?

        # if [ $exit_code -eq 0 ]; then
        #     echo -e "\n=== Test successful for file: ${paths[*]} ==="
        # else
        #     echo -e "\n=== Test failed for file: ${paths[*]} ==="
        # fi

        # return $exit_code
        echo "$0: Files checked: $file_count"
    
    else
        echo "ERROR: File $lint_script does not exist."
        exit 1
    fi
}

# Check if search_pattern is provided as a parameter
if [ -z "$1" ]; then
  echo "Usage: $0 <search_pattern or array_of_files>"
  exit 1
fi

process_files "$@"
