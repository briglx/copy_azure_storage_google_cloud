#!/usr/bin/env bash
#########################################################################
# Onboard and manage application on cloud infrastructure.
# Usage: devops.sh [COMMAND{provision | deploy}] 
# Globals:
#   AZURE_ENV_NAME
#   AZURE_LOCATION
#   AZURE_SUBSCRIPTION_ID
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
    echo "   AZURE_ENV_NAME"
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

    # Check AZURE_ENV_NAME
    if [ -z "$AZURE_ENV_NAME" ]
    then
        echo "AZURE_ENV_NAME is required" >&2
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
    if [ -n "$AZURE_ENV_NAME" ]
    then
        additional_parameters+=("environmentName=$AZURE_ENV_NAME")
    fi

    if [ -n "$AZURE_LOCATION" ]
    then
        additional_parameters+=("location=$AZURE_LOCATION")
    fi

    echo "Deploying ${deployment_name} in $location with ${additional_parameters[*]}"

    az deployment sub create \
        --name "${deployment_name}" \
        --location "$location" \
        --template-file "${PROJ_ROOT_PATH}/infra/main.bicep" \
        --parameters "${PROJ_ROOT_PATH}/infra/main.parameters.json" \
        --parameters "${additional_parameters[@]}"

    # Get the output variables from the deployment
    output_variables=$(az deployment sub show -n "${deployment_name}" --query 'properties.outputs' --output json)
    echo "Save deployment $deployment_name output variables to ${env_file}"
    {
        echo "# Deployment output variables"
        echo "# Generated on $(date)"
        echo ""
        echo "$output_variables" | jq -r 'to_entries[] | "\(.key | ascii_upcase )=\(.value.value)"' 
    }>> "$env_file"



}

delete(){
    echo "$0 : delete $app_name from $environment" >&2

    # Get resource group
    echo "Looking up resource group"
    rg_lookup="rg-${app_name}_${AZURE_ENV_NAME}_${AZURE_LOCATION}"
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
    local functionapp_pattern="func-${app_name}-${environment}-"
    local rg_lookup="rg-${app_name}_${AZURE_ENV_NAME}_${AZURE_LOCATION}"
    local query_param="[?name=='$rg_lookup'].name"
    local resource_group

    echo "$0 : deploy $app_name to $environment" >&2

    # Ensure the source folder exists
    if [ ! -d "$source_folder" ]; then
        echo "Error: Source folder '$source_folder' does not exist."
        return 1
    fi

    # Delete the previous zip file if it exists
    local prev_zip_files=("$destination_dir"/*.zip)
    if [ ${#prev_zip_files[@]} -gt 0 ]; then
        rm -f "${prev_zip_files[@]}" 2>/dev/null
    fi

    # Create the destination directory if it doesn't exist
    mkdir -p "$(dirname "$zip_file_path")"

    cd "$(dirname "$source_folder")"

    # Zip the folder to the specified location
    # zip -r "$zip_file_path" "$(basename "$source_folder")" -x "*/local.settings.json" -x "*/.gitignore"
    cd "$source_folder"
    zip -r "$zip_file_path" ./* -x "local.settings.json" -x "*/.gitignore"


    # Get resource group
    echo "Looking up resource group"
    resource_group=$(az group list --query "$query_param" -o tsv)
    if [ -z "$resource_group" ]
    then
        echo "Resource group ${resource_group} not found" >&2
        exit 1
    fi

    # Get function app name
    echo "Looking up function app"
    matching_resources=$(az resource list --query "[?name | starts_with(@, '$functionapp_pattern')].name" --output json)

    if [ "$(jq length <<< "$matching_resources")" -eq 0 ]; then
        echo "No matching function apps found."
        exit 1
    fi
    # Get the first matching resource
    functionapp_name=$(jq -r '.[0]' <<< "$matching_resources")
    echo "Deploying to $functionapp_name"

    az functionapp deployment source config-zip \
        --name "${functionapp_name}" \
        --resource-group "${resource_group}" \
        --src "${zip_file_path}"

    echo "Cleaning up"
    # rm "${zip_file_path}"

    echo "Done"
}

create_event_subscription(){
    local deployment_name="${app_name}.CreateEventSubscription-${run_date}"

    additional_parameters=("applicationName=$app_name")
    if [ -n "$AZURE_ENV_NAME" ]
    then
        additional_parameters+=("environmentName=$AZURE_ENV_NAME")
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
    *)
        echo "Unknown command."
        show_help
        exit 1
        ;;
esac
