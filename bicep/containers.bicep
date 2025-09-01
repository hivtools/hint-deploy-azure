// ------------------
//    PARAMETERS
// ------------------

@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('The prefix to use for all resource names')
param prefix string = 'nm'

@description('Worker config to use')
param workerConfigString string = loadTextContent('../config/workers.json')

@description('The name of the existing container app environment.')
param containerAppsEnvironmentName string

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: containerAppsEnvironmentName
}

@description('Name of the redis service')
param redisName string

@description('Name of the redis database')
param redisDbName string

@description('Name of redis private DNS zone')
param redisPrivateDnsZoneName string

resource redis 'Microsoft.Cache/redisEnterprise@2025-05-01-preview' existing = {
  name: redisName
}

resource redisDb 'Microsoft.Cache/redisEnterprise/databases@2025-05-01-preview' existing = {
  name: redisDbName
  parent: redis
}

var redisInfo object = {
  redisName: redisName
  hostname: '${redisName}.${redisPrivateDnsZoneName}'
  port: '10000'
  connectionString: 'redis://:${redisDb.listKeys().primaryKey}@${redisName}.${redisPrivateDnsZoneName}:10000'
  connectionStringNoProtocol: '${redisName}.${redisPrivateDnsZoneName}:10000'
  redisKey: redisDb.listKeys().primaryKey
}

// ------------------
// App config
// ------------------

// module appConfigModule 'app_configuration.bicep' = {
//   name: 'app-config-module'
// }

// var configInfo = appConfigModule.outputs.configInfo

// ------------------
// Migrate DB
// ------------------

@description('Tag of the DB migrate docker image to use')
param dbMigrateImage string


module migradeDbModule 'app/migrate_db.bicep' = {
  name: 'migrateDb'
  params: {
    location: location
    vnetName: vnetName
    dbMigrateImage: dbMigrateImage
    databaseName: databaseName
    postgresServerName: postgresServerName
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

resource hintr 'Microsoft.App/containerApps@2024-03-01' = {
  name: hintrName
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8888
        allowInsecure: true
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
              value: redisInfo.connectionString
            }
            {
              name: 'HINTR_WORKER_CONFIG'
              value: workerConfigString
            }
          ]
          resources: {
            cpu: json('1')
            memory: '2Gi'
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
        minReplicas: 0
        maxReplicas: 2
      }
      volumes: [
        {
          name: uploadsVolume
          storageType: 'AzureFile'
          storageName: 'uploads-mount-r'
        }
        {
          name: resultsVolume
          storageType: 'AzureFile'
          storageName: 'results-mount-rw'
        }
      ]
    }
    workloadProfileName: 'Consumption'
  }
}

// ------------------
// HINTR workers
// ------------------

@description('hintr worker docker image to use')
param hintrWorkerImage string

module workerJobModule 'app/worker_job.bicep' = {
  name: 'workerJob'
  params: {
    location: location
    containerAppsEnvironmentName: containerAppsEnvironmentName
    hintrWorkerImage: hintrWorkerImage
    redisConnectionString: redisInfo.connectionString
    redisConnectionStringNoProtocol: redisInfo.connectionStringNoProtocol
    redisKey: redisInfo.redisKey
    resultsVolume: resultsVolume
    resultsMount: 'results-mount-rw'
    uploadsVolume: uploadsVolume
    uploadsMount: 'uploads-mount-r'
    workerConfigString: workerConfigString
  }
}

// ------------------
// Hint web app
// ------------------

@secure()
@description('Avenir access token used to pull env vars from the auth server')
param avenirAccessToken string

@description('hint docker image to use')
param hintImage string

@description('hint web app name')
param hintWebAppName string = 'nm-hint'

@description('Storage account name')
param storageAccountName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

@description('hint web app service plan name')
param hintAppServicePlanName string

@description('Name for the existing vnet')
param vnetName string

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' existing = {
  name: hintAppServicePlanName
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vnetName
}

resource hintSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: '${prefix}-hint-subnet'
  parent: vnet
}

@description('Name of the postgres database for hint')
param databaseName string

@description('Name of the postgres server')
param postgresServerName string

resource hintWebApp 'Microsoft.Web/sites@2024-04-01' = {
  name: hintWebAppName
  location: location
  kind: 'app,linux,container'
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: hintSubnet.id
    siteConfig: {
      appSettings: [
        {
          name: 'AVENIR_ACCESS_TOKEN'
          value: avenirAccessToken
        }
        {
          name: 'APPLICATION_URL'
          value: 'https://${hintWebAppName}.azurewebsites.net'
        }
        {
          name: 'HINTR_URL'
          value: 'http://${hintr.properties.configuration.ingress.fqdn}'
        }
        {
          name: 'DB_URL'
          value: 'jdbc:postgresql://${postgresServerName}.postgres.database.azure.com/${databaseName}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://ghcr.io'
        }
        {
          name: 'WEBSITES_PORT'
          value: '8080'
        }
      ]
      linuxFxVersion: 'DOCKER|${hintImage}'
      appCommandLine: '--azure'
      azureStorageAccounts: {
        uploadsMount: {
          type: 'AzureFiles'
          accountName: storageAccountName
          accessKey: storageAccount.listKeys().keys[0].value
          mountPath: '/uploads'
          shareName: 'uploads-share'
        }
        resultsMount: {
          type: 'AzureFiles'
          accountName: storageAccountName
          accessKey: storageAccount.listKeys().keys[0].value
          mountPath: '/results'
          shareName: 'results-share'
        }
        configMount: {
          type: 'AzureFiles'
          accountName: storageAccountName
          accessKey: storageAccount.listKeys().keys[0].value
          mountPath: '/etc/hint'
          shareName: 'config-share'
        }
      }
    }
  }
}

@description('The name of the log analytics workspace. If set, it overrides the name generated by the template.')
param logAnalyticsWorkspaceName string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource diagnosticLogsWA 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: hintWebApp.name
  scope: hintWebApp
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
