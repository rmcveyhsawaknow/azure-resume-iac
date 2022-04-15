targetScope = 'subscription'

// virtual network parameters
param vnetName string = 'vnet-p-we-001'
param vnetLocation string = 'westeurope'
param vnetAddressPrefix string = '11.0.0.0/16'
param subnetName1 string = 'snet-p-we-001-aks-pool01'
param subnetPrefix1 string = '11.0.1.0/24'
param tagEnvironmentNameVnet string = 'production'
param tagCostCenterVnet string = '123'

// kubernetes parameters
param dnsPrefix string = 'akspwe001'
param clusterName string = 'aks-p-we-001'
param aksLocation string = 'westeurope'
param agentCount int = 2
param agentVMSize string = 'Standard_D2_v3'
param tagEnvironmentNameAks string = 'production'
param tagCostCenterAks string = '123'

// keyvault parameters
param vaultName string = 'kvpwe001'
param kvLocation string = 'westeurope'
param sku string = 'standard'
param tenant string = 'f0d1d268-e79f-49c2-b61c-5ec11119b78c'  // replace with your tenantId
param accessPolicies array = [
  {
    tenantId: tenant
    objectId: 'b25c764d-9768-4ad5-8923-2e14027d80e9'  // replace with your objectId
    permissions: {
      secrets: [
        'Get'
        'List'
        'Set'
      ]
    }
  }
]
param secretName string = 'password'
param secretValue string = '12345'
param tagEnvironmentNameKv string = 'production'
param tagCostCenterKv string = '123'

// resource group infra
resource rgInfra 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '_rg-infra-p-we-001'
  location: 'westeurope'
}

// resource group kubernetes
resource rgAks 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '_rg-aks-p-we-001'
  location: 'westeurope'
}

// module virtual network
module vnet './modules/virtualnetwork/vnet.bicep' = {
  name: 'vnet01'
  scope: resourceGroup(rgInfra.name)
  params: {
    vnetName: vnetName
    vnetLocation: vnetLocation
    vnetAddressPrefix: vnetAddressPrefix
    subnetName1: subnetName1
    subnetPrefix1: subnetPrefix1
    tagEnvironmentNameVnet: tagEnvironmentNameVnet
    tagCostCenterVnet: tagCostCenterVnet
  }
}

// module azure kubernetes service
module aks './modules/kubernetes/aks.bicep' = {
  name: 'aks01'
  scope: resourceGroup(rgAks.name)
  params: {
    dnsPrefix: dnsPrefix
    clusterName: clusterName
    location: aksLocation
    agentCount: agentCount
    agentVMSize: agentVMSize
    vnetSubnetId: vnet.outputs.subnets[0].id
    tagEnvironmentNameAks: tagEnvironmentNameAks
    tagCostCenterAks: tagCostCenterAks
  }
}

// module keyvault
module kv './modules/keyvault/kv.bicep' = {
  name: 'kv01'
  scope: resourceGroup(rgInfra.name)
  params: {
    vaultName: vaultName
    location: kvLocation
    sku: sku
    tenant: tenant
    accessPolicies: accessPolicies
    tagEnvironmentNameKv: tagEnvironmentNameKv
    tagCostCenterKv: tagCostCenterKv
  }
}

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