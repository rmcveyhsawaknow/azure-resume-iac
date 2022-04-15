
// common parameters
param resourceGroupLocation string
param tagEnvironmentNameTier string
param tagCostCenter string
param tagGitActionIacRunId string
param tagGitActionIacRunNumber string
param tagGitActionIacRunAttempt string
param tagGitActionIacActionsLink string

//cosmos parameters
@description('The default consistency level of the Cosmos DB account.')
@allowed([
  'Eventual'
  'ConsistentPrefix'
  'Session'
  'BoundedStaleness'
  'Strong'
])
param defaultConsistencyLevel string 
param databaseName string 
param containerName string
param cosmosName string

resource cosmos_accountName_resource 'Microsoft.DocumentDB/databaseAccounts@2021-10-15' = {
  name: cosmosName
  location: resourceGroupLocation
  kind: 'GlobalDocumentDB'
  properties: {
    //enableFreeTier: true
    consistencyPolicy: {
      defaultConsistencyLevel: defaultConsistencyLevel
    }
    locations: [
      {
        locationName: resourceGroupLocation
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    databaseAccountOfferType: 'Standard'
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

resource cosmos_accountName_databaseName 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-10-15' = {
  parent: cosmos_accountName_resource
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource accountName_databaseName_containerName 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-10-15' = {
  parent: cosmos_accountName_databaseName
  name: containerName
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
    }
  }
}
