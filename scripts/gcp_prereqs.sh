#!/usr/bin/env bash
#########################################################################
# Configure prerequisites for Google Cloud
#########################################################################

# Stop on errors
set -e

create_projects(){

    # Create IAM Cloud Project.
    gcloud projects create "${GOOGLE_IAM_PROJECT_ID}" --name="${GOOGLE_IAM_PROJECT_NAME}" --quiet
    # Enable Cloud Resource Manager API
    gcloud services enable cloudresourcemanager.googleapis.com --project "${GOOGLE_IAM_PROJECT_ID}"

    # Create Application Project
    gcloud projects create "${GOOGLE_PROJECT_ID}" --name="${GOOGLE_PROJECT_NAME}" --set-as-default --quiet
    gcloud services enable cloudresourcemanager.googleapis.com --project "${GOOGLE_PROJECT_ID}"
    gcloud services enable cloudbilling.googleapis.com --project "${GOOGLE_PROJECT_ID}"
    gcloud services enable iamcredentials.googleapis.com --project "${GOOGLE_PROJECT_ID}"
    
    # Enable Billing
    gcloud beta billing projects link "${GOOGLE_PROJECT_ID}" --billing-account="${GOOGLE_BILLING_ACCOUNT_ID}"

    # Assert billing is enabled
    if [[ $(gcloud beta billing projects describe "${GOOGLE_PROJECT_ID}" --format="value(billingEnabled)") == "False" ]]; then
        echo "ERROR: Billing is not enabled for project ${GOOGLE_PROJECT_ID}"
        exit 1
    fi
}

configure_workload_identity_federation(){

    local pool_name="${AZURE_TENANT_NAME}-identity-pool"
    local pool_description="Azure Tenant ${AZURE_TENANT_NAME} Identity Pool"
    local project_id="${GOOGLE_PROJECT_ID}"

    # Check if the Workload Identity Pool already exists
    pool_id=$(gcloud iam workload-identity-pools describe "${pool_name}" --project "${project_id}" --location "global" --format "value(name)")
    if [[ -n "$pool_id" ]]
    then
        echo "Workload Identity Pool ${pool_name} already exists"
    else 
        # Create a Workload Identity Pool
        gcloud iam workload-identity-pools create "${pool_name}" \
            --location "global" \
            --description "${pool_description}" \
            --display-name "${pool_name}" \
            --project "${project_id}"

        # Get the full ID of the Workload Identity Pool
        pool_id=$(gcloud iam workload-identity-pools describe "${pool_name}" --project "${project_id}" --location "global" --format "value(name)")
    fi

    # Check if the Azure identity provider already exists
    provider_id=$(gcloud iam workload-identity-pools providers describe-azure --project "${project_id}" --location "global" --workload-identity-pool "${pool_name}" --format "value(name)")
    if [[ -n "$provider_id" ]]
    then
        echo "Azure identity provider already exists"
    else 
        # Create an Azure identity provider
        gcloud iam workload-identity-pools providers create-oidc \
            --location "global" \
            --workload-identity-pool "${pool_id}" \
            --issuer-uri "https://login.microsoftonline.com/${AZURE_TENANT_NAME}/v2.0" \
            --allowed-audiences="${APPLICATION_ID_URI}" \
            --attribute-mapping="google.subject=assertion.sub,google.groups=assertion.groups" \
            --display-name "${AZURE_TENANT_NAME} Azure Identity Provider" \
            --description "${AZURE_TENANT_NAME} Azure Identity Provider" \
            --project "${project_id}"
    fi

    # Save variables to .env file
    echo "Save variables to .env file"
    {
        echo ""
        echo "# Script gcp_prereqs.sh output variables"
        echo "# Generated on ${iso_date_utc}"
        echo "WORKLOAD_POOL=$pool_id"
    }>> "$ENV_FILE"
}


## Globals
PROJ_ROOT_PATH=$(cd "$(dirname "$0")"/..; pwd)
ENV_FILE="${PROJ_ROOT_PATH}/.env"
iso_date_utc=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

create_projects
configure_workload_identity_federation