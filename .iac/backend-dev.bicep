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

// // resource group frontend
// resource rgFrontend 'Microsoft.Resources/resourceGroups@2020-06-01' = {
//   name: rgFrontendName
//   location: resourceGroupLocation
//   tags: {
//     Environment: tagEnvironmentNameTier
//     CostCenter: tagCostCenter
//     GitActionIaCRunId : tagGitActionIacRunId
//     GitActionIaCRunNumber : tagGitActionIacRunNumber 
//     GitActionIaCRunAttempt : tagGitActionIacRunAttempt
//     GitActionIacActionsLink : tagGitActionIacActionsLink
//   }
// }

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

// // module keyvault
// module kv './modules/keyvault/kv.bicep' = {
//   name: 'kv01'
//   scope: resourceGroup(rgInfra.name)
//   params: {
//     vaultName: vaultName
//     location: kvLocation
//     sku: sku
//     tenant: tenant
//     accessPolicies: accessPolicies
//     tagEnvironmentNameKv: tagEnvironmentNameKv
//     tagCostCenterKv: tagCostCenterKv
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
