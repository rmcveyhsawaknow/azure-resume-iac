// module virtual network
param vnetName string 

param vnetLocation string  

param vnetAddressPrefix string

param subnetName1 string 

param subnetPrefix1 string 

param tagEnvironmentNameTier string
param tagCostCenterVnet string

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: vnetName
  location: vnetLocation
  tags: {
    Environment: tagEnvironmentNameTier
    tagCostCenter: tagCostCenterVnet
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName1
        properties: {
          addressPrefix: subnetPrefix1
        }
      }
    ]
  }
}

output id string = vnet.id
output name string = vnet.name
output subnets array = vnet.properties.subnets
