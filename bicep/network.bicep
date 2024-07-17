@description('Vnet settings object')
param vnetSettings object

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

resource subnets 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = [for subnet in vnetSettings.subnets: {
  name: subnet.name
  parent: vnet
  properties: {
    addressPrefix: subnet.addressPrefix
    delegations: [
      {
        name: 'dlg-${subnet.service}'
        properties: {
          serviceName: subnet.service
        }
      }
    ]
    privateEndpointNetworkPolicies: subnet.public ? 'Disabled' : 'Enabled'
    privateLinkServiceNetworkPolicies: subnet.public? 'Disabled' : 'Enabled'
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

// @description('Composing the subnetId')
// var postgresSubnetId = '${vnetLink.properties.virtualNetwork.id}/subnets/${hintDbSubnetName}'
