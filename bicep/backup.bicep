// ------------------
//    PARAMETERS
// ------------------

@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('The prefix to use for all resource names')
param prefix string = 'nm'

@description('The name of the external Azure Storage Account.')
param blobStorageAccountName string = 'naomibackupstorage'

@description('Name of the redis service')
param redisName string

// ------------------
// Blob backup store
// ------------------

param blobSettings object = {
  storageAccountName: blobStorageAccountName
  location: location
}

module blobModule 'storage/blob.bicep' = {
  name: 'blobDeploy'
  params: {
    blobSettings: blobSettings
  }
}

// ------------------
// Backup logic app
// ------------------

// var frequency = 'Minute'
// var interval = '2'
// var workflowSchema = '2023-01-31-preview'
// var managementUrl = environment().resourceManager
// var storageUrlSuffix = environment().suffixes.storage


// resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
//   name: '${prefix}-redis-backup-app'
//   location: resourceGroup().location
//   properties: {
//     definition: {
//       '$schema': workflowSchema
//       contentVersion: '1.0.0.0'
//       parameters: {}
//       triggers: {
//         recurrence: {
//           type: 'Recurrence'
//           recurrence: {
//             frequency: frequency
//             interval: interval
//           }
//         }
//       }
//       actions: {
//         exportRedis: {
//           type: 'http'
//           inputs: {
//             method: 'POST'
//             uri: '${managementUrl}/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Cache/Redis/${redisName}/export?api-version=2023-08-01'
//             body: {
//               format: 'RDB'
//               container: 'https://${blobStorageAccountName}.blob.${storageUrlSuffix}/redis-backup'
//               prefix: 'daily'
//             }
//             authentication: {
//               type: 'ManagedServiceIdentity'
//             }
//           }
//         }
//       }
//     }
//     parameters: {}
//   }
//   identity: {
//     type: 'SystemAssigned'
//   }
// }

// resource redis 'Microsoft.Cache/Redis@2023-08-01' existing = {
//   name: redisName
// }

// @description('This is the built-in redis cache role. See https://learn.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles/databases#redis-cache-contributor')
// resource redisContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
//   scope: subscription()
//   name: 'e0f68234-74aa-48ed-b826-c38b57376e17'
// }

// // Role assignment
// resource redisRoleAssign 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid(redis.id, logicApp.id, redisContributorRole.id)
//   properties: {
//     principalId: logicApp.identity.principalId
//     roleDefinitionId: redisContributorRole.id
//   }
// }

// resource blobSA 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
//   name: blobStorageAccountName
// }

// @description('This is the built-in storage blob data contributor. See https://learn.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles/storage#storage-blob-data-contributor')
// resource storageBlobContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
//   scope: subscription()
//   name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
// }

// resource blobRoleAssign 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid(blobSA.id, logicApp.id, storageBlobContributorRole.id)
//   properties: {
//     principalId: logicApp.identity.principalId
//     roleDefinitionId: storageBlobContributorRole.id
//   }
// }
