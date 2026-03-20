
//// common parameters
param aadTenant string
param resourceGroupLocation string
param tagEnvironmentNameTier string
param tagCostCenter string
param tagGitActionIacRunId string
param tagGitActionIacRunNumber string
param tagGitActionIacRunAttempt string
param tagGitActionIacActionsLink string

//function app parameters
param corsFriendlyDnsUri string
param functionAppStorageAccountName string
param functionAppAppInsightsName string
param functionAppAppServicePlanName string
param functionAppName string
@allowed([
  'dotnet-isolated'
  'dotnet'
  'node'
  'python'
  'java'
])
param functionRuntime string
param functionAppKeySecretNamePrimary string
param functionAppKeySecretNameSecondary string
param keyVaultName string
param keyVaultSku string
param cosmosName string

var linuxFxVersionMap = {
  'dotnet-isolated': 'DOTNET-ISOLATED|8.0'
  dotnet: 'DOTNET|8.0'
  node: 'NODE|20'
  python: 'PYTHON|3.11'
  java: 'JAVA|17'
}

resource keyvault 'Microsoft.KeyVault/vaults@2024-11-01' = {
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
    enableSoftDelete: true
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

resource functionAppStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: functionAppStorageAccountName
  location: resourceGroupLocation
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
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

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${functionAppAppInsightsName}-law'
  location: resourceGroupLocation
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
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
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
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

resource functionAppPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
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

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: resourceGroupLocation
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'functionapp'
  properties: {
    serverFarmId: functionAppPlan.id
    siteConfig: {
      linuxFxVersion: linuxFxVersionMap[functionRuntime]
      ftpsState: 'Disabled'
      cors: {
        allowedOrigins: [
          corsFriendlyDnsUri
        ]
      }
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

//param guidValue string = newGuid()

var functionAppStorageKeys = functionAppStorageAccount.listKeys()

resource functionAppCosmosAppSetting 'Microsoft.Web/sites/config@2023-12-01' = {
  name: 'appsettings'
  dependsOn: [
    cosmosKeyVaultSecretPrimaryConnectionString
    cosmosKeyVaultSecretSecondaryConnectionString
  ]
  parent: functionApp
  properties: {
    AzureResumeConnectionStringPrimary: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${functionAppKeySecretNamePrimary})'
    AzureResumeConnectionStringSecondary: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${functionAppKeySecretNameSecondary})'
    APPLICATIONINSIGHTS_CONNECTION_STRING: functionAppAppInsights.properties.ConnectionString
    AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${functionAppStorageKeys.keys[0].value}'
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${functionAppStorageKeys.keys[0].value}'
    FUNCTIONS_WORKER_RUNTIME: functionRuntime
    FUNCTIONS_EXTENSION_VERSION: '~4'
    WEBSITE_CONTENTSHARE: functionAppName
  }
}

module cosmosKeyVaultSecretPrimaryConnectionString '../keyvault/createKeyVaultSecret.bicep' = {
  dependsOn: [
  keyvault
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
  keyvault
  ]
  name: 'cosmosKeyVaultSecretSecondaryConnectionString'
  params: {
    keyVaultName: keyVaultName
    secretName: functionAppKeySecretNameSecondary
    secretValue: listConnectionStrings(resourceId('Microsoft.DocumentDB/databaseAccounts', cosmosName), '2021-10-15').connectionStrings[1].connectionString
  }
}

output functionAppSCMI string = functionApp.identity.principalId
