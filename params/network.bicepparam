using '../bicep/network.bicep'

var deploy_environment = readEnvironmentVariable('HINT_ENV', 'staging')
var env = loadJsonContent('../config/environments.json')[deploy_environment]
param prefix = env.prefix

param location = 'eastus2'
param vnetName = '${prefix}-hint-nw'
