@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('The prefix to use for all resource names')
param prefix string = 'nm'

@description('The name of the vnet')
param vnetName string

param vnetSettings object = {
  name: vnetName
  location: location
  addressPrefixes: [
    {
      name: vnetName
      addressPrefix: '10.0.0.0/16'
    }
  ]
  subnets: [
    {
      name: '${prefix}-hint-subnet'
      addressPrefix: '10.0.1.0/24'
      service: 'Microsoft.Web/serverFarms'
      public: false
    }
    {
      name: '${prefix}-hint-db-migrate-subnet'
      addressPrefix: '10.0.2.0/24'
      service: 'Microsoft.ContainerInstance/containerGroups'
      public: false
    }
    {
      name: '${prefix}-hint-db-subnet'
      addressPrefix: '10.0.3.0/24'
      service: 'Microsoft.DBforPostgreSQL/flexibleServers'
      public: false
    }
    {
      name: '${prefix}-hintr-subnet'
      addressPrefix: '10.0.4.0/24'
      service: 'Microsoft.App/environments'
      public: false
    }
    {
      name: '${prefix}-redis-subnet'
      addressPrefix: '10.0.5.0/24'
      public: false
    }
    {
      name: '${prefix}-functionapp-subnet'
      addressPrefix: '10.0.6.0/24'
      service: 'Microsoft.App/environments'
      public: false
    }
  ]
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetSettings.name
  location: vnetSettings.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetSettings.addressPrefixes[0].addressPrefix
      ]
    }
  }
}

@description('Create configured subnets')
@batchSize(1)
resource subnets 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = [for subnet in vnetSettings.subnets: {
  name: subnet.name
  parent: vnet
  properties: {
    addressPrefix: subnet.addressPrefix
    delegations: contains(subnet, 'service') && !empty(subnet.service) ? [
      {
        name: 'dlg-${subnet.service}'
        properties: {
          serviceName: subnet.service
        }
      }
    ] : []
    privateEndpointNetworkPolicies: subnet.public ? 'Disabled' : 'Enabled'
    privateLinkServiceNetworkPolicies: subnet.public ? 'Disabled' : 'Enabled'
  }
}]

var vnetInfoArray = [for (subnet, i) in vnetSettings.subnets: {
  name: subnet.name
  id: subnets[i].id
}]

output vnetInfo object = {
  vnet: {
    name: vnet.name
    id: vnet.id
  }
  subnets: toObject(vnetInfoArray, entry => entry.name)
}
