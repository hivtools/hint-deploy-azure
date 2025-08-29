@description('The prefix to use for all resource names')
param prefix string = 'nm'

@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('Name for the existing vnet')
param vnetName string

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vnetName
}

resource dbMigrateSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: '${prefix}-hint-db-migrate-subnet'
  parent: vnet
}

@description('Tag of the DB migrate docker image to use')
param dbMigrateImage string

@description('Tag of the DB migrate docker image to use')
param dbMigrateName string = '${prefix}-db-migrate'

@description('PostgreSQL server name')
param postgresServerName string

@description('PostgreSQL database name')
param databaseName string

@description('PostgreSQL database hostname')
var databaseHostname = '${postgresServerName}.postgres.database.azure.com'

resource hintDbMigration 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: dbMigrateName
  location: location
  properties: {
    containers: [
      {
        name: 'hint-db-migrate'
        properties: {
          image: dbMigrateImage
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
        id: dbMigrateSubnet.id
        name: '${prefix}-hint-db-migrate-subnet'
      }
    ]
    osType: 'Linux'
    restartPolicy: 'Never'
  }
}
