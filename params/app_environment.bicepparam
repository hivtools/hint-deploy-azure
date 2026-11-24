using '../bicep/app_environment.bicep'

var deploy_environment = readEnvironmentVariable('HINT_ENV', 'staging')
var env = loadJsonContent('../config/environments.json')[deploy_environment]
param prefix = env.prefix
param vnetName = '${prefix}-hint-nw'

param fileShares = ['uploads', 'results', 'config']

param storageAccountName = env.storageAccountName
param logAnalyticsWorkspaceName = 'naomiLogs'
param logsResourceGroup = 'nmHint-logs-RG'
param containerAppsEnvironmentName = '${prefix}-hint-env'
param hintAppServicePlanName = '${prefix}-hint-SP'
param hintAppServicePlanSku = env.hintAppServicePlanSku
