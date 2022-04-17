// common parameters
param tagEnvironmentNameTier string
param tagCostCenter string
param tagGitActionIacRunId string
param tagGitActionIacRunNumber string
param tagGitActionIacRunAttempt string
param tagGitActionIacActionsLink string


//storage account static site parameters
param staticSiteOriginHostName string
var staticSiteOriginFlattenedHostNameInit = replace(staticSiteOriginHostName, 'https://', '')
var staticSiteOriginFlattenedHostNameFinal = replace(staticSiteOriginFlattenedHostNameInit, '/', '')


//cdn parameters
param cdnProfileName string
param cdnProfileEndpointName string
param cdnOriginGroupName string
param cdnOriginName string
param cdnRouteName string = 'MainRoute'

@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param skuName string = 'Standard_AzureFrontDoor'


//Dns parameters
param cNameValue string
param dnsZoneValue string
var customDomainName = '${cNameValue}.${dnsZoneValue}'
// Create a valid resource name for the custom domain. Resource names don't include periods. :)  :(  ;)
var customDomainResourceName = replace(customDomainName, '.', '-')


resource cdnProfile 'Microsoft.Cdn/profiles@2020-09-01' = {
  name: cdnProfileName
  location: 'global'
  sku: {
    name: skuName
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

resource cdnProfileEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2020-09-01' = {
  name: cdnProfileEndpointName
  parent: cdnProfile
  location: 'global'
  properties: {
    originResponseTimeoutSeconds: 240
    enabledState: 'Enabled'
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

resource cdnOriginGroup 'Microsoft.Cdn/profiles/originGroups@2020-09-01' = {
  name: cdnOriginGroupName
  parent: cdnProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 100
    }
  }
}

resource customDomain 'Microsoft.Cdn/profiles/customDomains@2020-09-01' = {
  name: customDomainResourceName
  parent: cdnProfile
  properties: {
    hostName: customDomainName
    tlsSettings: {
      certificateType: 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
    }
  }
  dependsOn: [
    cdnProfileEndpoint
  ]
}

resource cdnOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2020-09-01' = {
  name: cdnOriginName
  parent: cdnOriginGroup
  properties: {
    hostName: staticSiteOriginFlattenedHostNameFinal
    httpPort: 80
    httpsPort: 443
    originHostHeader: staticSiteOriginFlattenedHostNameFinal
    priority: 1
    weight: 1000
  }
}

resource cdnRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2020-09-01' = {
  name: cdnRouteName
  parent: cdnProfileEndpoint
  dependsOn:[
    cdnOrigin // This explicit dependency is required to ensure that the origin group is not empty when the route is created.
  ]
  properties: {
    customDomains: [
      {
        id: customDomain.id
      }
    ]
    originGroup: {
      id: cdnOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    queryStringCachingBehavior: 'IgnoreQueryString'
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
}

output customDomainValidationDnsTxtRecordName string = '_dnsauth.${cNameValue}'
output customDomainValidationDnsTxtRecordValue string = customDomain.properties.validationProperties.validationToken
output customDomainValidationExpiry string = customDomain.properties.validationProperties.expirationDate
output frontDoorEndpointHostName string = cdnProfileEndpoint.properties.hostName
