targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Id of the user or app to assign application roles')
param principalId string = ''

@minLength(1)
@maxLength(64)
@description('Application name')
param applicationName string

param keyVaultName string = ''
param storageAccountName string = ''
param eventGridEventSubscriptionName string = ''
param applicationInsightsName string = ''
param functionEndpoint string = ''
param logAnalyticsName string = ''
param appServicePlanName string = ''
param apiServiceName string = ''
param acrName string = ''
param acrSku string = ''
param createEventSubscription bool = false
param functionName string = 'ProcessBlobEvents'

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, applicationName, environmentName, location))
var tags = { 'app-name': applicationName, 'env-name': environmentName }

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${abbrs.resourcesResourceGroups}${applicationName}_${environmentName}_${location}'
  location: location
  tags: tags
}

/////////// Common ///////////

// Store secrets in a keyvault
module keyVault './core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
  }
}

module storageAccount './core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    allowBlobPublicAccess: true
    location: location
    containers: [
      {
        name: '${abbrs.storageStorageContainer}-sample'
        publicAccess: 'Blob'
      }
    ]
  }
}

// Azure Container Registry
module containerRegistry './core/host/containerregistry.bicep' = {
  name: 'containerRegistry'
  scope: rg
  params: {
    name: !empty(acrName) ? acrName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
    acrSku: !empty(acrSku) ? acrSku : 'Basic'
  }
}

module eventGrid './core/pubsub/event-grid.bicep' = {
  name: 'events-module'
  scope: rg
  params: {
    name: '${abbrs.eventGridSystemTopic}${applicationName}-${environmentName}-${storageAccount.outputs.name}'
    location: location
    tags: tags
    endpoint: !empty(functionEndpoint) ? functionEndpoint : '${functions.outputs.id}/functions/${functionName}'
    createEventSubscription: createEventSubscription
    eventSubName: !empty(eventGridEventSubscriptionName) ? eventGridEventSubscriptionName : '${abbrs.eventGridEventSubscriptions}${resourceToken}-${functionName}'
    storageAccountId: storageAccount.outputs.id
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
  }
}

/////////// Function App ///////////

module fxnstore './core/storage/storage-account.bicep' = {
  name: 'fxnstore'
  scope: rg
  params: {
    name: '${abbrs.storageStorageAccounts}${resourceToken}fx'
    allowBlobPublicAccess: true
    location: location
  }
}

module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${applicationName}-${environmentName}-${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'Y1'
      tier: 'Dynamic'
    }
  }
}

module functions './core/host/functions.bicep' = {
  name: '${applicationName}-functions'
  scope: rg
  params: {
    name: !empty(apiServiceName) ? apiServiceName : '${abbrs.webSitesFunctions}${applicationName}-${environmentName}-${resourceToken}'
    location: location
    tags: tags
    alwaysOn: false
    appSettings: {
      AzureWebJobsFeatureFlags: 'EnableWorkerIndexing'
      FUNCTIONS_WORKER_RUNTIME: 'python'
      AZURE_TENANT_ID: tenant().tenantId
    }
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: appServicePlan.outputs.id
    keyVaultName: keyVault.outputs.name
    runtimeName: 'python'
    runtimeVersion: '3.10'
    storageAccountName: fxnstore.outputs.name
  }
}

output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_LOCATION string = location

output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output STORAGE_ACCOUNT_ID string = storageAccount.outputs.id
output STORAGE_ACCOUNT_NAME string = storageAccount.outputs.name
output STORAGE_CONTAINER_NAME array = storageAccount.outputs.containerNames
output EVENT_GRID_NAME string = eventGrid.outputs.systemTopicName
output APPLICATION_INSIGHTS_NAME string = monitoring.outputs.applicationInsightsName
output LOG_ANALYTICS_NAME string = monitoring.outputs.logAnalyticsName
output APP_SERVICE_PLAN_NAME string = appServicePlan.outputs.name
output FUNCTION_APP_ID string = functions.outputs.id
output FUNCTION_APP_NAME string = functions.outputs.name
output FUNCTION_APP_HOST_NAME string = functions.outputs.uri
output FUNCTION_APP_PRINCIPAL_ID string = functions.outputs.identityPrincipalId
output RESOURCE_TOKEN string = resourceToken
