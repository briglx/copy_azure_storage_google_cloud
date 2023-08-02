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
param storageContainerName string = ''
param eventGridName string = ''
param appServicePlanName string = ''
param apiServiceName string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, applicationName, environmentName, location))
var tags = { 'app-name': applicationName, 'env-name': environmentName }
var finalEventGridName = !empty(eventGridName) ? eventGridName : '${abbrs.eventGridDomainsTopics}${resourceToken}'

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
        name: !empty(storageContainerName) ? storageContainerName : '${abbrs.storageStorageContainer}${resourceToken}'
        publicAccess: 'Blob'
      }
    ]
  }
}

module eventGrid './core/pubsub/event-grid.bicep' = {
  name: 'events-module'
  scope: rg
  params: {
    name: finalEventGridName
    location: location
    tags: tags
    endpoint: ''
    eventSubName: '${finalEventGridName}-subs'
    storageAccountId: storageAccount.outputs.id
  }
}


/////////// Function App ///////////

module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
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
    name: !empty(apiServiceName) ? apiServiceName : '${abbrs.webSitesFunctions}api-${resourceToken}'
    location: location
    tags: tags
    alwaysOn: false
    // appSettings: {
    //   EVENT_GRID_ENDPOINT: eventGrid.properties.endpoint
    //   EVENT_GRID_TOPIC_KEY: eventGrid.listKeys().key1
    // }
    appServicePlanId: appServicePlan.outputs.id
    keyVaultName: keyVault.outputs.name
    runtimeName: 'node'
    runtimeVersion: '18'
    storageAccountName: storageAccount.outputs.name
  }
}

output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId

output SERVICE_API_NAME string = functions.outputs.name

output STORAGE_ACCOUNT_NAME string = storageAccount.outputs.name
output STORAGE_CONTAINER_NAME array = storageAccount.outputs.containerNames
