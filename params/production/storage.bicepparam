using '../../bicep/storage.bicep'

param location = 'eastus'
param prefix = 'nm'
param vnetName = '${prefix}-hint-nw'

param storageAccountName = 'hintappstoragepremium'

param adminDbPassword = readEnvironmentVariable('AVENIR_NM_DB_PASSWORD')
param databaseName = 'hint'

param fileShares = ['uploads', 'results', 'config']

param redisName = '${prefix}-hintr-queue'
param redisDbName = 'default'
param redisPrivateDnsZoneName = 'privatelink.eastus.redis.azure.net'
