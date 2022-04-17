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

////storage account static site parameters
param staticSiteOriginHostName string

//cdn parameters
param cdnProfileName string
param cdnProfileEndpointName string
param cdnOriginGroupName string
param cdnOriginName string

//Dns parameters
param rgDnsName string
param cNameValue string
param dnsZoneValue string

// resource group frontend
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

// module cosmos
module frontendCdn './modules/cdn/cdn.bicep' = {
  name: 'frontendCdn01'
  scope: resourceGroup(rgFrontend.name)
  params: {
    tagEnvironmentNameTier: tagEnvironmentNameTier
    tagCostCenter: tagCostCenter
    tagGitActionIacRunId : tagGitActionIacRunId
    tagGitActionIacRunNumber : tagGitActionIacRunNumber
    tagGitActionIacRunAttempt : tagGitActionIacRunAttempt 
    tagGitActionIacActionsLink : tagGitActionIacActionsLink
    staticSiteOriginHostName: staticSiteOriginHostName
    cdnProfileName: cdnProfileName
    cdnProfileEndpointName: cdnProfileEndpointName 
    cdnOriginGroupName: cdnOriginGroupName 
    cdnOriginName: cdnOriginName 
    cNameValue: cNameValue
    dnsZoneValue: dnsZoneValue
  }
}

// module dns
module frontendDns './modules/dns/azuredns.bicep' = {
  name: 'frontendDns01'
  scope: resourceGroup(rgDns.name)
  params: {
    cNameValue: cNameValue
    dnsZoneValue: dnsZoneValue
    frontDoorEndpointHostName: frontendCdn.outputs.frontDoorEndpointHostName
    customDomainValidationDnsTxtRecordName: frontendCdn.outputs.customDomainValidationDnsTxtRecordName
    customDomainValidationDnsTxtRecordValue: frontendCdn.outputs.customDomainValidationDnsTxtRecordValue
  }
}








