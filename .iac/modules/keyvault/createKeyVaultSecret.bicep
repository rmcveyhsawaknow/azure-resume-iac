param keyVaultName string
param secretName string

#disable-next-line secure-secrets-in-params   // Doesn't contain a secret
param secretValue string

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVaultName}/${secretName}' 
  properties: {
    value: secretValue
  }
}

output keyVaultSecretName string = keyVaultSecret.name
