#!/usr/bin/env bash
######################################################
# Set azure permissions
# Globals:
#   
#   AZURE_APP_SERVICE_CLIENT_ID
#   STORAGE_ACCOUNT_ID
######################################################

service_account_id="$AZURE_APP_SERVICE_ID"
storage_id="${STORAGE_ACCOUNT_ID}"

az role assignment create \
  --assignee-object-id "$service_account_id" \
  --role "Storage Blob Data Reader" \
  --scope "${storage_id}"
