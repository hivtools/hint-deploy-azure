using '../bicep/containers.bicep'

param avenirAccessToken = readEnvironmentVariable('AVENIR_ACCESS_TOKEN')
var deploy_environment = readEnvironmentVariable('HINT_ENV', 'staging')
var env = loadJsonContent('../config/environments.json')[deploy_environment]

param prefix = env.prefix
param vnetName = '${prefix}-hint-nw'
param hintResourceGroup = env.resourceGroup

param storageAccountName = env.storageAccountName
param logAnalyticsWorkspaceName = 'naomiLogs'
param logsResourceGroup = 'nmHint-logs-RG'
param containerAppsEnvironmentName = '${prefix}-hint-env'
param hintAppServicePlanName = '${prefix}-hint-SP'

param databaseName = 'hint'
param postgresServerName = '${prefix}-hint-db'
param redisName = '${prefix}-hintr-queue'
param redisDbName = 'default'
param redisPrivateDnsZoneName = 'privatelink.eastus2.redis.azure.net'

param faBlobStorageAccountName = env.faBlobStorageAccountName
param faStorageContainerName = 'active-jobs'
param activeJobsFunctionAppName = '${prefix}-active-jobs'

param hintImage = 'ghcr.io/hivtools/hint:${env.hintImageTag}'
param dbMigrateImage = 'ghcr.io/hivtools/hint-db-migrate:${env.hintImageTag}'
param hintrImage = 'ghcr.io/hivtools/hintr:${env.hintrImageTag}'
param hintrWorkerImage = 'ghcr.io/hivtools/hintr-worker:${env.hintrImageTag}'

param hintWebAppName = '${prefix}-naomi'
param applicationUrl = env.applicationUrl
param hintrName = '${prefix}-hintr'
param hintrCpu = env.hintrCpu
param hintrMemory = env.hintrMemory

