#!/bin/bash
# ######################################################
# Copy local file to GCP Storage
# Globals:
#   GOOGLE_PROJECT_ID
#   WORKLOAD_IDENTITY_PROVIDER  The full identifier of the
#        Workload Identity Provider, including the project
#       number, pool name, and provider name. If provided,
#       this must be the full identifier which includes all parts.
#   GOOGLE_BUCKET_NAME
# Params
#    -o, --
#    -f, --file             Local file name.
#    -h, --help             Show this message and get help for a command.
# ######################################################

# Stop on errors
set -e

show_help() {
    echo "$0 : Copy local file to GCP Storage" >&2
    echo "Usage: copy_to_gcp.sh [OPTIONS]"
    echo "Globals"
    echo "   GOOGLE_PROJECT_ID"
    echo "   WORKLOAD_IDENTITY_PROVIDER"
    echo "   GOOGLE_BUCKET_NAME"
    echo
    echo "Arguments"
    echo "   -f, --file             Local file name."
    echo "   -h, --help             Show this message and get help for a command."
    echo
}

validate_parameters(){
    # Check file
    if [ -z "$local_file_name" ]
    then
        echo "file is required" >&2
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

    # Check WORKLOAD_IDENTITY_PROVIDER
    if [ -z "$WORKLOAD_IDENTITY_PROVIDER" ]
    then
        echo "WORKLOAD_IDENTITY_PROVIDER is required" >&2
        show_help
        exit 1
    fi
}

auth_gsutil(){


    pass
}

gsutil_copy_file(){
    local local_file_name="$1"
    destination="gs://${GOOGLE_BUCKET_NAME}/$(basename "${local_file_name}")"

    # Authenticate and copy
    # gsutil auth "$json_cred_key"
    # gsutil cp "$local_file_name" "gs://$GOOGLE_BUCKET_NAME"

    # OR Pass the credentials in a file
    # json_cred_key=$(gcloud iam service-accounts keys create - \
    #     --iam-account="$WORKLOAD_IDENTITY_PROVIDER" \
    #     --project="$GOOGLE_PROJECT_ID" \
    #     --format="json" | jq -r '.privateKeyData')
    gsutil -o "Credentials=${DWIF_TOKEN_FILE}" cp "${LOCAL_FILE}" "${GCS_URI}"

}

gcloud_copy_file(){
    local local_file_name="$1"
    destination="gs://${GOOGLE_BUCKET_NAME}/$(basename "${local_file_name}")"
    local_sp_name=$(echo "$GOOGLE_CICD_SERVICE_ACCOUNT" | cut -d'@' -f 1 | tr '[:upper:]' '[:lower:]'])
    local key_file="creds-${local_sp_name}.${FILE_TIMESTAMP}.json"

    echo "Copy $local_file_name to $destination"
    echo "GOOGLE_CICD_SERVICE_ACCOUNT: $GOOGLE_CICD_SERVICE_ACCOUNT"
    echo "GOOGLE_PROJECT_ID: $GOOGLE_PROJECT_ID"
    echo "WORKLOAD_IDENTITY_PROVIDER: $WORKLOAD_IDENTITY_PROVIDER"
    echo "SERVICE_ACCOUNT_NAME: $GOOGLE_CICD_SERVICE_ACCOUNT"
    echo "destination: $destination"
    echo "key_file: $key_file"
    echo "local_sp_name: $local_sp_name"

    # Authenticate with Google Cloud
    # Get json key - The Google Cloud Service Account Key JSON to use for authentication.
    # json_cred_key=$(gcloud iam service-accounts keys create - \
    #     --iam-account="$WORKLOAD_IDENTITY_PROVIDER" \
    #     --project="$GOOGLE_PROJECT_ID" \
    #     --format="json" | jq -r '.privateKeyData')

    # Authenticate using workload identity federation through a service account
    # GOOGLE_CICD_SERVICE_ACCOUNT="your-service-account@your-project.iam.gserviceaccount.com"
    gcloud auth activate-service-account "${GOOGLE_CICD_SERVICE_ACCOUNT}" --key-file="${GOOGLE_CICD_CLIENT_KEY_FILE}"

    # Copy the local file to the Google Cloud Storage bucket
    gcloud storage cp "${local_file_name}" "${destination}"
    # Deactivate the service account
    gcloud auth revoke "${GOOGLE_CICD_SERVICE_ACCOUNT}"

}

# Parse params
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -f|--file) local_file_name="$2"; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

## Globals
FILE_TIMESTAMP=$(date -u +"%Y%m%dT%H%M%S")

validate_parameters

gcloud_copy_file "$local_file_name"
