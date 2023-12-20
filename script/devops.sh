#!/usr/bin/env bash
#########################################################################
# Onboard and manage application on cloud infrastructure.
# Usage: devops.sh [COMMAND{provision | deploy}]
# Globals:
#   ENV_NAME
#   AZURE_LOCATION
#   AZURE_SUBSCRIPTION_ID
#   FUNCTION_APP_NAME (created when provisioned)
#
# Commands
#   provision   Provision resources for the application.
#   deploy      Prepare the app and deploy to cloud.
#   delete      Delete the app from cloud.
# Params
#    -n, --name             Application name.
#    -h, --help             Show this message and get help for a command.
#########################################################################

# Stop on errors
set -e

show_help() {
    echo "$0 : Onboard and manage application on cloud infrastructure." >&2
    echo "Usage: devops.sh [COMMAND{provision | deploy}]"
    echo "Globals"
    echo "   ENV_NAME"
    echo "   AZURE_LOCATION"
    echo "   AZURE_SUBSCRIPTION_ID"
    echo
    echo "Commands"
    echo "  provision   Provision resources for the application."
    echo "  delete      Delete the app from cloud."
    echo "  deploy      Prepare the app and deploy to cloud."
    echo
    echo "Arguments"
    echo "   -n, --name             Application name."
    echo "   -h, --help             Show this message and get help for a command."
    echo
}

validate_parameters(){
    # Check command
    if [ -z "$1" ]
    then
        echo "COMMAND is required (provision | deploy)" >&2
        show_help
        exit 1
    fi

    # Check ENV_NAME
    if [ -z "$ENV_NAME" ]
    then
        echo "ENV_NAME is required" >&2
        show_help
        exit 1
    fi

    # Check AZURE_LOCATION
    if [ -z "$AZURE_LOCATION" ]
    then
        echo "AZURE_LOCATION is required" >&2
        show_help
        exit 1
    fi

    # Check AZURE_SUBSCRIPTION_ID
    if [ -z "$AZURE_SUBSCRIPTION_ID" ]
    then
        echo "AZURE_SUBSCRIPTION_ID is required" >&2
        show_help
        exit 1
    fi

    # Check app name
    if [ -z "$app_name" ]
    then
        echo "name is required" >&2
        show_help
        exit 1
    fi

    # Check location
    if [ -z "$location" ]
    then
        location="$AZURE_LOCATION"
    fi

}

provision(){

    local env_file="${PROJ_ROOT_PATH}/.env"
    local deployment_name="${app_name}.Provisioning-${run_date}"

    additional_parameters=("applicationName=$app_name")
    if [ -n "$ENV_NAME" ]
    then
        additional_parameters+=("environmentName=$ENV_NAME")
    fi

    if [ -n "$AZURE_LOCATION" ]
    then
        additional_parameters+=("location=$AZURE_LOCATION")
    fi

    echo "Deploying ${deployment_name} in $location with ${additional_parameters[*]}"

    az deployment sub create \
        --subscription "$AZURE_SUBSCRIPTION_ID" \
        --name "${deployment_name}" \
        --location "$location" \
        --template-file "${PROJ_ROOT_PATH}/infra/main.bicep" \
        --parameters "${PROJ_ROOT_PATH}/infra/main.parameters.json" \
        --parameters "${additional_parameters[@]}"

    # Get the output variables from the deployment
    output_variables=$(az deployment sub show -n "${deployment_name}" --query 'properties.outputs' --output json)
    echo "Save deployment $deployment_name output variables to ${env_file}"
    {
        echo ""
        echo "# Deployment output variables"
        echo "# Generated on ${ISO_DATE_UTC}"
        echo "$output_variables" | jq -r 'to_entries[] | "\(.key | ascii_upcase )=\(.value.value)"'
    }>> "$env_file"


    # Create Google Cloud Resources


}

delete(){
    echo "$0 : delete $app_name from $environment" >&2

    # Get resource group
    echo "Looking up resource group"
    rg_lookup="rg-${app_name}_${ENV_NAME}_${AZURE_LOCATION}"
    query_param="[?name=='$rg_lookup'].name"
    resource_group=$(az group list --query "$query_param" -o tsv)

    if [ -z "$resource_group" ]
    then
        echo "Resource group ${resource_group} not found" >&2
        exit 1
    fi

    echo "Deleting resource group"
    az group delete --name "$resource_group" --yes

    echo "Done"
}

