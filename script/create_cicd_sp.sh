#!/usr/bin/env bash
######################################################
# Create a cloud CICD system identity to authenticate
# using OpenId Connect (OIDC) federated credentials.
# Sets AZURE_CICD_CLIENT_ID, GOOGLE_CICD_SERVICE_ACCOUNT,
# and GOOGLE_CICD_CLIENT_KEY_FILE in .env
# Globals:
#   CICD_CLIENT
#   AZURE_TENANT_ID
#   AZURE_SUBSCRIPTION_ID
#   GOOGLE_IAM_PROJECT_ID
#   GOOGLE_PROJECT_ID
#   GITHUB_ORG
#   GITHUB_REPO
# Params
#    -c, --cloud            Cloud name [azure|google].
#    -h, --help             Show this message and get help for a command.
######################################################

# Stop on errors
set -e

show_help() {
    echo "$0 : Create a cloud CICD system identity to authenticate using OpenId Connect (OIDC) federated credentials." >&2
    echo "Usage: create_cicd_sp.sh [OPTIONS]" >&2
    echo "Sets AZURE_CICD_CLIENT_ID, GOOGLE_CICD_SERVICE_ACCOUNT, and GOOGLE_CICD_CLIENT_KEY_FILE in .env" >&2
    echo "Globals"
    echo "   CICD_CLIENT"
    echo "   AZURE_TENANT_ID"
    echo "   AZURE_SUBSCRIPTION_ID"
    echo "   GOOGLE_IAM_PROJECT_ID"
    echo "   GOOGLE_PROJECT_ID"
    echo "   GITHUB_ORG"
    echo "   GITHUB_REPO"
    echo
    echo "Arguments"
    echo "   -c, --cloud            Cloud name [azure|google]."
    echo "   -h, --help             Show this message and get help for a command."
    echo
}

update_gitignore(){
    local entry="$1"
    local gitignore_file=".gitignore"
    local comment="# Entry from create_cicd_sp.sh. Generated on ${iso_date_utc}"

    if [ -e "$gitignore_file" ]; then
        if grep -q "^$entry" "$gitignore_file"; then
            echo "$entry already exists in $gitignore_file"
        else
            echo "$entry doesn't exist in $gitignore_file. Adding entry..."
            echo -e "$comment\n$entry" >> "$gitignore_file"
            echo "Entry added successfully."
        fi
    else
        echo "Error: $gitignore_file not found."
    fi
}

validate_parameters(){

    # Check CICD_CLIENT
    if [ -z "$CICD_CLIENT" ]
    then
        echo "CICD_CLIENT is required" >&2
        show_help
        exit 1
    fi

    # Check GITHUB_ORG
    if [ -z "$GITHUB_ORG" ]
    then
        echo "GITHUB_ORG is required" >&2
        show_help
        exit 1
    fi

    # Check GITHUB_REPO
    if [ -z "$GITHUB_REPO" ]
    then
        echo "GITHUB_REPO is required" >&2
        show_help
        exit 1
    fi

    # Check cloud_name
    if [ -z "$cloud_name" ]
    then
        echo "cloud name is required" >&2
        show_help
        exit 1
    fi

}

