// module virtual network
param vnetName string {
  default: 'vnet01'
  metadata: {
    description: 'VNet name'
  }
}

param vnetLocation string  {
  default: resourceGroup().location
  metadata: {
    description: 'Location of the virtual network'
  }
}

param vnetAddressPrefix string {
  default: '10.0.0.0/16'
  metadata: {
    description: 'Address prefix'
  }
}

param subnetName1 string  {
  default: 'subnet1'
  metadata: {
    description: 'Subnet 1 Name'
  }
}

param subnetPrefix1 string {
  default: '10.0.1.0/24'
  metadata: {
    description: 'Subnet 1 Prefix'
  }
}

param tagEnvironmentNameVnet string
param tagCostCenterVnet string

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: vnetName
  location: vnetLocation
  tags: {
    Environment: tagEnvironmentNameVnet
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