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

@description('The name of the main hint resource group')
param hintResourceGroup string

@description('The name of the storage account to back up')
param storageAccountName string

@description('File shares to back up')
var fileShares = [
  'results-share'
  'uploads-share'
]

@description('The name of the hint backup vault')
param vaultName string = 'hint-backup-vault'

@description('The name of the hint backup policy for file share')
param fileSharePolicyName string = 'hint-fs-backup-policy'

@description('Time of day when backup should be triggered in 24 hour HH:MM format, where MM must be 00 or 30.')
param scheduleRunTime string = '02:00'

var scheduleRunTimes = [
  '2025-01-01T${scheduleRunTime}:00Z'
]

// ------------------
// Backup vault
// ------------------

resource vault 'Microsoft.RecoveryServices/vaults@2021-12-01' = {
  name: vaultName
  location: location
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {
  }
}

resource backupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2025-02-28-preview' = {
  parent: vault
  name: fileSharePolicyName
  properties: {
    backupManagementType: 'AzureStorage'
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: scheduleRunTimes
    }
    retentionPolicy: {
      dailySchedule: {
        retentionTimes: scheduleRunTimes
        retentionDuration: {
          count: 3
          durationType: 'Days'
        }
      }
      weeklySchedule: {
        daysOfTheWeek: ['Sunday']
        retentionTimes: scheduleRunTimes
        retentionDuration: {
          count: 2
          durationType: 'Weeks'
        }
      }
      monthlySchedule: {
        retentionScheduleFormatType: 'Daily'
        retentionScheduleDaily: {
          daysOfTheMonth: [
            {
              date: 1
              isLast: false
            }
          ]
        }
        retentionTimes: scheduleRunTimes
        retentionDuration: {
          count: 3
          durationType: 'Months'
        }
      }
      yearlySchedule: {
        retentionScheduleFormatType: 'Daily'
        monthsOfYear: ['January']
        retentionScheduleDaily: {
          daysOfTheMonth: [
            {
              date: 1
              isLast: false
            }
          ]
        }
        retentionTimes: scheduleRunTimes
        retentionDuration: {
          count: 3
          durationType: 'Years'
        }
      }
      retentionPolicyType: 'LongTermRetentionPolicy'
    }
    timeZone: 'UTC'
    workLoadType: 'AzureFileShare'
  }
}

// ------------------
// File share backup
// ------------------

resource protectionContainer 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers@2025-02-28-preview' = {
  name: '${vaultName}/Azure/storagecontainer;Storage;${hintResourceGroup};${storageAccountName}'
  dependsOn: [
    vault
    backupPolicy
  ]
  properties: {
    backupManagementType: 'AzureStorage'
    containerType: 'StorageContainer'
    sourceResourceId: resourceId(hintResourceGroup, 'Microsoft.Storage/storageAccounts', storageAccountName)
  }
}

resource protectedItem 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2025-02-28-preview' = [for fileShareName in fileShares: {
  parent: protectionContainer
  name: 'AzureFileShare;${fileShareName}'
  dependsOn:[
    vault
  ]
  properties:{
    protectedItemType:'AzureFileShareProtectedItem'
    sourceResourceId: resourceId(hintResourceGroup, 'Microsoft.Storage/storageAccounts', storageAccountName)
    policyId: backupPolicy.id
  }
}]


// ------------------
// Postgres backups
// ------------------

param backupVaultName string = 'nm-postgres-backup'

resource backupVault 'Microsoft.DataProtection/backupVaults@2023-01-01' = {
  name: backupVaultName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    storageSettings: [
      {
        datastoreType: 'VaultStore'
        type: 'LocallyRedundant'
      }
    ]
  }
}

param backupPolicyName string = 'postgres-policy'

