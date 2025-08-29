@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('The prefix to use for all resource names')
param prefix string = 'nm'

@description('PostgreSQL server name')
param postgresServerName string = '${prefix}-hint-db'

@description('PostgreSQL administrator username')
param adminDbUsername string = 'hintuser'

@secure()
@description('PostgreSQL administrator password')
param adminDbPassword string

@description('PostgreSQL database name')
param databaseName string

@description('Name of the existing vnet resource')
param vnetName string

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vnetName
}

// ------------------
// Private DNS for postgres database
// ------------------

@description('DNS Zone name')
param dnsZoneName string = 'hint-private-dns'

@description('Fully Qualified DNS Private Zone')
param dnsZoneFqdn string = '${dnsZoneName}.postgres.database.azure.com'

@description('Postgres private DNS subnet ID')
var postgresqlSubnetId = '${vnetLink.properties.virtualNetwork.id}/subnets/${prefix}-hint-db-subnet'

resource dnszone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dnsZoneFqdn
  location: 'global'
  dependsOn: [vnet]
}

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${prefix}-hint-nw-link'
  parent: dnszone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2025-06-01-preview' = {
  name: postgresServerName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '17'
    administratorLogin: adminDbUsername
    administratorLoginPassword: adminDbPassword
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    network: {
      delegatedSubnetResourceId: postgresqlSubnetId
      privateDnsZoneArmResourceId: dnszone.id
      publicNetworkAccess: 'Disabled'
    }
  }
}

resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  parent: postgresServer
  name: databaseName
}

output dbInfo object = {
  serverName: postgresServerName
  hostname: '${postgresServerName}.postgres.database.azure.com'
  databaseName: databaseName
}
