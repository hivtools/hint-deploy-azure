targetScope = 'resourceGroup'

// ------------------
//    PARAMETERS
// ------------------

@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('The prefix to use for all resource names')
param prefix string = 'nm'

// ------------------
// Network
// ------------------

param vnetSettings object = {
  name: '${prefix}-hint-nw'
  location: location
  addressPrefixes: [
    {
      name: '${prefix}-hint-nw'
      addressPrefix: '10.0.0.0/16'
    }
  ]
  subnets: [
    {
      name: '${prefix}-hint-subnet'
      addressPrefix: '10.0.1.0/24'
      service: 'Microsoft.Web/serverFarms'
      public: true
    }
    {
      name: '${prefix}-hint-db-migrate-subnet'
      addressPrefix: '10.0.2.0/24'
      service: 'Microsoft.ContainerInstance/containerGroups'
      public: false
    }
    {
      name: '${prefix}-hint-db-subnet'
      addressPrefix: '10.0.3.0/24'
      service: 'Microsoft.DBforPostgreSQL/flexibleServers'
      public: false
    }
    {
      name: '${prefix}-hintr-subnet'
      addressPrefix: '10.0.4.0/24'
      service: 'Microsoft.App/environments'
      public: true
    }
  ]
}

module vnetModule './network.bicep' = {
  name: 'vnetDeploy'
  params: {
    vnetSettings: vnetSettings
  }
}

var vnetInfo = vnetModule.outputs.vnetInfo

// ------------------
// Private DNS
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
  dependsOn: [vnetModule]
}

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${prefix}-hint-nw-link'
  parent: dnszone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetInfo.vnet.id
    }
  }
}

// ------------------
// CONTAINER APP ENVIRONMENT
// ------------------

@description('The name of the container apps environment. If set, it overrides the name generated by the template.')
param containerAppsEnvironmentName string = 'hint-env'

@description('The name of the log analytics workspace. If set, it overrides the name generated by the template.')
param logAnalyticsWorkspaceName string = 'hint-log-workspace'

@description('The name of the high memory workload profile for running models')
param highMemoryWorkloadProfileName string = 'worker-profile'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: any({
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  })
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppsEnvironmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
      {
        minimumCount: 1
        maximumCount: 2
        name: highMemoryWorkloadProfileName
        workloadProfileType: 'E4'
      }
    ]
    vnetConfiguration: {
      infrastructureSubnetId: vnetInfo.subnets['${prefix}-hintr-subnet'].id
      internal: false
    }
  }
}

resource record 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: dnszone
  name: '*'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: containerAppsEnvironment.properties.staticIp
      }
    ]
  }
}

// ------------------
// STORAGE
// ------------------

@description('The name of the external Azure Storage Account.')
param storageAccountName string

param storageSettings object = {
  storageAccountName: storageAccountName
  location: location
  containerAppEnvironmentName: containerAppsEnvironmentName
  fileShares: {
    uploads: {
      name: 'uploads'
      mountAccessMode: 'ReadWrite'
    }
    results: {
      name: 'results'
      mountAccessMode: 'ReadWrite'
    }
    config: {
      name: 'config'
      mountAccessMode: 'ReadWrite'
    }
    redis: {
      name: 'redis'
      mountAccessMode: 'ReadWrite'
    }
  }
}

module storageModule './storage.bicep' = {
  name: 'storageDeploy'
  params: {
    storageSettings: storageSettings
  }
}

// ------------------
// REDIS
// ------------------

@description('Docker container registry URL')
param azureCRUrl string

@description('Docker container registry username')
param azureCRUsername string

@secure()
@description('Azure Registry password')
param azureCRPassword string

@description('redis container app name')
param redisName string

@description('Name of redis volume')
param redisVolume string = 'redis-volume'

@description('Redis docker image to use')
param redisImage string

