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

var fileShareSettings = [for shareName in storageSettings.fileShares: {
  name: shareName
  shareName: '${shareName}-share'
  mountNameRW: '${shareName}-mount-rw'
  mountNameR: '${shareName}-mount-r'
}]

@description('Create configured file shares')
resource fileShares 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = [for share in fileShareSettings: {
  parent: fileService
  name: share.shareName
  properties: {
    accessTier: 'Premium'
  }
}]

output storageInfo object = toObject(fileShareSettings, entry => entry.name)
