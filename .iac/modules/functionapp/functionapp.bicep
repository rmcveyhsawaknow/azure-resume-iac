
// common parameters
param resourceGroupLocation string
param tagEnvironmentNameTier string
param tagCostCenter string
param tagGitActionIacRunId string
param tagGitActionIacRunNumber string
param tagGitActionIacRunAttempt string
param tagGitActionIacActionsLink string

//function app parameters
param corsFriendlyDnsUri string
param corsCdnUri string
param functionAppStorageAccountName string
param functionAppAppInsightsName string
param functionAppAppServicePlanName string
param functionAppName string
param functionName string

param functionRuntime string


param functionAppKeySecretNamePrimary string
param functionAppKeySecretNameSecondary string

param keyVaultName string
param cosmosName string


resource functionAppStorageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: functionAppStorageAccountName
  location: resourceGroupLocation
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
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

resource functionAppAppInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: functionAppAppInsightsName
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

resource functionAppPlan 'Microsoft.Web/serverfarms@2020-12-01' = {
  name: functionAppAppServicePlanName
  location: resourceGroupLocation
  kind: 'functionapp'
  sku: {
    name: 'Y1'
  }
  properties: {
    reserved: true
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

resource functionApp 'Microsoft.Web/sites@2020-12-01' = {
  name: functionAppName
  location: resourceGroupLocation
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'functionapp'
  properties: {
    serverFarmId: functionAppPlan.id
    siteConfig: {
      cors: {
        allowedOrigins: [
          corsFriendlyDnsUri
          corsCdnUri
        ]
      }
      appSettings: [
        {
          name: functionAppKeySecretNamePrimary
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${functionAppKeySecretNamePrimary})'
        }
        {
          name: functionAppKeySecretNameSecondary
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${functionAppKeySecretNameSecondary})'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: functionAppAppInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${functionAppAppInsights.properties.InstrumentationKey}'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(functionAppStorageAccount.id, functionAppStorageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(functionAppStorageAccount.id, functionAppStorageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionRuntime
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
      ]
    }
    httpsOnly: true
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

resource function 'Microsoft.Web/sites/functions@2020-12-01' = {
  name: '${functionApp.name}/${functionName}'
  properties: {
    config: {
      disabled: false
      bindings: [
        {
          name: 'req'
          type: 'httpTrigger'
          direction: 'in'
          authLevel: 'function'
          methods: [
            'get'
            'post'
          ]
        }
        // {
        //   name: '$return'
        //   type: 'http'
        //   direction: 'out'
        // }
      ]
    }
    // files: {
    //   'run.csx': loadTextContent('run.csx')
    // }
  }
}

//key vault parameters
// need to fix this and move into module - https://stackoverflow.com/questions/69577692/assign-managedid-to-keyvault-access-policy

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
    createMode: 'default'
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enablePurgeProtection: true
    enableRbacAuthorization: false
    enableSoftDelete: false
    softDeleteRetentionInDays: 7
    accessPolicies: [
      {
        // applicationId: functionApp.identity.principalId
        objectId: functionApp.identity.principalId
        permissions: {
          // certificates: [
          //   'string'
          // ]
          // keys: [
          //   'string'
          // ]
          secrets: [
            'get'
            'list'
          ]
          // storage: [
          //   'string'
          // ]
        }
        tenantId: functionApp.identity.tenantId
      }
    ]
  }
}

module cosmosKeyVaultSecretPrimaryConnectionString '../keyvault/createKeyVaultSecret.bicep' = {
  dependsOn: [
  ]
  name: 'cosmosKeyVaultSecretPrimaryConnectionString'
  params: {
    keyVaultName: keyVaultName
    secretName: functionAppKeySecretNamePrimary
    secretValue: listConnectionStrings(resourceId('Microsoft.DocumentDB/databaseAccounts', cosmosName), '2021-10-15').connectionStrings[0].connectionString
  }
}

module cosmosKeyVaultSecretSecondaryConnectionString '../keyvault/createKeyVaultSecret.bicep' = {
  dependsOn: [
  ]
  name: 'cosmosKeyVaultSecretSecondaryConnectionString'
  params: {
    keyVaultName: keyVaultName
    secretName: functionAppKeySecretNameSecondary
    secretValue: listConnectionStrings(resourceId('Microsoft.DocumentDB/databaseAccounts', cosmosName), '2021-10-15').connectionStrings[1].connectionString
  }
}

output functionAppSCMI string = functionApp.identity.principalId
