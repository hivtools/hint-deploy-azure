using '../../bicep/app_environment.bicep'

param prefix = 'nm'
param vnetName = '${prefix}-hint-nw'

param fileShares = ['uploads', 'results', 'config']

param storageAccountName = 'naomiappstorage'
param logAnalyticsWorkspaceName = 'naomiLogs'
param logsResourceGroup = 'nmHint-logs-RG'
param containerAppsEnvironmentName = '${prefix}-hint-env'
param hintAppServicePlanName = '${prefix}-hint-SP'
