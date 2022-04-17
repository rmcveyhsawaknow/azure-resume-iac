//// common parameters
param resourceGroupLocation string
param tagEnvironmentNameTier string
param tagCostCenter string
param tagGitActionIacRunId string
param tagGitActionIacRunNumber string
param tagGitActionIacRunAttempt string
param tagGitActionIacActionsLink string

//storage account static site parameters
param staticSiteStorageAccountName string
param staticSiteStorageAccountAppInsightsName string

@allowed([
  'Standard_LRS'
  'Standard_GRS'
  // 'Standard_RAGRS'
  // 'Standard_ZRS'
  // 'Premium_LRS'
  // 'Premium_ZRS'
  // 'Standard_GZRS'
  // 'Standard_RAGZRS'
])
@description('The storage account sku name.')
param storageSku string = 'Standard_LRS'

resource frontendStaticSite 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: staticSiteStorageAccountName
  location: resourceGroupLocation
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
  }
  tags: {
    Environment: tagEnvironmentNameTier
    CostCenter: tagCostCenter
    GitActionIaCRunId : tagGitActionIacRunId
    GitActionIaCRunNumber : tagGitActionIacRunNumber 
    GitActionIaCRunAttempt : tagGitActionIacRunAttempt
    GitActionIacActionsLink : tagGitActionIacActionsLink
  }
}

resource frontendStaticSiteAppAppInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: staticSiteStorageAccountAppInsightsName
  location: resourceGroupLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: {
    Environment: tagEnvironmentNameTier
    CostCenter: tagCostCenter
    GitActionIaCRunId : tagGitActionIacRunId
    GitActionIaCRunNumber : tagGitActionIacRunNumber 
    GitActionIaCRunAttempt : tagGitActionIacRunAttempt
    GitActionIacActionsLink : tagGitActionIacActionsLink
  }
}

output storageEndpoint string = frontendStaticSite.properties.primaryEndpoints.web
