targetScope = 'subscription'

//common parameters
param resourceGroupLocation string 
param rgBackendName string
param rgFrontendName string
param tagCostCenter string
param tagGitActionIacRunId string
param tagGitActionIacRunNumber string
param tagGitActionIacRunAttempt string
param tagGitActionIacActionsLink string


// virtual network parameters
param vnetName string 
param vnetAddressPrefix string 
param subnetName1 string 
param subnetPrefix1 string
param tagEnvironmentNameTier string


// // kubernetes parameters
// param dnsPrefix string = 'aksdwe001'
// param clusterName string = 'aks-d-we-001'
// param aksLocation string = 'westeurope'
// param agentCount int = 2
// param agentVMSize string = 'Standard_D2_v3'
// param tagEnvironmentNameAks string = 'development'
// param tagCostCenterAks string = '123'

// // keyvault parameters
// param vaultName string = 'kvdwe001'
// param kvLocation string = 'westeurope'
// param sku string = 'standard'
// param tenant string = 'f0d1d268-e79f-49c2-b61c-5ec11119b78c'  // replace with your tenantId
// param accessPolicies array = [
//   {
//     tenantId: tenant
//     objectId: 'b25c764d-9768-4ad5-8923-2e14027d80e9'  // replace with your objectId
//     permissions: {
//       secrets: [
//         'Get'
//         'List'
//         'Set'
//       ]
//     }
//   }
// ]

// param secretName string = 'password'
// param secretValue string = '12345'
// param tagEnvironmentNameKv string = 'development'
// param tagCostCenterKv string = '123'

//// resource group infra
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

// resource group kubernetes
resource rgFrontend 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: rgFrontendName
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

// module virtual network
module vnet './modules/virtualnetwork/vnet.bicep' = {
  name: 'vnet01'
  scope: resourceGroup(rgBackend.name)
  params: {
    vnetName: vnetName
    vnetLocation: rgBackend.location
    vnetAddressPrefix: vnetAddressPrefix
    subnetName1: subnetName1
    subnetPrefix1: subnetPrefix1
    tagEnvironmentNameTier: tagEnvironmentNameTier
    tagCostCenter: tagCostCenter
    tagGitActionIacRunId : tagGitActionIacRunId
    tagGitActionIacRunNumber : tagGitActionIacRunNumber
    tagGitActionIacRunAttempt : tagGitActionIacRunAttempt 
    tagGitActionIacActionsLink : tagGitActionIacActionsLink
  }
}

// // module azure kubernetes service
// module aks './modules/kubernetes/aks.bicep' = {
//   name: 'aks01'
//   scope: resourceGroup(rgAks.name)
//   params: {
//     dnsPrefix: dnsPrefix
//     clusterName: clusterName
//     location: aksLocation
//     agentCount: agentCount
//     agentVMSize: agentVMSize
//     vnetSubnetId: vnet.outputs.subnets[0].id
//     tagEnvironmentNameAks: tagEnvironmentNameAks
//     tagCostCenterAks: tagCostCenterAks
//   }
// }

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
