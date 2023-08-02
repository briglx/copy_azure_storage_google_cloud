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

    additional_parameters=("applicationName=$app_name")
    if [ -n "$AZURE_ENV_NAME" ]
    then
        additional_parameters+=("environmentName=$AZURE_ENV_NAME")
    fi

    if [ -n "$AZURE_LOCATION" ]
    then
        additional_parameters+=("location=$AZURE_LOCATION")
    fi

    echo "Deploying ${app_name} at $run_date in $location with ${additional_parameters[*]}"
    
    az deployment sub create \
        --name "${app_name}.Deployment-${run_date}" \
        --location "$location" \
        --template-file "${PROJ_ROOT_PATH}/infra/main.bicep" \
        --parameters "${PROJ_ROOT_PATH}/infra/main.parameters.json" \
        --parameters "${additional_parameters[@]}"
}

deploy(){
    echo "$0 : deploy to $environment" >&2
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
        ;;
    deploy)
        deploy
        ;;
    *)
        echo "Unknown command."
        show_help
        exit 1
        ;;
esac
