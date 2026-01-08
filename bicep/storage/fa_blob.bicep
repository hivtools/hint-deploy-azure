@description('Storage settings object for function app storage')
param faBlobSettings object

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: faBlobSettings.storageAccountName
  location: faBlobSettings.location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    allowSharedKeyAccess: false
    allowBlobPublicAccess: false
  }
  resource blobServices 'blobServices' = {
    name: 'default'
    properties: {
      deleteRetentionPolicy: {}
    }
    resource deploymentContainer 'containers' = {
      name: faBlobSettings.faStorageContainerName
      properties: {
        publicAccess: 'None'
      }
    }
  }
}

output blobInfo object = {
  storageAccountName: storageAccount.name
}