resource backupPolicyPostgres 'Microsoft.DataProtection/backupVaults/backupPolicies@2023-01-01' = {
  parent: backupVault
  name: backupPolicyName
  properties: {
    policyRules: [
      {
        name: 'WeeklyBackup'
        objectType: 'AzureBackupRule'
        backupParameters: {
          backupType: 'full'
          objectType: 'AzureBackupParams'
        }
        trigger: {
          schedule: {
            repeatingTimeIntervals: [
              'R/2025-10-05T02:00:00+00:00/P1W'
            ]
            timeZone: 'Coordinated Universal Time'
          }
          taggingCriteria: [
            {
              tagInfo: {
                tagName: 'Yearly'
              }
              taggingPriority: 10
              isDefault: false
              criteria: [
                {
                  absoluteCriteria: [
                    'FirstOfYear'
                  ]
                  objectType: 'ScheduleBasedBackupCriteria'
                }
              ]
            }
            {
              tagInfo: {
                tagName: 'Monthly'
              }
              taggingPriority: 15
              isDefault: false
              criteria: [
                {
                  absoluteCriteria: [
                    'FirstOfMonth'
                  ]
                  objectType: 'ScheduleBasedBackupCriteria'
                }
              ]
            }
            {
              tagInfo: {
                tagName: 'Weekly'
              }
              taggingPriority: 20
              isDefault: false
              criteria: [
                {
                  absoluteCriteria: [
                    'FirstOfWeek'
                  ]
                  objectType: 'ScheduleBasedBackupCriteria'
                }
              ]
            }
            {
              tagInfo: {
                tagName: 'Default'
              }
              taggingPriority: 99
              isDefault: true
            }
          ]
          objectType: 'ScheduleBasedTriggerContext'
        }
        dataStore: {
          dataStoreType: 'VaultStore'
          objectType: 'DataStoreInfoBase'
        }
      }
      {
        name: 'Yearly'
        objectType: 'AzureRetentionRule'
        isDefault: false
        lifecycles: [
          {
            deleteAfter: {
              objectType: 'AbsoluteDeleteOption'
              duration: 'P3Y'
            }
            targetDataStoreCopySettings: []
            sourceDataStore: {
              dataStoreType: 'VaultStore'
              objectType: 'DataStoreInfoBase'
            }
          }
        ]
      }
      {
        name: 'Monthly'
        objectType: 'AzureRetentionRule'
        isDefault: false
        lifecycles: [
          {
            deleteAfter: {
              objectType: 'AbsoluteDeleteOption'
              duration: 'P3M'
            }
            targetDataStoreCopySettings: []
            sourceDataStore: {
              dataStoreType: 'VaultStore'
              objectType: 'DataStoreInfoBase'
            }
          }
        ]
      }
      {
        name: 'Weekly'
        objectType: 'AzureRetentionRule'
        isDefault: false
        lifecycles: [
          {
            deleteAfter: {
              objectType: 'AbsoluteDeleteOption'
              duration: 'P3W'
            }
            targetDataStoreCopySettings: []
            sourceDataStore: {
              dataStoreType: 'VaultStore'
              objectType: 'DataStoreInfoBase'
            }
          }
          ]
      }
      {
        name: 'Default'
        objectType: 'AzureRetentionRule'
        isDefault: true
        lifecycles: [
          {
            deleteAfter: {
              objectType: 'AbsoluteDeleteOption'
              duration: 'P7D'
            }
            targetDataStoreCopySettings: []
            sourceDataStore: {
              dataStoreType: 'VaultStore'
              objectType: 'DataStoreInfoBase'
            }
          }
        ]
      }
    ]
    datasourceTypes: [
      'Microsoft.DBforPostgreSQL/flexibleServers'
    ]
    objectType: 'BackupPolicy'
  }
}

param postgresServerName string

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2025-06-01-preview' existing = {
  name: postgresServerName
  scope: resourceGroup(hintResourceGroup)
}

