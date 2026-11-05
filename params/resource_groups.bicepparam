using '../bicep/resource_groups.bicep'

var deploy_environment = readEnvironmentVariable('HINT_ENV', 'staging')
var env = loadJsonContent('../config/environments.json')[deploy_environment]

param location = 'eastus2'

// A null resource group in environments.json means that stack isn't deployed
// for this environment, so don't create a group for it
param resourceGroupNames = map(
  filter(
    [env.resourceGroup, env.observabilityResourceGroup, env.backupResourceGroup],
    name => name != null
  ),
  name => name!
)
