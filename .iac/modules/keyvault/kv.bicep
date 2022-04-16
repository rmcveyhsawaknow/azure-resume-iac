// common parameters
param resourceGroupLocation string
param tagEnvironmentNameTier string
param tagCostCenter string
param tagGitActionIacRunId string
param tagGitActionIacRunNumber string
param tagGitActionIacRunAttempt string
param tagGitActionIacActionsLink string

//key vault parameters
param keyVaultName string
param keyVaultSku string
param aadTenant string


resource keyvault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: resourceGroupLocation
  tags: {
    Environment: tagEnvironmentNameTier
    CostCenter: tagCostCenter
    GitActionIaCRunId : tagGitActionIacRunId
    GitActionIaCRunNumber : tagGitActionIacRunNumber 
    GitActionIaCRunAttempt : tagGitActionIacRunAttempt
    GitActionIacActionsLink : tagGitActionIacActionsLink
  }
  properties: {
    tenantId: aadTenant
    sku: {
      family: 'A'
      name: keyVaultSku
    }
    accessPolicies: [
      //need to fix this - https://stackoverflow.com/questions/69577692/assign-managedid-to-keyvault-access-policy
    ]
  }
}

output name string = keyvault.name