deploy(){
    local source_folder="${PROJ_ROOT_PATH}/functions"
    local destination_dir="${PROJ_ROOT_PATH}/dist"
    local timestamp
    timestamp=$(date +'%Y%m%d%H%M%S')
    local zip_file_name="${app_name}_${environment}_${timestamp}.zip"
    local zip_file_path="${destination_dir}/${zip_file_name}"

    echo "$0 : deploy $app_name to $environment" >&2

    # Ensure the source folder exists
    if [ ! -d "$source_folder" ]; then
        echo "Error: Source folder '$source_folder' does not exist."
        return 1
    fi

    # Create the destination directory if it doesn't exist
    mkdir -p "$(dirname "$zip_file_path")"

    # Copy .env to local
    "${PROJ_ROOT_PATH}"/scripts/copy_env.sh

    # Create an array for exclusion patterns
    exclude_patterns=()
    while IFS= read -r pattern; do
        # Skip lines starting with '#' (comments)
        if [[ "$pattern" =~ ^[^#] ]]; then
            exclude_patterns+=("-x./$pattern")
        fi
    done < "${PROJ_ROOT_PATH}/.gitignore"
    exclude_patterns+=("-x./local.settings.*")
    exclude_patterns+=("-x./requirements_dev.txt")

    # Zip the folder to the specified location
    cd "$source_folder"
    zip -r "$zip_file_path" ./* "${exclude_patterns[@]}"

    func azure functionapp publish "$FUNCTION_APP_NAME"

    # az functionapp deployment source config-zip \
    #     --name "${functionapp_name}" \
    #     --resource-group "${resource_group}" \
    #     --src "${zip_file_path}"

    # Update environment variables to function app
    update_environment_variables

    echo "Cleaning up"
    rm "${zip_file_path}"

    echo "Done"
}

update_environment_variables(){
    local env_file="${PROJ_ROOT_PATH}/.env"
    local input_file="${PROJ_ROOT_PATH}/functions/local.settings.json"
    local output_file="${PROJ_ROOT_PATH}/.fnx.app.settings.json"
    keys_to_match=("AZURE_TENANT_ID" "AZURE_APP_SERVICE_CLIENT_ID" "AZURE_APP_SERVICE_CLIENT_SECRET")

    # Update Azure Function App Environment Variables from .env file
    echo "Update Azure Function App Environment Variables from .env file"

    # json_data=$(cat "$input_file")
    json_data=$( jq -r '.Values' "$input_file")
    keys_json_array=$(printf '%s\n' "${keys_to_match[@]}" | jq -R -s 'split("\n") | map(select(. != ""))')

    filtered_data=$(echo "$json_data" | jq --argjson keys "$keys_json_array" '
        . as $data | to_entries | map(select(.key as $k | $keys | index($k))) | from_entries
    ')

    # Write the JSON array to the output file
    echo "$filtered_data" | jq '.' > "$output_file"

    az webapp config appsettings set \
        --id "$FUNCTION_APP_ID" \
        --settings "@$output_file"

    rm "$output_file"

}

create_event_subscription(){
    local deployment_name="${app_name}.CreateEventSubscription-${run_date}"

    additional_parameters=("applicationName=$app_name")
    if [ -n "$ENV_NAME" ]
    then
        additional_parameters+=("environmentName=$ENV_NAME")
    fi

    if [ -n "$AZURE_LOCATION" ]
    then
        additional_parameters+=("location=$AZURE_LOCATION")
    fi

    additional_parameters+=("createEventSubscription=true")

    # Create Event Subscription
    echo "Create Event Subscription"

    az deployment sub create \
        --name "${deployment_name}" \
        --location "$location" \
        --template-file "${PROJ_ROOT_PATH}/infra/main.bicep" \
        --parameters "${PROJ_ROOT_PATH}/infra/main.parameters.json" \
        --parameters "${additional_parameters[@]}"

}

# Argument/Options
LONGOPTS=name:,resource-group:,environment:,location:,help
OPTIONS=n:g:e:l:h

# Variables
app_name=""
location=""
environment="dev"
run_date=$(date +%Y%m%dT%H%M%S)
ISO_DATE_UTC=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

# Globals
PROJ_ROOT_PATH=$(cd "$(dirname "$0")"/..; pwd)

# Parse arguments
TEMP=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
eval set -- "$TEMP"
unset TEMP
while true; do
    case "$1" in
        -h|--help)
            show_help
            exit
            ;;
        -n|--name)
            app_name="$2"
            shift 2
            ;;
        -l|--location)
            location="$2"
            shift 2
            ;;
        -e|--environment)
            environment="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Unknown parameters."
            show_help
            exit 1
            ;;
    esac
done

validate_parameters "$@"
command=$1

case "$command" in
    provision)
        provision
        exit 0
        ;;
    delete)
        delete
        exit 0
        ;;
    deploy)
        deploy
        exit 0
        ;;
    event)
        create_event_subscription
        exit 0
        ;;
    update_env)
        update_environment_variables
        exit 0
        ;;
    *)
        echo "Unknown command."
        show_help
        exit 1
        ;;
esac
