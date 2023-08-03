#!/usr/bin/env bash
###################################################################
# Run bicep linting on passed in files.
#
# Params
#   Files. path to one or more json files separated by spaces
###################################################################


lint_path(){
    local paths=("$@")
    local lint_script="./scripts/lint_bicep.sh"

    if [ -f "$lint_script" ]; then
        # shellcheck source=./scripts/lint_bicep.sh
        source "$lint_script"
       
        lint_bicep "${paths[@]}"

        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
            echo -e "\n=== Test successful for file: ${paths[*]} ==="
        else
            echo -e "\n=== Test failed for file: ${paths[*]} ==="
        fi

        return $exit_code
    
    else
        echo "ERROR: File $lint_script does not exist."
        exit 1
    fi
}



lint_path "$@"
