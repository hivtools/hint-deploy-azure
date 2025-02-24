@description('DB settings object')
param dbSettings object

@description('PostgreSQL server name')
param postgresServerName string = '${dbSettings.prefix}-hint-db'

@description('PostgreSQL administrator username')
param adminDbUsername string = 'hint'

@description('PostgreSQL database name')
param databaseName string = 'hint'

@description('PostgreSQL database hostname')
var databaseHostname = '${postgresServerName}.postgres.database.azure.com'

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
  name: postgresServerName
  location: dbSettings.location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '11'
    administratorLogin: adminDbUsername
    administratorLoginPassword: dbSettings.adminDbPassword
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    network: {
      delegatedSubnetResourceId: dbSettings.postgresSubnetResourceId
      privateDnsZoneArmResourceId: dbSettings.dnsZoneId
      publicNetworkAccess: 'Disabled'
    }
  }
}

resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  parent: postgresServer
  name: databaseName
}

resource hintDbMigration 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: dbSettings.dbMigrateName
  location: dbSettings.location
  properties: {
    containers: [
      {
        name: 'hint-db-migrate'
        properties: {
          image: dbSettings.dbMigrateImage
          command: [
            'flyway'
            'migrate'
            '-url=jdbc:postgresql://${databaseHostname}/${databaseName}'
          ]
          resources: {
            requests: {
              cpu: json('0.5')
              memoryInGB: json('1.0')
            }
          }
        }
      }
    ]
    subnetIds: [
      {
        id: dbSettings.dbMigrateSubnetId
        name: '${dbSettings.prefix}-hint-db-migrate-subnet'
      }
    ]
    osType: 'Linux'
    restartPolicy: 'Never'
  }
  dependsOn: [postgresDatabase]
}

output dbInfo object = {
  serverName: postgresServerName
  hostname: '${postgresServerName}.postgres.database.azure.com'
  databaseName: databaseName
}
