targetScope = 'subscription'

//common parameters
param resourceGroupLocation string 
param rgBackendName string
param tagCostCenter string
param tagGitActionIacRunId string
param tagGitActionIacRunNumber string
param tagGitActionIacRunAttempt string
param tagGitActionIacActionsLink string
param tagEnvironmentNameTier string


// cosmos parameters
param cosmosName string 
param databaseName string
param containerName string
param defaultConsistencyLevel string

// function app parameters
param corsFriendlyDnsUri string
param corsCdnUri string

param functionAppStorageAccountName string
param functionAppAppInsightsName string
param functionAppAppServicePlanName string
param functionAppName string
param functionAppKeySecretNamePrimary string
param functionAppKeySecretNameSecondary string

param functionRuntime string


////key vault parameters
param keyVaultName string
param keyVaultSku string


// resource group backend
resource rgBackend 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: rgBackendName
  location: resourceGroupLocation
  tags: {
    Environment: tagEnvironmentNameTier
    CostCenter: tagCostCenter
    GitActionIaCRunId : tagGitActionIacRunId
    GitActionIaCRunNumber : tagGitActionIacRunNumber 
    GitActionIaCRunAttempt : tagGitActionIacRunAttempt
    GitActionIacActionsLink : tagGitActionIacActionsLink
  }
}

// module cosmos
module cosmos './modules/cosmos/cosmos.bicep' = {
  name: 'cosmos01'
  scope: resourceGroup(rgBackend.name)
  params: {
    cosmosName: cosmosName
    resourceGroupLocation: rgBackend.location
    defaultConsistencyLevel: defaultConsistencyLevel
    databaseName: databaseName
    containerName: containerName
    tagEnvironmentNameTier: tagEnvironmentNameTier
    tagCostCenter: tagCostCenter
    tagGitActionIacRunId : tagGitActionIacRunId
    tagGitActionIacRunNumber : tagGitActionIacRunNumber
    tagGitActionIacRunAttempt : tagGitActionIacRunAttempt 
    tagGitActionIacActionsLink : tagGitActionIacActionsLink
  }
}

module storageFunctionApp './modules/functionapp/functionapp.bicep' = {
  name: 'storageFunctionApp01'
  scope: resourceGroup(rgBackend.name)
  dependsOn: [
    cosmos
  ]
  params: {
    functionAppStorageAccountName: functionAppStorageAccountName
    resourceGroupLocation: rgBackend.location
    functionAppAppInsightsName: functionAppAppInsightsName
    functionAppAppServicePlanName: functionAppAppServicePlanName
    functionAppName: functionAppName
    // functionName: functionName
    corsFriendlyDnsUri: corsFriendlyDnsUri
    corsCdnUri: corsCdnUri
    functionRuntime: functionRuntime
    functionAppKeySecretNamePrimary: functionAppKeySecretNamePrimary
    functionAppKeySecretNameSecondary: functionAppKeySecretNameSecondary
    keyVaultName: keyVaultName
    keyVaultSku: keyVaultSku
    aadTenant: subscription().tenantId
    cosmosName: cosmosName
    tagEnvironmentNameTier: tagEnvironmentNameTier
    tagCostCenter: tagCostCenter
    tagGitActionIacRunId : tagGitActionIacRunId
    tagGitActionIacRunNumber : tagGitActionIacRunNumber
    tagGitActionIacRunAttempt : tagGitActionIacRunAttempt 
    tagGitActionIacActionsLink : tagGitActionIacActionsLink
  }
}






