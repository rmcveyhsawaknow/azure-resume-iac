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
param functionName string
param functionAppKeySecretNamePrimary string
param functionAppKeySecretNameSecondary string

param functionRuntime string


//key vault parameters
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
  params: {
    functionAppStorageAccountName: functionAppStorageAccountName
    resourceGroupLocation: rgBackend.location
    functionAppAppInsightsName: functionAppAppInsightsName
    functionAppAppServicePlanName: functionAppAppServicePlanName
    functionAppName: functionAppName
    functionName: functionName
    corsFriendlyDnsUri: corsFriendlyDnsUri
    corsCdnUri: corsCdnUri
    functionRuntime: functionRuntime
    functionAppKeySecretNamePrimary: functionAppKeySecretNamePrimary
    functionAppKeySecretNameSecondary: functionAppKeySecretNameSecondary
    keyVaultName: keyVaultName
    keyVaultSku: keyVaultSku
    aadTenant: subscription().tenantId
    tagEnvironmentNameTier: tagEnvironmentNameTier
    tagCostCenter: tagCostCenter
    tagGitActionIacRunId : tagGitActionIacRunId
    tagGitActionIacRunNumber : tagGitActionIacRunNumber
    tagGitActionIacRunAttempt : tagGitActionIacRunAttempt 
    tagGitActionIacActionsLink : tagGitActionIacActionsLink
  }
}

// module keyvault
// module kv './modules/keyvault/kv.bicep' = {
//   name: 'keyvault01'
//   scope: resourceGroup(rgBackend.name)
//   params: {
//     keyVaultName: keyVaultName
//     resourceGroupLocation: resourceGroupLocation
//     keyVaultSku: keyVaultSku
//     aadTenant: subscription().tenantId
//     tagEnvironmentNameTier: tagEnvironmentNameTier
//     tagCostCenter: tagCostCenter
//     tagGitActionIacRunId : tagGitActionIacRunId
//     tagGitActionIacRunNumber : tagGitActionIacRunNumber
//     tagGitActionIacRunAttempt : tagGitActionIacRunAttempt 
//     tagGitActionIacActionsLink : tagGitActionIacActionsLink
//   }
// }



// create secret in existing KeyVault
//resource secret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
//  name: '${vaultName.name}/${secretName}'
//  properties: {
//    attributes: {
//      enabled: true
//    }
//    value: secretValue
//  }
//}


module cosmosKeyVaultSecretPrimaryConnectionString './modules/keyvault/createKeyVaultSecret.bicep' = {
  dependsOn: [
    cosmos
    storageFunctionApp
  ]
  scope: resourceGroup(rgBackend.name)
  name: 'cosmosKeyVaultSecretPrimaryConnectionString'
  params: {
    keyVaultName: keyVaultName
    secretName: functionAppKeySecretNamePrimary
    secretValue: listConnectionStrings(resourceId('Microsoft.DocumentDB/databaseAccounts', cosmosName), '2021-10-15').connectionStrings[0].connectionString
  }
}

module cosmosKeyVaultSecretSecondaryConnectionString './modules/keyvault/createKeyVaultSecret.bicep' = {
  dependsOn: [
    cosmos
    storageFunctionApp
  ]
  scope: resourceGroup(rgBackend.name)
  name: 'cosmosKeyVaultSecretSecondaryConnectionString'
  params: {
    keyVaultName: keyVaultName
    secretName: functionAppKeySecretNameSecondary
    secretValue: listConnectionStrings(resourceId('Microsoft.DocumentDB/databaseAccounts', cosmosName), '2021-10-15').connectionStrings[1].connectionString
  }
}

output cosmosKeyVaultSecretPrimaryConnectionString string = cosmosKeyVaultSecretPrimaryConnectionString.outputs.keyVaultSecretName
