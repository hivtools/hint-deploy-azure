using '../../bicep/app_environment.bicep'

param prefix = 'nm'
param vnetName = '${prefix}-hint-nw'

param fileShares = ['uploads', 'results', 'config']

param storageAccountName = 'hintappstoragepremium'
param logAnalyticsWorkspaceName = 'logAnalyticsWorkspaceName'
param containerAppsEnvironmentName = '${prefix}-hint-env'
param hintAppServicePlanName = '${prefix}-hint-SP'
