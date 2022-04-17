targetScope = 'subscription'

//common parameters
param resourceGroupLocation string 
// param rgFrontendName string
param tagCostCenter string
param tagGitActionIacRunId string
param tagGitActionIacRunNumber string
param tagGitActionIacRunAttempt string
param tagGitActionIacActionsLink string
param tagEnvironmentNameTier string

//cdn parameters


//Dns parameters
param rgDnsName string
param cNameValue string
param dnsZoneValue string


// resource group dns global
resource rgDns 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: rgDnsName
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

// module dns
module frontendDns './modules/dns/azuredns.bicep' = {
  name: 'frontendDns01'
  scope: resourceGroup(rgDns.name)
  params: {
    cNameValue: cNameValue
    dnsZoneValue: dnsZoneValue
  }
}








