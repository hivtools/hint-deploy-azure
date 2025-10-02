targetScope = 'subscription'

@description('Array of actions for the roleDefinition')
param actions array = [
  'Microsoft.Authorization/*/read'
  'Microsoft.Cache/redis/*'
  'Microsoft.Resources/subscriptions/resourceGroups/read'
  'Microsoft.Cache/redisEnterprise/read'
  'Microsoft.Cache/redisEnterprise/databases/read'
  'Microsoft.Cache/redisEnterprise/databases/export/action'
  'Microsoft.Cache/redisEnterprise/databases/operationResults/read'
]

@description('Array of notActions for the roleDefinition')
param notActions array = []

@description('Friendly name of the role definition')
param roleName string = 'Redis enterprise exporter'

@description('Detailed description of the role definition')
param roleDescription string = 'Gives access to redis cache including exporting redis enterprise'

var roleDefName = guid(roleName)

resource roleDef 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' = {
  name: roleDefName
  properties: {
    roleName: roleName
    description: roleDescription
    type: 'customRole'
    permissions: [
      {
        actions: actions
        notActions: notActions
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

output redisRoleDefName string = roleDefName