resource redis 'Microsoft.App/containerApps@2024-03-01' = {
  name: redisName
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: false
        targetPort: 6379
        allowInsecure: false
        transport: 'tcp'
      }
      secrets: [
        {
          name: 'registry-password'
          value: azureCRPassword
        }
      ]
      registries: [
        {
          passwordSecretRef: 'registry-password'
          server: azureCRUrl
          username: azureCRUsername
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'redis'
          image: redisImage
          command: [
            'redis-server'
          ]
          args: [
            '--appendonly'
            'yes'
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          volumeMounts: [
            {
              volumeName: redisVolume
              mountPath: '/data'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: [
        {
          name: redisVolume
          storageType: 'AzureFile'
          storageName: storageModule.outputs.storageInfo.redis.mountName
        }
      ]
    }
    workloadProfileName: 'Consumption'
  }
}

// ------------------
// HINTR
// ------------------

@description('hintr container app name')
param hintrName string

@description('hintr docker image to use')
param hintrImage string

@description('Name of uploads volume')
param uploadsVolume string = 'uploads-volume'

@description('Name of results volume')
param resultsVolume string = 'results-volume'

@description('Name of config volume')
param configVolume string = 'config-volume'

resource hintr 'Microsoft.App/containerApps@2024-03-01' = {
  name: hintrName
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8888
        allowInsecure: false
      }
    }
    template: {
      containers: [
        {
          name: 'hintr'
          image: hintrImage
          command: [
            '/usr/local/bin/hintr_api'
          ]
          args: [
            '--workers'
            '0'
            '--results-dir'
            '/results'
            '--inputs-dir'
            '/uploads'
            '--port'
            '8888'
            '--health-check-interval'
            // Azure closes idle tcp connection after 4 mins, so make interval
            // slighty less than this
            '210'
          ]
          env: [
            {
              name: 'REDIS_URL'
              value: 'redis://nm-redis:6379'
            }
          ]
          resources: {
            cpu: json('1')
            memory: '4Gi'
          }
          volumeMounts: [
            {
              volumeName: uploadsVolume
              mountPath: '/uploads'
            }
            {
              volumeName: resultsVolume
              mountPath: '/results'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
      }
      volumes: [
        {
          name: uploadsVolume
          storageType: 'AzureFile'
          storageName: storageModule.outputs.storageInfo.uploads.mountName
        }
        {
          name: resultsVolume
          storageType: 'AzureFile'
          storageName: storageModule.outputs.storageInfo.results.mountName
        }
      ]
    }
    workloadProfileName: highMemoryWorkloadProfileName
  }
}

// ------------------
// HINTR workers
// ------------------

@description('hintr worker container app name')
param hintrWorkerName string

@description('hintr worker docker image to use')
param hintrWorkerImage string

resource hintrWorker 'Microsoft.App/containerApps@2024-03-01' = {
  name: hintrWorkerName
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    template: {
      containers: [
        {
          name: 'hintr-worker'
          image: hintrWorkerImage
          env: [
            {
              name: 'REDIS_URL'
              value: 'redis://nm-redis:6379'
            }
          ]
          resources: {
            cpu: json('1')
            memory: '16Gi'
          }
          volumeMounts: [
            {
              volumeName: uploadsVolume
              mountPath: '/uploads'
            }
            {
              volumeName: resultsVolume
              mountPath: '/results'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
      volumes: [
        {
          name: uploadsVolume
          storageType: 'AzureFile'
          storageName: storageModule.outputs.storageInfo.uploads.mountName
        }
        {
          name: resultsVolume
          storageType: 'AzureFile'
          storageName: storageModule.outputs.storageInfo.results.mountName
        }
      ]
    }
    workloadProfileName: highMemoryWorkloadProfileName
  }
  dependsOn: [
    hintr
  ]
}

// ------------------
// Database
// ------------------

@description('PostgreSQL server name')
param postgresServerName string = 'nm-hint-db'

@description('PostgreSQL administrator username')
param adminDbUsername string = 'hint'

@secure()
@description('PostgreSQL administrator password')
param adminDbPassword string

@description('PostgreSQL database name')
param databaseName string = 'hint'

@description('PostgreSQL database hostname')
var databaseHostname = '${postgresServerName}.postgres.database.azure.com'

@description('Tag of the DB migrate docker image to use')
param dbMigrateName string

@description('Tag of the DB migrate docker image to use')
param dbMigrateImage string

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
  name: postgresServerName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '11'
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
  dependsOn: [vnetModule]
}

resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  parent: postgresServer
  name: databaseName
}

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
        id: vnetInfo.subnets['${prefix}-hint-db-migrate-subnet'].id
        name: '${prefix}-hint-db-migrate-subnet'
      }
    ]
    osType: 'Linux'
    restartPolicy: 'Never'
  }
  dependsOn: [postgresDatabase]
}

// ------------------
// Hint web app
// ------------------

@description('hint web app name')
param hintWebAppName string

@secure()
@description('Avenir access token used to pull env vars from the auth server')
param avenirAccessToken string

@description('hint docker image to use')
param hintImage string

resource hint 'Microsoft.App/containerApps@2024-03-01' = {
  name: hintWebAppName
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: false
      }
      secrets: [
        {
          name: 'avenir-access-token'
          value: avenirAccessToken
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'hint'
          image: hintImage
          command: [
            '/entrypoint_azure'
          ]
          env: [
            {
              name: 'AVENIR_ACCESS_TOKEN'
              secretRef: 'avenir-access-token'
            }
            {
              name: 'APPLICATION_URL'
              value: 'https://${hintWebAppName}.${containerAppsEnvironment.properties.defaultDomain}'
            }
            {
              name: 'HINTR_URL'
              value: 'http://nm-hintr'
            }
            {
              name: 'DB_URL'
              value: 'jdbc:postgresql://${databaseHostname}/${databaseName}'
            }
          ]
          resources: {
            cpu: json('1')
            memory: '4Gi'
          }
          volumeMounts: [
            {
              volumeName: uploadsVolume
              mountPath: '/uploads'
            }
            {
              volumeName: resultsVolume
              mountPath: '/results'
            }
            {
              volumeName: configVolume
              mountPath: '/etc/hint'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      volumes: [
        {
          name: uploadsVolume
          storageType: 'AzureFile'
          storageName: storageModule.outputs.storageInfo.uploads.mountName
        }
        {
          name: resultsVolume
          storageType: 'AzureFile'
          storageName: storageModule.outputs.storageInfo.results.mountName
        }
        {
          name: configVolume
          storageType: 'AzureFile'
          storageName: storageModule.outputs.storageInfo.config.mountName
        }
      ]
    }
    workloadProfileName: highMemoryWorkloadProfileName
  }
  dependsOn: [
    hintDbMigration
  ]
}
