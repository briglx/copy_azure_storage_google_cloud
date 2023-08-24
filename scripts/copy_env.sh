#!/usr/bin/env bash
######################################################
# Copy .env variables to function app env file:
# local.settings.json.
######################################################

# Stop on errors
set -e

validate_parameters(){

    # Check if the JSON file exists
    if [ ! -f "$LOCAL_SETTINGS_JSON" ]; then
        echo "JSON file '$LOCAL_SETTINGS_JSON' not found."
        exit 1
    fi

    # Check if the .env file exists
    if [ ! -f "$ENV_FILE" ]; then
        echo ".env file '$ENV_FILE' not found."
        exit 1
    fi

    # Check if the JSON file is valid
    if ! jq '.' "$LOCAL_SETTINGS_JSON" &> /dev/null; then
        echo "Invalid JSON file: $LOCAL_SETTINGS_JSON"
        exit 1
    fi

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo "jq is not installed. Please install jq to use this script."
        exit 1
    fi

}

update_values(){

    # Associative array to store key-value pairs from .env
    declare -A env_vars

    # Create a backup
    backup_file="$LOCAL_SETTINGS_JSON.backup.${ISO_DATE_UTC}.json"
    cp "$LOCAL_SETTINGS_JSON" "$backup_file"

    # Read JSON file into memory
    json_data=$(<"$LOCAL_SETTINGS_JSON")

    while IFS='=' read -r key value; do
        if [[ -n "$key" && -n "$value" && ! "$key" =~ ^# ]]; then

            # Replace placeholders in value with actual values from env_vars
            for var_key in "${!env_vars[@]}"; do
                value="${value//\$\{$var_key\}/${env_vars[$var_key]}}"
            done

            # Remove surrounding quotes from value
            value="${value%\"}"
            value="${value#\"}"

            # Store the key-value pair in env_vars
            env_vars["$key"]="$value"

            echo "Adding $key = $value"
            
            json_data=$(jq --arg key "$key" --arg value "$value" '.Values[$key] = $value' <<< "$json_data")
    
        fi
    done < "$ENV_FILE"

    echo "$json_data" > "$LOCAL_SETTINGS_JSON"

}

## Globals
PROJ_ROOT_PATH=$(cd "$(dirname "$0")"/..; pwd)
ENV_FILE="${PROJ_ROOT_PATH}/.env"
LOCAL_SETTINGS_JSON="${PROJ_ROOT_PATH}/functions/local.settings.json"
ISO_DATE_UTC=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

validate_parameters

update_values
