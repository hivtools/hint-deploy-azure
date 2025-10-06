@description('Storage settings object')
param storageSettings object

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageSettings.storageAccountName
  location: storageSettings.location
  sku: {
    name: 'Premium_ZRS'
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
  size: share.value.size
}]

@description('Create configured file shares')
resource fileShares 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = [for share in fileShareSettings: {
  parent: fileService
  name: share.shareName
  properties: {
    accessTier: 'Premium'
    shareQuota: share.size
  }
}]

output storageInfo object = toObject(fileShareSettings, entry => entry.name)