module roleAssignmentForPgFlex './roles/role_assignment.bicep' = {
  name: 'postgresRoleAssignment'
  scope: resourceGroup(hintResourceGroup)
  params: {
    roleDefinitionName: 'c088a766-074b-43ba-90d4-1fb21feae531'
    targetResourceId: backupVault.id
    targetResourcePrincipalId: backupVault.identity.principalId
  }
}

module roleAssignmentForDiscovery './roles/role_assignment.bicep' = {
  name: 'discoveryRoleAssignment'
  scope: resourceGroup(hintResourceGroup)
  params: {
    roleDefinitionName: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
    targetResourceId: backupVault.id
    targetResourcePrincipalId: backupVault.identity.principalId
  }
}

param postgresBackupName string = 'postgres-backup-instance'

resource backupInstance 'Microsoft.DataProtection/backupVaults/backupInstances@2025-07-01' = {
  parent: backupVault
  name: postgresBackupName
  properties: {
    friendlyName: postgresBackupName
    objectType: 'BackupInstance'
    dataSourceInfo: {
      objectType: 'Datasource'
      resourceID: postgresServer.id
      resourceName: postgresServerName
      resourceType: 'Microsoft.DBforPostgreSQL/flexibleServers'
      resourceUri: postgresServer.id
      resourceLocation: location
      datasourceType: 'Microsoft.DBforPostgreSQL/flexibleServers'
    }
    policyInfo: {
      policyId: backupPolicyPostgres.id
    }
    identityDetails: {
      useSystemAssignedIdentity: true
    }
  }
  dependsOn: [
  ]
}

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

var frequency = 'Day'
var interval = '15'
var workflowSchema = '2023-01-31-preview'
var managementUrl = environment().resourceManager
var storageUrlSuffix = environment().suffixes.storage

resource backupStorageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: blobStorageAccountName
}

var blobUploadSas string = backupStorageAccount.listServiceSAS('2021-04-01', {
  canonicalizedResource: '/blob/${blobStorageAccountName}/redis-backup'
  signedResource: 'c'
  signedProtocol: 'https'
  signedPermission: 'rwl'
  signedServices: 'b'
  signedExpiry: '2026-07-01T00:00:00Z'
}).serviceSasToken

var sasTokenFixed = replace(blobUploadSas, '%3A', ':')

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: '${prefix}-redis-backup-app'
  location: resourceGroup().location
  properties: {
    definition: {
      '$schema': workflowSchema
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        recurrence: {
          type: 'Recurrence'
          recurrence: {
            frequency: frequency
            interval: interval
          }
        }
      }
      actions: {
        exportRedis: {
          type: 'http'
          inputs: {
            method: 'POST'
            uri: '${managementUrl}/subscriptions/${subscription().subscriptionId}/resourceGroups/${hintResourceGroup}/providers/Microsoft.Cache/redisEnterprise/${redisName}/databases/default/export?api-version=2025-07-01'
            body: {
              sasUri: sasTokenFixed
            }
            authentication: {
              type: 'ManagedServiceIdentity'
            }
          }
        }
      }
    }
    parameters: {}
  }
  identity: {
    type: 'SystemAssigned'
  }
}

module redisRole './roles/redis_role.bicep' = {
  scope: subscription()
}

@description('Grants the built-in redis cache role. See https://learn.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles/databases#redis-cache-contributor')
module redisRoleAssignment './roles/role_assignment.bicep' = {
  name: 'redisRoleAssignment'
  scope: resourceGroup(hintResourceGroup)
  params: {
    roleDefinitionName: redisRole.outputs.redisRoleDefName
    targetResourceId: logicApp.id
    targetResourcePrincipalId: logicApp.identity.principalId
  }
}

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

@description('Grants the the built-in storage blob data contributor. See https://learn.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles/storage#storage-blob-data-contributor')
module blobRoleAssignment './roles/role_assignment.bicep' = {
  name: 'blobRoleAssignment'
  params: {
    roleDefinitionName: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    targetResourceId: logicApp.id
    targetResourcePrincipalId: logicApp.identity.principalId
  }
}
