using 'bicep/hint.bicep'

param avenirAccessToken = readEnvironmentVariable('AVENIR_ACCESS_TOKEN')

param location = 'eastus'

param containerAppsEnvironmentName = 'hint-env'
param logAnalyticsWorkspaceName = 'hint-log-workspace'

param storageAccountName = 'hintappstorage'
param uploadsShareName = 'uploads-share'
param resultsShareName = 'results-share'
param configShareName = 'config-share'
param uploadsMountName = 'uploads-mount'
param resultsMountName = 'results-mount'
param configMountName = 'config-mount'
param uploadsVolume = 'uploads-volume'
param resultsVolume = 'results-volume'
param configVolume = 'config-volume'

param azureCRUrl = readEnvironmentVariable('AZURE_HINT_CR_SERVER')
param azureCRUsername = readEnvironmentVariable('AZURE_HINT_CR_USERNAME')
param azureCRPassword = readEnvironmentVariable('AZURE_HINT_CR_PASSWORD')

param postgresServerName = 'nm-hint-db'
param adminDbUsername = 'hintuser'
param adminDbPassword = 'changeme'
param databaseName = 'hint'

param hintWebAppName = 'nm-hint'

