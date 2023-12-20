#!/usr/bin/env bash
######################################################
# Get versions of os, frameworks, packages, etc.
######################################################

os_version=$(lsb_release -a 2>/dev/null | grep Description | awk '{print $2, $3, $4, $5}')
shellcheck_version=$(shellcheck --version 2>/dev/null | grep version: | awk '{print $2}')
python_version=$(python --version 2>&1 | awk '{print $2}')
node_version=$(node --version 2>/dev/null)
az_cli_version=$(az --version 2>/dev/null | grep azure-cli | awk '{print $2}')
az_func_version=$(func --version 2>/dev/null)
gcp_cloud_sdk_version=$(gcloud --version 2>/dev/null | grep Google | awk '{print $4}')
gcp_core_version=$(gcloud --version 2>/dev/null | grep core | awk '{print $2}')
gcp_gsutil_version=$(gsutil --version 2>/dev/null | grep gsutil | awk '{print $3}')
bicep_version=$(az bicep version 2>/dev/null | awk '{print $4}')
pre_commit_version=$(pre-commit --version 2>/dev/null | awk '{print $2}')

versions=$(cat <<EOF
{
  "os_version": "$os_version",
  "shellcheck_version": "$shellcheck_version",
  "python_version": "$python_version",
  "node_version": "$node_version",
  "az_cli_version": "$az_cli_version",
  "az_func_version": "$az_func_version",
  "gcp_cloud_sdk_version": "$gcp_cloud_sdk_version",
  "gcp_core_version": "$gcp_core_version",
  "gcp_gsutil_version": "$gcp_gsutil_version",
  "bicep_version": "$bicep_version",
  "pre_commit_version": "$pre_commit_version"
}
EOF
)

echo "$versions"
