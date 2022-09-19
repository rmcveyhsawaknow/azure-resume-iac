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
// param cdnProfileEndpointName string
// param cdnOriginGroupName string
param cdnOriginName string
param cdnRouteName string = 'MainRoute'


//Dns parameters
param cNameValue string
param dnsZoneValue string
var customDomainName = '${cNameValue}.${dnsZoneValue}'
// Create a valid resource name for the custom domain. Resource names don't include periods. :)  :(  ;)
//var customDomainResourceName = replace(customDomainName, '.', '-')





// @description('The name of the Front Door resource.')
// param cdnProfileName string

// @description('The hostname of the backend. Must be a public IP address or FQDN.')
// param backendAddress string

var frontEndEndpointDefaultHostName = '${cdnProfileName}.azurefd.net'
var frontEndEndpointDefaultName = replace(frontEndEndpointDefaultHostName, '.', '-')
var frontEndEndpointCustomName = replace(customDomainName, '.', '-')
var loadBalancingSettingsName = 'loadBalancingSettings'
var healthProbeSettingsName = 'healthProbeSettings'
// var routingRuleName = 'routingRule'
// var backendPoolName = 'backendPool'

resource frontDoor 'Microsoft.Network/frontDoors@2020-01-01' = {
  name: cdnProfileName
  location: 'global'
  tags: {
    Environment: tagEnvironmentNameTier
    CostCenter: tagCostCenter
    GitActionIaCRunId : tagGitActionIacRunId
    GitActionIaCRunNumber : tagGitActionIacRunNumber 
    GitActionIaCRunAttempt : tagGitActionIacRunAttempt
    GitActionIacActionsLink : tagGitActionIacActionsLink
  }
  properties: {
    enabledState: 'Enabled'

    frontendEndpoints: [
      {
        name: frontEndEndpointDefaultName
        properties: {
          hostName: frontEndEndpointDefaultHostName
          sessionAffinityEnabledState: 'Disabled'
        }
      }
      {
        name: frontEndEndpointCustomName
        properties: {
          hostName: customDomainName
          sessionAffinityEnabledState: 'Disabled'
        }
      }
    ]

    loadBalancingSettings: [
      {
        name: loadBalancingSettingsName
        properties: {
          sampleSize: 4
          successfulSamplesRequired: 2
        }
      }
    ]

    healthProbeSettings: [
      {
        name: healthProbeSettingsName
        properties: {
          path: '/'
          protocol: 'Http'
          intervalInSeconds: 120
        }
      }
    ]

    backendPools: [
      {
        name: cdnOriginName
        properties: {
          backends: [
            {
              address: staticSiteOriginFlattenedHostNameFinal
              backendHostHeader: staticSiteOriginFlattenedHostNameFinal
              httpPort: 80
              httpsPort: 443
              weight: 50
              priority: 1
              enabledState: 'Enabled'
            }
          ]
          loadBalancingSettings: {
            id: resourceId('Microsoft.Network/frontDoors/loadBalancingSettings', cdnProfileName, loadBalancingSettingsName)
          }
          healthProbeSettings: {
            id: resourceId('Microsoft.Network/frontDoors/healthProbeSettings', cdnProfileName, healthProbeSettingsName)
          }
        }
      }
    ]

    routingRules: [
      {
        name: cdnRouteName
        properties: {
          frontendEndpoints: [
            {
              id: resourceId('Microsoft.Network/frontDoors/frontEndEndpoints', cdnProfileName, frontEndEndpointDefaultName)
            }
            {
              id: resourceId('Microsoft.Network/frontDoors/frontEndEndpoints', cdnProfileName, frontEndEndpointCustomName)
            }
          ]
          acceptedProtocols: [
            'Http'
            'Https'
          ]
          patternsToMatch: [
            '/*'
          ]
          routeConfiguration: {
            '@odata.type': '#Microsoft.Azure.FrontDoor.Models.FrontdoorForwardingConfiguration'
            forwardingProtocol: 'MatchRequest'
            backendPool: {
              id: resourceId('Microsoft.Network/frontDoors/backEndPools', cdnProfileName, cdnOriginName)
            }
          }
          enabledState: 'Enabled'
        }
      }
    ]
  }

  resource frontendEndpoint 'frontendEndpoints' existing = {
    name: frontEndEndpointCustomName
  }
}

// This resource enables a Front Door-managed TLS certificate on the frontend.
resource customHttpsConfiguration 'Microsoft.Network/frontdoors/frontendEndpoints/customHttpsConfiguration@2020-07-01' = {
  parent: frontDoor::frontendEndpoint
  name: 'default'
  properties: {
    protocolType: 'ServerNameIndication'
    certificateSource: 'FrontDoor'
    frontDoorCertificateSourceParameters: {
      certificateType: 'Dedicated'
    }
    minimumTlsVersion: '1.2'
  }
}

output frontDoorEndpointHostName string = frontEndEndpointDefaultHostName
output customDomainValidationDnsTxtRecordName string = '_dnsauth.${cNameValue}'
output customDomainValidationDnsTxtRecordValue string = 'notValidValue'
//output customDomainValidationDnsTxtRecordValue string = customDomain.properties.validationProperties.validationToken
//output customDomainValidationExpiry string = customDomain.properties.validationProperties.expirationDate
