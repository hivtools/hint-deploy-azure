@description('Storage settings object')
param storageSettings object

// Premium shares need a premium FileStorage account, other tiers need a standard StorageV2 account
var isPremium = storageSettings.fileShareAccessTier == 'Premium'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageSettings.storageAccountName
  location: storageSettings.location
  sku: {
    name: isPremium ? 'Premium_ZRS' : 'Standard_LRS'
  }
  kind: isPremium ? 'FileStorage' : 'StorageV2'
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
    accessTier: storageSettings.fileShareAccessTier
    shareQuota: share.size
  }
}]

output storageInfo object = toObject(fileShareSettings, entry => entry.name)
