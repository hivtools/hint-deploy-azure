param privateEndpointSubnet string
param vnetName string

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vnetName
}

@description('Specify the name of the Azure Redis Cache to create.')
param redisName string = 'hintr-queue'

param redisDbName string = 'default'

param redisPrivateEndpointName string = 'redis-private-endpoint'

@description('Location of all resources')
param location string = resourceGroup().location

@description('Specify the pricing tier of the new Azure Redis Cache (there are others).')
@allowed([
  'Basic'
  'Standard'
  'Premium'
  'Balanced'
])
param redisCacheSKU string = 'Balanced'

@description('Specify the family for the sku. C = Basic/Standard, P = Premium, B = Balanced (there are others).')
@allowed([
  'C'
  'P'
  'B'
])
param redisCacheFamily string = 'B'

@description('Specify the size of the new Azure Redis Cache instance. Valid values: for C (Basic/Standard) family (0, 1, 2, 3, 4, 5, 6), for P (Premium) family (1, 2, 3, 4, 5)')
@allowed([
  0
  1
  2
  3
  4
  5
  6
])
param redisCacheCapacity int = 0

@description('Specify name of Built-In access policy to use as assignment.')
@allowed([
  'Data Owner'
  'Data Contributor'
  'Data Reader'
])
param builtInAccessPolicyName string = 'Data Reader'

@description('Specify name of custom access policy to create.')
param builtInAccessPolicyAssignmentName string = 'builtInAccessPolicyAssignment-${uniqueString(resourceGroup().id)}'

@description('Specify the valid objectId(usually it is a GUID) of the Microsoft Entra Service Principal or Managed Identity or User Principal to which the built-in access policy would be assigned.')
param builtInAccessPolicyAssignmentObjectId string = newGuid()

@description('Specify human readable name of principal Id of the Microsoft Entra Application name or Managed Identity name used for built-in policy assignment.')
param builtInAccessPolicyAssignmentObjectAlias string = 'builtInAccessPolicyApplication-${uniqueString(resourceGroup().id)}'

@description('Specify name of custom access policy to create.')
param customAccessPolicyName string = 'customAccessPolicy-${uniqueString(resourceGroup().id)}'

@description('Specify the valid permissions for the customer access policy to create. For details refer to https://aka.ms/redis/ConfigureAccessPolicyPermissions')
param customAccessPolicyPermissions string = '+@connection +get +hget allkeys'

@description('Specify name of custom access policy to create.')
param customAccessPolicyAssignmentName string = 'customAccessPolicyAssignment-${uniqueString(resourceGroup().id)}'

@description('Specify the valid objectId(usually it is a GUID) of the Microsoft Entra Service Principal or Managed Identity or User Principal to which the custom access policy would be assigned.')
param customAccessPolicyAssignmentObjectId string = newGuid()

@description('Specify human readable name of principal Id of the Microsoft Entra Application name or Managed Identity name used for custom policy assignment.')
param customAccessPolicyAssignmentObjectAlias string = 'customAccessPolicyApplication-${uniqueString(resourceGroup().id)}'

resource redis 'Microsoft.Cache/redisEnterprise@2024-10-01' = {
  name: redisName
  location: location
  properties: {
    minimumTlsVersion: '1.2'
  }
  sku: {
    name: 'Balanced_B0'
  }
}

resource redisDb 'Microsoft.Cache/redisEnterprise/databases@2024-10-01' = {
  parent: redis
  name: redisDbName
  properties: {
    clientProtocol: 'Plaintext'
    clusteringPolicy: 'EnterpriseCluster'
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

var privateDnsZoneName = 'privatelink.eastus.redis.azure.net'
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: privateDnsZoneName
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
  password: redisDb.listKeys().primaryKey
  hostname: '${redisName}.${privateDnsZoneName}'
  port: '10000'
  connectionString: 'redis://:${redisDb.listKeys().primaryKey}@${redisName}.${privateDnsZoneName}:10000'
}
