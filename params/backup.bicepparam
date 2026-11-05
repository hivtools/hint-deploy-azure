using '../bicep/backup.bicep'

var deploy_environment = readEnvironmentVariable('HINT_ENV', 'staging') 
var env = loadJsonContent('../config/environments.json')[deploy_environment]
param prefix = env.prefix

param redisName = '${prefix}-hintr-queue'
param hintResourceGroup = 'nmHint-RG'
param storageAccountName = env.storageAccountName
param postgresServerName = 'nm-hint-db'
