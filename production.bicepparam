using 'bicep/hint.bicep'

param avenirAccessToken = readEnvironmentVariable('AVENIR_ACCESS_TOKEN')

param location = 'eastus'
param storageAccountName = 'hintappstorage'

param azureCRUrl = readEnvironmentVariable('AZURE_HINT_CR_SERVER')
param azureCRUsername = readEnvironmentVariable('AZURE_HINT_CR_USERNAME')
param azureCRPassword = readEnvironmentVariable('AZURE_HINT_CR_PASSWORD')

param adminDbPassword = readEnvironmentVariable('AVENIR_NM_DB_PASSWORD')

param hintImage = 'ghcr.io/mrc-ide/hint:azure-entrypoint'
param dbMigrateImage = hintImage
param hintrImage = 'ghcr.io/mrc-ide/hintr:add-health-check'
param hintrWorkerImage = 'ghcr.io/mrc-ide/hintr-worker:add-health-check'
param redisImage = 'nmhintcr.azurecr.io/redis:5.0'

param hintWebAppName = 'nm-hint'
param dbMigrateName = 'nm-db-migrate'
param hintrName = 'nm-hintr'
param hintrWorkerName = 'nm-hintr-worker'
param redisName = 'nm-redis'
