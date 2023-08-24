#!/usr/bin/env bash
#########################################################################
# Provision Google Cloud Resources
#########################################################################

# Stop on errors
set -e

validate_parameters(){
    
    # Check GOOGLE_PROJECT_ID
    if [ -z "$GOOGLE_PROJECT_ID" ]
    then
        echo "GOOGLE_PROJECT_ID is required" >&2
        show_help
        exit 1
    fi
    
}

provision(){

    local project_id="${GOOGLE_PROJECT_ID}"
    local service_account_name="${FUNCAPP_CLIENT}"
    local service_account_display_name="${APP_FRIENDLY_NAME} Function App"
    local service_account_description="Service account used by Azure function App"

    # gcloud config set account "$GOOGLE_ACCOUNT"
    gcloud config set project "${project_id}" --quiet 
    
    # Create Storage Bucket
    gcloud storage buckets create "gs://${GOOGLE_BUCKET_NAME}" --project="${project_id}" --location="${GOOGLE_REGION}" --quiet

    # Create Service Account
    gcloud iam service-accounts create "${service_account_name}" --project="${project_id}" --display-name="${service_account_display_name}" --description "${service_account_description}" --quiet

    # Allow external identities to impersonate the service account
    gcloud iam service-accounts add-iam-policy-binding "${service_account_name}@${project_id}.iam.gserviceaccount.com" \
        --role="roles/iam.workloadIdentityUser" \
        --member="principalSet://iam.googleapis.com/projects/${project_id}/locations/global/workloadIdentityPools/${AZURE_TENANT_NAME}-identity-pool/*" \
        --project="${project_id}"
        
        
}

validate_parameters
provision