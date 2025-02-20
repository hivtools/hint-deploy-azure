param dnsZoneName string
param privateEndpointId string
param envDefaultDomain string
param tags object
param vnetName string

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vnetName
}

var privateEndpointIdSplit = split(privateEndpointId, '/')

resource networkInterface 'Microsoft.Network/networkInterfaces@2024-05-01' existing = {
  name: privateEndpointIdSplit[length(privateEndpointIdSplit) - 1]
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dnsZoneName
  location: 'global'
  tags: tags
}

resource aRecordSet 'Microsoft.Network/privateDnsZones/A@2024-06-01' = {
  name: envDefaultDomain
  parent: privateDnsZone
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: networkInterface.properties.ipConfigurations[0].properties.privateIPAddress
      }
    ]
  }
}

// resource starRecordSet 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
//   name: '*'
//   parent: privateDnsZone
//   properties: {
//     ttl: 3600
//     aRecords: [
//       {
//         ipv4Address: envStaticIp
//       }
//     ]
//   }
// }

// resource atRecordSet 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
//   name: '@'
//   parent: privateDnsZone
//   properties: {
//     ttl: 3600
//     aRecords: [
//       {
//         ipv4Address: envStaticIp
//       }
//     ]
//   }
// }

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${vnet.name}-link'
  parent: privateDnsZone
  tags: tags
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}
