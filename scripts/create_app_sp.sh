#!/usr/bin/env bash
######################################################
# Create a cloud App system identity to represent
# application in cloud.
# Globals:
#   CICD_CLIENT
#   AZURE_TENANT_ID
#   AZURE_SUBSCRIPTION_ID
# Params
#    -c, --cloud            Cloud name [azure|google].
#    -n, --name             Application name.
#    -e, --env              Environment name.
#    -h, --help             Show this message and get help for a command.
######################################################

# Stop on errors
set -e

show_help() {
    echo "$0 : Create a cloud App system identity to represent application in cloud." >&2
    echo "Usage: create_app_sp.sh [OPTIONS]"
    echo "Globals"
    echo "   CICD_CLIENT"
    echo "   AZURE_TENANT_ID"
    echo "   AZURE_SUBSCRIPTION_ID"
    echo
    echo "Arguments"
    echo "   -c, --cloud            Cloud name [azure|google]."
    echo "   -n, --name             Application name."
    echo "   -e, --env              Environment name."
    echo "   -h, --help             Show this message and get help for a command."
    echo
}

validate_parameters(){
    # Check cloud
    if [ -z "$cloud_name" ]
    then
        echo "cloud is required" >&2
        show_help
        exit 1
    fi

    # Check app_name
    if [ -z "$app_name" ]
    then
        echo "name is required" >&2
        show_help
        exit 1
    fi

    # Check env
    if [ -z "$env_name" ]
    then
        echo "environment is required" >&2
        show_help
        exit 1
    fi

    # Check AZURE_TENANT_ID
    if [ -z "$AZURE_TENANT_ID" ]
    then
        echo "AZURE_TENANT_ID is required" >&2
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
}

create_app_sp(){
    # Create a service principal for the App
    echo "Creating service principal for $env_name $app_name"
    if [ "$cloud_name" == "azure" ]; then

        # Create an Azure Active Directory application and a service principal.
        app_id=$(az ad app create --display-name "${env_name}_${app_name}" --query id -o tsv)
        app_client_id=$(az ad app list --display-name "${env_name}_${app_name}" --query [].appId -o tsv)
        
        # Create a service principal for the Azure Active Directory application.
        app_sp=$(az ad sp create --id "$app_id")
        app_sp_id=$(jq -r '.id' <<< "$app_sp")

        # Create a secret for the service principal.
        app_client_secret=$(az ad app credential reset \
            --id "$app_id" \
            --display-name "App Client Secret" \
            --query password -o tsv)

        # Save variables to .env
        if [ -f "$ENV_FILE" ]; then
            
            echo "Save Azure variables to ${ENV_FILE}"
            {
                echo ""
                echo "# Script create_app_sp.sh output"
                echo "# Generated on ${ISO_DATE_UTC}"
                echo "AZURE_APP_SERVICE_ID=$app_id"
                echo "AZURE_APP_SERVICE_CLIENT_ID=$app_client_id"
                echo "AZURE_APP_SERVICE_CLIENT_SECRET=$app_client_secret"
            }>> "$ENV_FILE"
        
        fi
        
        if [ -n "$AZ_SCRIPTS_OUTPUT_PATH" ]; then
            outputJson=$(jq -n \
                    --arg applicationObjectId "$app_id" \
                    --arg applicationClientId "$app_client_id" \
                    --arg applicationClientSecret "$app_client_secret" \
                    --arg servicePrincipalObjectId "$app_sp_id" \
                    '{applicationObjectId: $applicationObjectId, applicationClientId: $applicationClientId, applicationClientSecret: $applicationClientSecret, servicePrincipalObjectId: $servicePrincipalObjectId}' )
            echo "$outputJson" > "$AZ_SCRIPTS_OUTPUT_PATH"
        fi

        
    elif [ "$CLOUD" == "google" ]; then
        gcloud iam service-accounts create "$app_name" \
            --description="Service account for $app_name" \
            --display-name="$app_name"
        gcloud iam service-accounts keys create "$app_name.json" \
            --iam-account="$app_name@$GOOGLE_PROJECT_ID.iam.gserviceaccount.com"
    else
        echo "Cloud $CLOUD not supported" >&2
        show_help
        exit 1
    fi
}

## Globals
PROJ_ROOT_PATH=$(cd "$(dirname "$0")"/..; pwd)
ENV_FILE="${PROJ_ROOT_PATH}/.env"
ISO_DATE_UTC=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

DEFAULT_CLOUD="azure"
DEFAULT_NAME="${APPLICATION_NAME}"
DEFAULT_ENV="${ENVIRONMENT_NAME}"

# Variables
cloud_name="$DEFAULT_CLOUD"
app_name="$DEFAULT_NAME"
env_name="$DEFAULT_ENV"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -c|--cloud)
            shift
            if [[ -n "$1" ]]; then
                cloud_name="$1"
            else
                echo "Error: --cloud requires a value."
                show_help
                exit 1
            fi
            shift
            ;;
        -n|--name)
            shift
            if [[ -n "$1" ]]; then
                app_name="$1"
            else
                echo "Error: --name requires a value."
                show_help
                exit 1
            fi
            shift
            ;;
        -e|--env)
            shift
            if [[ -n "$1" ]]; then
                env_name="$1"
            else
                echo "Error: --env requires a value."
                show_help
                exit 1
            fi
            shift
            ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
done

validate_parameters

create_app_sp
