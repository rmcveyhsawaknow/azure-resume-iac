//Dns parameters
param cNameValue string
param dnsZoneValue string

param frontDoorEndpointHostName string
param customDomainValidationDnsTxtRecordName string
param customDomainValidationDnsTxtRecordValue string

resource dnsZoneLookup 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: dnsZoneValue
  location: 'global'
  properties: {
    zoneType: 'Public'
  }
}

//create the dns cname record

resource dnsCname 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  //name: '${dnsZoneValue}/${cNameValue}'
  name: cNameValue
  parent: dnsZoneLookup
  properties: {
    TTL: 300
    CNAMERecord: {
      cname: frontDoorEndpointHostName //cdnProfileEndpoint.properties.hostName //output from cdn.bicep frontDoorEndpointHostName
    }
  }
}

resource customDomainValidationDnsTxtRecord 'Microsoft.Network/dnsZones/TXT@2018-05-01' = {
  name: customDomainValidationDnsTxtRecordName //'_dnsauth.${customDomain.properties.hostName}' //output from cdn.bicep customDomainValidationDnsTxtRecordName
  parent: dnsZoneLookup
  properties: {
    TTL: 300
    TXTRecords: [
      {
        value: [
          customDomainValidationDnsTxtRecordValue //'string' // output from cdn.bicep customDomainValidationDnsTxtRecordValue
        ]
      }
    ]
  }
}
