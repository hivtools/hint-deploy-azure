targetScope = 'subscription'

@description('The location to create the resource groups in.')
param location string

@description('Names of the resource groups to create.')
param resourceGroupNames string[]

resource resourceGroups 'Microsoft.Resources/resourceGroups@2024-03-01' = [for name in resourceGroupNames: {
  name: name
  location: location
}]
