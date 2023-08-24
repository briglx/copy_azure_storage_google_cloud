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
./scripts/gcp_prereqs.sh
```
