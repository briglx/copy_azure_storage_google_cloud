# Copy Azure Storage Google Cloud

This project demonstrates how to copy files between Azure and Google Cloud.

## Architecture Diagram

![Architecture Overview](./docs/architecture_overview.png)

## DevOps Architecture Diagram

![Dev Ops Architecture](./docs/devops_architecture_overview.png)

## Simplified Flow Diagram

```mermaid
flowchart LR
    A[Monitoring App] --> |write| B[StorageAccount]
    B --> |New Event| C[EventGrid]
    C .-> |Read| D[FunctionApp]
    D --> |Write| E[GoogleStorage]
```

## Components

### Solution

- [Azure Blob Storage](https://azure.microsoft.com/en-us/products/storage/blobs/) - Target storage account where monitoring applications saves new files.
- [Azure Event Grid](https://azure.microsoft.com/en-us/products/event-grid/) - Capture Storage Events.
- [Azure Function App](https://azure.microsoft.com/en-us/products/functions/) - Event-driven, serverless compute to copy file to Google Cloud Storage.
- [Google Cloud Storage](https://cloud.google.com/storage/) - Target store to save file.

### DevOps

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) - Provisioning, managing and deploying the application to Azure.
- [GitHub Actions](https://github.com/features/actions) - The CI/CD pipelines.
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/overview) - The CI/CD pipelines.

### Developer tools

- [Visual Studio Code](https://code.visualstudio.com/) - The local IDE experience.
- [GitHub Codespaces](https://github.com/features/codespaces) - The cloud IDE experience.

# Development Environment

1. Fork this repository.
2. Create a new GitHub Codespaces from your fork. This will automatically provision a new Codespaces with all the required dependencies preinstalled and configured.
3. Open a new terminal and run `npm install && npm run prepare`

# Deploy Resources

This project uses scripts to provision infrastructure, package, and deploy the application to Azure and Google Cloud.

## Prerequisites

- Azure Subscription
- [Google Cloud Project](docs/setting_up_gcp.md)
- GitHub Account
- Azure CLI
- Google Cloud CLI

## Create System Identities

The solution uses several system identities.

| System Identities                   | Authentication                                             | Authorization                                                                                                                                                                  | Purpose                                                                             |
| ----------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| `env.AZURE_CICD_CLIENT_NAME`        | OpenId Connect (OIDC) based Federated Identity Credentials | Subscription Contributor access<br>Microsoft Graph API admin consent Permissions: <ul><li>Directory.ReadWrite.All</li><li>User.Invite.All</li><li>User.ReadWrite.All</li></ul> | Deploy cloud resources: <ul><li>core infrastructure</li><li>function app</li></ul>  |
| `env.GOOGLE_CICD_SERVICE_ACCOUNT`   | OpenId Connect (OIDC) based Federated Identity Credentials | <ul><li>roles/storage.admin</li><li>roles/serviceusage.serviceUsageAdmin</li><li>roles/iam.serviceAccountCreator</li></ul>                                                     | Deploy cloud resources: <ul><li>core infrastructure</li><li>cloud storage</li></ul> |
| `env.AZURE_FUNCAPP_SERVICE_ACCOUNT` | Workload identity federation or JSON key file              | <ul><li>Storage Blob Data Reader on Storage Account</li></ul>                                                                                                                  | Read Blob Contents to copy                                                          |

```bash
# load .env vars (optional)
[ ! -f .env ] || eval "export $(grep -v '^#' .env | xargs)"
# or this version allows variable substitution and quoted long values
[ -f .env ] && while IFS= read -r line; do [[ $line =~ ^[^#]*= ]] && eval "export $line"; done < .env

# Login to cloud cli. Only required once per install.
az login --tenant $AZURE_TENANT_ID
gcloud auth login --quiet

# Create Azure CICD system identity
./scripts/create_cicd_sp.sh --cloud azure
./scripts/create_app_sp.sh --cloud azure --name "$APP_NAME" --env "$ENV_NAME"

# Set IAM project as default
gcloud config set project "$GOOGLE_IAM_PROJECT_ID"
# Create Google CICD system identity
./scripts/create_cicd_sp.sh --cloud google

```

## Provisioning

Running the following commands will provision cloud resources for deploying the application.

```bash
# Configure the environment variables. Copy `example.env` to `.env` and update the values
cp example.env .env
# load .env vars
[ ! -f .env ] || export $(grep -v '^#' .env | xargs)
# or this version allows variable substitution and quoted long values
[ -f .env ] && while IFS= read -r line; do [[ $line =~ ^[^#]*= ]] && eval "export $line"; done < .env

# Login to az. Only required once per install.
az login --tenant $AZURE_TENANT_ID

# Provision infrastructure and the development environment
./scripts/devops.sh provision --name "$APP_NAME" --environment "$ENV"

# Login to gcloud. Only required once per install.
gcloud auth activate-service-account "${GOOGLE_CICD_SERVICE_ACCOUNT}" --key-file="${GOOGLE_CICD_CLIENT_KEY_FILE}"
gcloud auth list
./scripts/gcp_provision.sh --project "$GOOGLE_PROJECT_ID" --environment "$ENV"

```

## Deployment

```bash
# load .env vars
[ ! -f .env ] || export $(grep -v '^#' .env | xargs)
# or this version allows variable substitution and quoted long values
[ -f .env ] && while IFS= read -r line; do [[ $line =~ ^[^#]*= ]] && eval "export $line"; done < .env

# Package the app using the environment variables in .azure/env + deploy the code on Azure
./scripts/devops.sh deploy --name "$APP_NAME" --environment "$ENV_NAME"

# Create event subscription
./scripts/devops.sh event --name "$APP_NAME" --environment "$ENV_NAME"
```

# Architecture Design Decisions

## Blob Storage trigger vs Event Grid trigger

If you're using earlier versions of the Blob Storage trigger with Azure Functions, you often get delayed executions because the trigger polls the blob container for updates. You can reduce latency by triggering your function using an event subscription to the same container. The event subscription forwards changes in the container as events that your function consumes by using Event Grid. You can implement this capability with Visual Studio Code with latest Azure Functions extension.

## Google CICD Authentication

Google's auth github actions recommends:

> using Workload Identity Federation instead as exporting a long-lived Service Account Key JSON credential poses a security risk.

# References

- Event Grid Trigger https://learn.microsoft.com/en-us/azure/azure-functions/functions-event-grid-blob-trigger?pivots=programming-language-javascript
- Setup Google Workload Identity Federation https://github.com/google-github-actions/auth#setup
- Google Workload Identity Federation with GitHub Actions https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines
- GitHub OIDC token attributes https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#understanding-the-oidc-token
- Google How to Authenticate Service Accounts https://cloud.google.com/blog/products/identity-security/how-to-authenticate-service-accounts-to-help-keep-applications-secure
- Python Confidential Client Example https://github.com/AzureAD/microsoft-authentication-library-for-python/blob/dev/sample/confidential_client_secret_sample.py
