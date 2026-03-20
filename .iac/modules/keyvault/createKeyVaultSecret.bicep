param keyVaultName string
param secretName string


#disable-next-line secure-secrets-in-params   // Doesn't contain a secret
param secretValue string

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  name: '${keyVaultName}/${secretName}' 
  properties: {
    value: secretValue
  }
}

output keyVaultSecretName string = keyVaultSecret.name
