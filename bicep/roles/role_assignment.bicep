targetScope = 'resourceGroup'

@description('The principal ID of the resource to get access permissions granted')
param targetResourcePrincipalId string

@description('The ID of the resource to get access permissions granted')
param targetResourceId string

@description('The name of the built-in role to grant to target')
param roleDefinitionName string


@description('The built-in role. See https://learn.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles')
resource roleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: roleDefinitionName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(targetResourceId, roleDefinition.id)
  properties: {
    principalType: 'ServicePrincipal'
    principalId: targetResourcePrincipalId
    roleDefinitionId: roleDefinition.id
  }
}
