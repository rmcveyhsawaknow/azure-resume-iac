targetScope = 'subscription'

//common parameters
param resourceGroupLocation string 
param rgFrontendName string
param tagCostCenter string
param tagGitActionIacRunId string
param tagGitActionIacRunNumber string
param tagGitActionIacRunAttempt string
param tagGitActionIacActionsLink string
param tagEnvironmentNameTier string


//storage account static site parameters
param staticSiteStorageAccountName string
param staticSiteStorageAccountAppInsightsName string

// resource group backend
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

// module cosmos
module frontendStaticSite './modules/storageaccount/sa_staticsite.bicep' = {
  name: 'staticSiteStorageAccountName01'
  scope: resourceGroup(rgFrontend.name)
  params: {
    staticSiteStorageAccountName: staticSiteStorageAccountName
    resourceGroupLocation: rgFrontend.location
    staticSiteStorageAccountAppInsightsName: staticSiteStorageAccountAppInsightsName
    tagEnvironmentNameTier: tagEnvironmentNameTier
    tagCostCenter: tagCostCenter
    tagGitActionIacRunId : tagGitActionIacRunId
    tagGitActionIacRunNumber : tagGitActionIacRunNumber
    tagGitActionIacRunAttempt : tagGitActionIacRunAttempt 
    tagGitActionIacActionsLink : tagGitActionIacActionsLink
  }
}








