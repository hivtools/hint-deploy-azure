@description('Storage settings object')
param storageSettings object

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageSettings.storageAccountName
  location: storageSettings.location
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
  }
}]

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: storageSettings.containerAppEnvironmentName
}

@description('Create configured storage mounts')
resource storageMountsRW 'Microsoft.App/managedEnvironments/storages@2024-03-01' = [for (share, i) in fileShareSettings: {
  parent: containerAppEnvironment
  name: share.mountNameRW
  properties: {
    azureFile: {
      accountName: storageAccount.name
      shareName: fileShares[i].name
      accountKey: storageAccount.listKeys().keys[0].value
      accessMode: 'ReadWrite'
    }
  }
}]

@description('Create configured storage mounts')
resource storageMountsR 'Microsoft.App/managedEnvironments/storages@2024-03-01' = [for (share, i) in fileShareSettings: {
  parent: containerAppEnvironment
  name: share.mountNameR
  properties: {
    azureFile: {
      accountName: storageAccount.name
      shareName: fileShares[i].name
      accountKey: storageAccount.listKeys().keys[0].value
      accessMode: 'ReadOnly'
    }
  }
}]

output storageInfo object = toObject(fileShareSettings, entry => entry.name)
