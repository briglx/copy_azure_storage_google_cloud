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

## Prerequisites

- Azure Subscription
- Google Cloud Account
- GitHub Account

## Provisioning

This project uses scripts to provision infrastructure, package, and deploy the application to Azure and Google Cloud. Running the following commands will get you started with deployment.

```bash
# Configure the environment variables. Copy `example.env` to `.env` and update the values
cp example.env .env
# load .env vars
[ ! -f .env ] || export $(grep -v '^#' .env | xargs)

# Login to az. Only required once per install.
az login --tenant $AZURE_TENANT_ID

# Provision infrastructure and the azd development environment
./scripts/devops.sh provision --name "$APP_NAME" --environment "$AZURE_ENV_NAME"

# Package the app using the environment variables in .azure/env + deploy the code on Azure
./scripts/devops.sh deploy
```
