using '../../bicep/containers.bicep'

param avenirAccessToken = readEnvironmentVariable('AVENIR_ACCESS_TOKEN')

param prefix = 'nm'
param vnetName = '${prefix}-hint-nw'

param storageAccountName = 'naomiappstorage'
param logAnalyticsWorkspaceName = 'naomiLogs'
param logsResourceGroup = 'nmHint-logs-RG'
param containerAppsEnvironmentName = '${prefix}-hint-env'
param hintAppServicePlanName = '${prefix}-hint-SP'

param databaseName = 'hint'
param postgresServerName = '${prefix}-hint-db'
param redisName = '${prefix}-hintr-queue'
param redisDbName = 'default'
param redisPrivateDnsZoneName = 'privatelink.eastus2.redis.azure.net'

param hintImage = 'ghcr.io/hivtools/hint:main'
param hintrImage = 'ghcr.io/hivtools/hintr:main'
param hintrWorkerImage = 'ghcr.io/hivtools/hintr-worker:main'
param dbMigrateImage = 'ghcr.io/hivtools/hint-db-migrate:update-postgres'

param hintWebAppName = '${prefix}-naomi'
param hintrName = '${prefix}-hintr'

