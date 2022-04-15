// module kubernetes
param dnsPrefix string {
  default: 'cl01'
  metadata: {
    description: 'The DNS prefix to use with hosted Kubernetes API server FQDN.'
  }
}

param clusterName string {
  default: 'aks101'
  metadata: {
    description: 'The name of the Managed Cluster resource.'
  }
}

param location string {
  default: resourceGroup().location
  metadata: {
    description: 'Specifies the Azure location where the key vault should be created.'
  }
}

param agentCount int {
  default: 1
  minValue: 1
  maxValue: 50
  metadata: {
    description: 'The number of nodes for the cluster. 1 Node is enough for Dev/Test and minimum 3 nodes, is recommended for Production'
  }
}

param agentVMSize string {
  default: 'Standard_D2_v3'
  metadata: {
    description: 'The size of the Virtual Machine.'
  }
}

param tagEnvironmentNameAks string
param tagCostCenterAks string
param vnetSubnetId string

resource aks 'Microsoft.ContainerService/managedClusters@2020-09-01' = {
  name: clusterName
  location: location
  tags: {
    Environment: tagEnvironmentNameAks
    tagCostCenter: tagCostCenterAks
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enableRBAC: true
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: 'pool01'
        count: agentCount
        mode: 'System'
        vmSize: agentVMSize
        type: 'VirtualMachineScaleSets'
        osType: 'Linux'
        enableAutoScaling: false
        vnetSubnetID: vnetSubnetId
      }
    ]
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    networkProfile: {
      networkPlugin: 'azure'
      loadBalancerSku: 'standard'
    }
  }
}

output id string = aks.id
output apiServerAddress string = aks.properties.fqdn
output name string = aks.name