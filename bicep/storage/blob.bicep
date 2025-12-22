@description('Blob settings object')
param blobSettings object

resource blobSA 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: blobSettings.storageAccountName
  location: blobSettings.location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Cool'
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' = {
  parent: blobSA
  name: 'default'
}

resource dataMigrationContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  parent: blobServices
  name: 'data-migration'
}

@description('Create file service')
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2025-01-01' = {
  parent: blobSA
  name: 'default'
}

@description('Create configured file shares')
resource fileShares 'Microsoft.Storage/storageAccounts/fileServices/shares@2025-01-01' = {
  parent: fileService
  name: 'migration-share'
}
