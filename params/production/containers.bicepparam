using '../../bicep/containers.bicep'

param avenirAccessToken = readEnvironmentVariable('AVENIR_ACCESS_TOKEN')

param prefix = 'nm'
param vnetName = '${prefix}-hint-nw'

param storageAccountName = 'hintappstoragepremium'
param logAnalyticsWorkspaceName = 'logAnalyticsWorkspaceName'
param containerAppsEnvironmentName = '${prefix}-hint-env'
param hintAppServicePlanName = '${prefix}-hint-SP'

param databaseName = 'hint'
param postgresServerName = '${prefix}-hint-db'
param redisName = '${prefix}-hintr-queue'
param redisDbName = 'default'
param redisPrivateDnsZoneName = 'privatelink.eastus.redis.azure.net'

param hintImage = 'ghcr.io/hivtools/hint:nm-115'
param hintrImage = 'ghcr.io/hivtools/hintr:nm-115'
param hintrWorkerImage = 'ghcr.io/hivtools/hintr-worker:nm-115'
param proxyImage = 'ghcr.io/hivtools/hint-proxy-azure:main'
param dbMigrateImage = 'ghcr.io/hivtools/hint-db-migrate:update-postgres'

param hintWebAppName = '${prefix}-hint'
param hintrName = '${prefix}-hintr'

