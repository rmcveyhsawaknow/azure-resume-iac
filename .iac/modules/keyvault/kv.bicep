// module keyvault
param vaultName string {
  default: 'kvwesteurope01'
  metadata: {
    description: 'Specifies the name of the key vault..'
  }
}

param location string {
  default: resourceGroup().location
  metadata: {
    description: 'Specifies the Azure location where the key vault should be created.'
  }
}

param sku string {
  metadata: {
    description: 'Specifies whether the key vault is a standard vault or a premium vault.'
  }
}

param tenant string {
  metadata: {
    description: 'Specifies the Azure Active Directory tenant ID that should be used for authenticating requests to the key vault..'
  }
}

param accessPolicies array {
  metadata: {
    description: 'Specifies the permissions to secrets in the vault.'
  }
}

param tagEnvironmentNameKv string
param tagCostCenterKv string

resource keyvault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: vaultName
  location: location
  tags: {
    Environment: tagEnvironmentNameKv
    tagCostCenter: tagCostCenterKv
  }
  properties: {
    tenantId: tenant
    sku: {
      family: 'A'
      name: sku
    }
    accessPolicies: accessPolicies
  }
}

output name string = keyvault.name