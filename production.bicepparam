using 'bicep/hint.bicep'

param avenirAccessToken = readEnvironmentVariable('AVENIR_ACCESS_TOKEN')

param location = 'eastus'
param storageAccountName = 'hintappstoragepremium'

param containerAppsEnvironmentName = 'hint-env'
param hintWorkloadProfileName = 'hint-profile'
param workerWorkloadProfileName = 'worker-profile'

param azureCRUrl = readEnvironmentVariable('AZURE_HINT_CR_SERVER')
param azureCRUsername = readEnvironmentVariable('AZURE_HINT_CR_USERNAME')
param azureCRPassword = readEnvironmentVariable('AZURE_HINT_CR_PASSWORD')
param adminDbPassword = readEnvironmentVariable('AVENIR_NM_DB_PASSWORD')

param hintImage = 'ghcr.io/hivtools/hint:azure-wa'
param dbMigrateImage = 'ghcr.io/hivtools/hint-db-migrate:latest'
param hintrImage = 'ghcr.io/hivtools/hintr:main'
param hintrWorkerImage = 'ghcr.io/hivtools/hintr-worker:main'
param redisImage = 'nmhintcr.azurecr.io/redis:5.0'
param proxyImage = 'ghcr.io/hivtools/hint-proxy-azure:main'

param hintWebAppName = 'nm-hint'
param dbMigrateName = 'nm-db-migrate'
param hintrName = 'nm-hintr'
param hintrWorkerName = 'nm-hintr-worker'
param redisName = 'nm-redis'
