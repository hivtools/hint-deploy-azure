using '../../bicep/backup.bicep'

param prefix = 'nm'

param redisName = '${prefix}-hintr-queue'
param hintResourceGroup = 'nmHint-RG'
param storageAccountName = 'naomiappstorage'
param postgresServerName = 'nm-hint-db'
