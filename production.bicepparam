using 'bicep/hint.bicep'

param avenirAccessToken = readEnvironmentVariable('AVENIR_ACCESS_TOKEN')

param location = 'eastus'
param storageAccountName = 'hintappstorage'

param azureCRUrl = readEnvironmentVariable('AZURE_HINT_CR_SERVER')
param azureCRUsername = readEnvironmentVariable('AZURE_HINT_CR_USERNAME')
param azureCRPassword = readEnvironmentVariable('AZURE_HINT_CR_PASSWORD')

param adminDbPassword = readEnvironmentVariable('AVENIR_NM_DB_PASSWORD')

