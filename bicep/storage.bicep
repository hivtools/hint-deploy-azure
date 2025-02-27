@description('Storage settings object')
param storageSettings object

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageSettings.storageAccountName
  location: storageSettings.location
  properties: {
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Deny'
    }
  }
  sku: {
    name: 'Premium_LRS'
  }
  kind: 'FileStorage'
}

@description('Create file service')
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

var fileShareSettings = [for share in items(storageSettings.fileShares): {
  name: share.value.name
  shareName: '${share.value.name}-share'
  mountNameRW: '${share.value.name}-mount-rw'
  mountNameR: '${share.value.name}-mount-r'
}]

@description('Create configured file shares')
resource fileShares 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = [for share in fileShareSettings: {
  parent: fileService
  name: share.shareName
  properties: {
    accessTier: 'Premium'
    enabledProtocols: 'NFS'
  }
}]

resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${storageSettings.storageAccountName}-privateendpoint'
  location: storageSettings.location
  properties: {
    privateLinkServiceConnections: [
      {
        name: '${storageSettings.storageAccountName}-privateendpoint'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
    subnet: {
      id: storageSettings.privateEndpointSubnet
    }
  }
}

var privateDnsZoneName = 'privatelink.file.${environment().suffixes.storage}'
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

// resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
//   name: storageSettings.vnetName
// }

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: storagePrivateEndpoint
  name: 'storage-endpoint-dns-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: privateDnsZone.name
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: storageSettings.containerAppEnvironmentName
}

@description('Create configured storage mounts')
resource storageMountsRW 'Microsoft.App/managedEnvironments/storages@2024-10-02-preview' = [for (share, i) in fileShareSettings: {
  parent: containerAppEnvironment
  name: share.mountNameRW
  properties: {
    nfsAzureFile: {
      shareName: '/${storageSettings.storageAccountName}/${fileShares[i].name}'
      server: '${storageSettings.storageAccountName}.${privateDnsZoneName}'
      accessMode: 'ReadWrite'
    }
  }
}]

@description('Create configured storage mounts')
resource storageMountsR 'Microsoft.App/managedEnvironments/storages@2024-10-02-preview' = [for (share, i) in fileShareSettings: {
  parent: containerAppEnvironment
  name: share.mountNameR
  properties: {
    nfsAzureFile: {
      shareName: '/${storageSettings.storageAccountName}/${fileShares[i].name}'
      server: '${storageSettings.storageAccountName}.${privateDnsZoneName}'
      accessMode: 'ReadOnly'
    }
  }
}]

output storageInfo object = toObject(fileShareSettings, entry => entry.name)