validate_azure_parameters(){

    # Check TENANT_ID
    if [ -z "$TENANT_ID" ]
    then
        echo "TENANT_ID is required" >&2
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

validate_google_parameters(){
    # Check GOOGLE_IAM_PROJECT_ID
    if [ -z "$GOOGLE_IAM_PROJECT_ID" ]
    then
        echo "GOOGLE_IAM_PROJECT_ID is required" >&2
        show_help
        exit 1
    fi

    # Check GOOGLE_PROJECT_ID
    if [ -z "$GOOGLE_PROJECT_ID" ]
    then
        echo "GOOGLE_PROJECT_ID is required" >&2
        show_help
        exit 1
    fi
}

create_azure_sp(){

    # Constants
    ms_graph_api_id="00000003-0000-0000-c000-000000000000"
    ms_graph_user_invite_all_permission="09850681-111b-4a89-9bed-3f2cae46d706"
    ms_graph_user_read_write_all_permission="741f803b-c850-494e-b5df-cde7c675a1ca"
    ms_graph_directory_read_write_all_permission="19dbc75e-c2e2-444c-a770-ec69d8559fc7"

    # App Names
    app_name="${CICD_CLIENT}_service_app"
    app_secret_name="${CICD_CLIENT}_client_secret"

    az login --tenant "$TENANT_ID"

    # Create an Azure Active Directory application and a service principal.
    app_id=$(az ad app create --display-name "$app_name" --query id -o tsv)
    app_client_id=$(az ad app list --display-name "$app_name" --query [].appId -o tsv)

    # Create a service principal for the Azure Active Directory application.
    az ad sp create --id "$app_id"

    # Assign contributor role to the app service principal
    app_sp_id=$(az ad sp list --all --display-name "$app_name" --query "[].id" -o tsv)
    az role assignment create --assignee "$app_sp_id" --role contributor --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID"
    az role assignment create --role contributor --subscription "$AZURE_SUBSCRIPTION_ID" --assignee-object-id  "$app_sp_id" --assignee-principal-type ServicePrincipal --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID"

    # Configure Microsoft Graph api permissions
    az ad app permission add --id "$app_client_id" --api "$ms_graph_api_id" --api-permissions "$ms_graph_user_invite_all_permission=Role $ms_graph_user_read_write_all_permission=Role $ms_graph_directory_read_write_all_permission=Role"
    az ad app permission admin-consent --id "$app_client_id"

    # Add OIDC federated credentials for the application.
    post_body="{\"name\":\"$app_secret_name\","
    post_body=$post_body'"issuer":"https://token.actions.githubusercontent.com",'
    post_body=$post_body"\"subject\":\"repo:$GITHUB_ORG/$GITHUB_REPO:pull_request\","
    post_body=$post_body'"description":"GitHub CICD Service","audiences":["api://AzureADTokenExchange"]}'
    az rest --method POST --uri "https://graph.microsoft.com/beta/applications/$app_id/federatedIdentityCredentials" --body "$post_body"

    # Save variables to .env
    echo "Save Azure variables to ${ENV_FILE}"
    {
        echo ""
        echo "# Script create_cicd_sp.sh output variables create_azure_sp"
        echo "# Generated on ${iso_date_utc}"
        echo "AZURE_CICD_CLIENT_ID=$app_client_id"
    }>> "$ENV_FILE"

}

create_google_sp(){

    local project_id="${GOOGLE_IAM_PROJECT_ID}"
    local target_project_id="${GOOGLE_PROJECT_ID}"
    local service_account_name="${CICD_CLIENT}"
    local creds_file="creds-${service_account_name}.json"
    local pool_name=cicd-identity-pool
    local pool_provider_name=github-cicd-service
    local provider_display_name="GitHub CICD Service"
    local repo="${GITHUB_ORG}/${GITHUB_REPO}"

    # Login to Google Cloud
    gcloud config set project "$project_id"

    # Create Google Cloud Service Account
    gcloud iam service-accounts create "${service_account_name}" --project "${project_id}"
    service_account_email=$(gcloud iam service-accounts list --filter=name:"${service_account_name}" --format "value(email)")

    # Download the service account key
    gcloud iam service-accounts keys create "${creds_file}" --iam-account "${service_account_email}" --project "${project_id}"
    update_gitignore "${creds_file}"

    # Grant Service Account access to Cloud Resources ...
    gcloud projects add-iam-policy-binding "${target_project_id}" --member=serviceAccount:"${service_account_email}" --role=roles/storage.admin
    gcloud projects add-iam-policy-binding "${target_project_id}" --member=serviceAccount:"${service_account_email}" --role=roles/serviceusage.serviceUsageAdmin
    gcloud projects add-iam-policy-binding "${target_project_id}" --member=serviceAccount:"${service_account_email}" --role=roles/iam.serviceAccountCreator

    # Check if the Workload Identity Pool already exists
    pool_id=$(gcloud iam workload-identity-pools describe "${pool_name}" --project "${project_id}" --location "global" --format "value(name)")
    if [[ -n "$pool_id" ]]
    then
        echo "Workload Identity Pool ${pool_name} already exists"
    else
        # Create a Workload Identity Pool
        gcloud iam workload-identity-pools create "${pool_name}" --project "${project_id}" --location "global" --description "CICD Identity Pool"

        # Get the full ID of the Workload Identity Pool
        pool_id=$(gcloud iam workload-identity-pools describe "${pool_name}" --project "${project_id}" --location "global" --format "value(name)")
    fi

    # Grant users access to this service account
    gcloud projects add-iam-policy-binding "${target_project_id}" --member=serviceAccount:"principalSet://iam.googleapis.com/projects/${project_id}/locations/global/workloadIdentityPools/${pool_name}/*" --role=roles/iam.serviceAccountUser

    # Check if the Workload Identity Pool Provider already exists
    provider_id=$(gcloud iam workload-identity-pools providers describe "${pool_provider_name}" --project "${project_id}" --location "global" --workload-identity-pool "${pool_name}" --format "value(name)")
    if [[ -n "$provider_id" ]]
    then
        echo "Workload Identity Pool Provider ${pool_provider_name} already exists"
    else
        echo "Create Workload Identity Pool Provider ${pool_provider_name}"
        gcloud iam workload-identity-pools providers create-oidc \
            "${pool_provider_name}" \
            --project="${project_id}" --location="global" \
            --workload-identity-pool="${pool_name}" \
            --display-name="${provider_display_name}" \
            --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
            --issuer-uri="https://token.actions.githubusercontent.com"
            # --attribute-condition="assertion.repository_owner=='$GITHUB_ORG'" \

        # Grant Workload Identity Provider authentications from the GitHub repository to impersonate the service account.
        gcloud iam service-accounts add-iam-policy-binding "${service_account_email}" \
            --project="${project_id}" \
            --role="roles/iam.workloadIdentityUser" \
            --member="principalSet://iam.googleapis.com/${pool_id}/attribute.repository/${repo}"

        # Get the full ID of the Workload Identity Pool Provider
        provider_id=$(gcloud iam workload-identity-pools providers describe "${pool_provider_name}" \
            --project "${project_id}" \
            --location "global" \
            --workload-identity-pool "${pool_name}" \
            --format "value(name)")
    fi

    # Save variables to .env
    echo "Save variables to ${ENV_FILE}"
    {
        echo ""
        echo "# Script create_cicd_sp.sh output variables"
        echo "# Generated on ${iso_date_utc}"
        echo "GOOGLE_CICD_SERVICE_ACCOUNT=$service_account_email"
        echo "WORKLOAD_IDENTITY_PROVIDER=$provider_id"
        echo "GOOGLE_CICD_CLIENT_KEY_FILE=$creds_file"
    }>> "$ENV_FILE"

}

# Argument/Options
LONGOPTS=cloud:,help
OPTIONS=c:h

# Variables
cloud_name=""

## Globals
PROJ_ROOT_PATH=$(cd "$(dirname "$0")"/..; pwd)
ENV_FILE="${PROJ_ROOT_PATH}/.env"
iso_date_utc=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

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
        -c|--cloud)
            cloud_name="$2"
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

case "$cloud_name" in
    azure)
        validate_azure_parameters
        create_azure_sp
        exit 0
        ;;
    google)
        validate_google_parameters
        create_google_sp
        exit 0
        ;;
    *)
        echo "Unknown command."
        show_help
        exit 1
        ;;
esac
