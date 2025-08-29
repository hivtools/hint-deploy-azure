// ------------------
//    PARAMETERS
// ------------------

@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('The prefix to use for all resource names')
param prefix string = 'nm'

@description('The name of the external Azure Storage Account.')
param storageAccountName string

@description('Name of the existing vnet resource')
param vnetName string

@description('File shares to create')
param fileShares array

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vnetName
}

resource gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: '${prefix}-gateway-subnet'
  parent: vnet
}

// ------------------
// File shares
// ------------------

param storageSettings object = {
  storageAccountName: storageAccountName
  location: location
  fileShares: fileShares
}

module storageModule 'storage/file_shares.bicep' = {
  name: 'storageDeploy'
  params: {
    storageSettings: storageSettings
  }
}

// ------------------
// REDIS
// ------------------

@description('Name of the redis service')
param redisName string

@description('Name of the redis database')
param redisDbName string

@description('Name of redis private DNS zone')
param redisPrivateDnsZoneName string

module redisModule 'storage/redis.bicep' = {
  name: 'redis-module'
  params: {
    privateEndpointSubnet: gatewaySubnet.id
    vnetName: vnetName
    redisName: redisName
    redisDbName: redisDbName
    redisPrivateDnsZoneName: redisPrivateDnsZoneName
  }
}

// ------------------
// Database
// ------------------

@secure()
@description('PostgreSQL administrator password')
param adminDbPassword string

@description('Name for the hint postgres database')
param databaseName string

module dbModule 'storage/db.bicep' = {
  name: 'dbDeploy'
  params: {
    prefix: prefix
    adminDbPassword: adminDbPassword
    vnetName: vnetName
    databaseName: databaseName
  }
}

output storageInfo object = {
  db: dbModule.outputs.dbInfo
  redis: redisModule.outputs.redisInfo
  shares: storageModule.outputs.storageInfo
}
