param privateEndpointSubnet string
param vnetName string

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vnetName
}

@description('Specify the name of the Azure Redis Cache to create.')
param redisName string

param redisDbName string

@description('Location of all resources')
param location string = resourceGroup().location

resource redis 'Microsoft.Cache/redisEnterprise@2025-08-01-preview' = {
  name: redisName
  location: location
  properties: {
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
  }
  sku: {
    name: 'Balanced_B0'
  }
}

resource redisDb 'Microsoft.Cache/redisEnterprise/databases@2025-08-01-preview' = {
  parent: redis
  name: redisDbName
  properties: {
    clientProtocol: 'Plaintext'
    clusteringPolicy: 'NoCluster'
    evictionPolicy: 'noeviction'
    persistence: {
      aofEnabled: true
      aofFrequency: '1s'
    }
  }
}

resource redisPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${redisName}-privateendpoint'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: '${redisName}-privateendpoint'
        properties: {
          privateLinkServiceId: redis.id
          groupIds: [
            'redisEnterprise'
          ]
        }
      }
    ]
    subnet: {
      id: privateEndpointSubnet
    }
  }
}

param redisPrivateDnsZoneName string
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: redisPrivateDnsZoneName
  location: 'global'
}

resource privateDnsZoneVNetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: '${vnet.name}-link-redis'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource privateDnsZoneARecord 'Microsoft.Network/privateDnsZones/A@2024-06-01' = {
  name: redisName
  parent: privateDnsZone
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: redisPrivateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
      }
    ]
  }
}

output redisInfo object = {
  redisName: redisName
  hostname: '${redisName}.${redisPrivateDnsZoneName}'
  port: '10000'
}
