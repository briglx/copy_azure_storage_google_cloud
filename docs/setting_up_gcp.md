# Setting up GCP

This document describes how to setup the Google Cloud Platform (GCP) prerequisites needed for this project.

# IAM Project

GCP recommends having a separate project for IAM. The IAM project will be used to create the service accounts and permissions for the other projects.

## Create IAM Project

```bash
# load .env vars (optional)
[ ! -f .env ] || eval "export $(grep -v '^#' .env | xargs)"
# or this version allows variable substitution and quoted long values
[ -f .env ] && while IFS= read -r line; do [[ $line =~ ^[^#]*= ]] && eval "export $line"; done < .env

# Login to cloud cli. Only required once per install.
gcloud auth login --quiet

# Create Google Cloud Project.
gcloud projects create "${GOOGLE_IAM_PROJECT_ID}" --name="${GOOGLE_IAM_PROJECT_NAME}" --set-as-default --quiet
# Enable Cloud Resource Manager API
gcloud services enable cloudresourcemanager.googleapis.com

# Create Application Project
gcloud projects create "${GOOGLE_PROJECT_ID}" --name="${GOOGLE_PROJECT_NAME}" --set-as-default --quiet
gcloud services enable cloudresourcemanager.googleapis.com --project "${GOOGLE_PROJECT_ID}"
gcloud services enable cloudbilling.googleapis.com --project "${GOOGLE_PROJECT_ID}"
gcloud services enable iamcredentials.googleapis.com --project "${GOOGLE_PROJECT_ID}"

# Link billing account to project
gcloud beta billing projects link "${GOOGLE_PROJECT_ID}" --billing-account="${GOOGLE_BILLING_ACCOUNT_ID}"

# Assert billing is enabled
if [[ $(gcloud beta billing projects describe "${GOOGLE_PROJECT_ID}" --format="value(billingEnabled)") == "False" ]]; then
    echo "ERROR: Billing is not enabled for project ${GOOGLE_PROJECT_ID}"
    exit 1
fi
```
