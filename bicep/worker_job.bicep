targetScope = 'resourceGroup'

// ------------------
//    PARAMETERS
// ------------------


@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('Name of existing container apps environment')
param containerAppsEnvironmentName string

@description('Workload profile for workers')
param workloadProfile string

@description('String for connecting to Azure managed redis')
param redisConnectionString string

@description('hostname for azure managed redis')
param redisHostname string

@description('Port Azure managed redis is running on')
param redisPort string

@description('Password for Azure managed redis')
@secure()
param redisPassword string

@description('Worker image name with registry and tag')
param hintrWorkerImage string

// ------------------
//    EXISTING RESOURCES
// ------------------

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: containerAppsEnvironmentName
}

// ------------------
// HINTR
// ------------------

@description('Name of uploads volume')
param uploadsVolume string = 'uploads-volume'
@description('Name of uploads mount')
param uploadsMount string = 'uploads-mount-r'

@description('Name of results volume')
param resultsVolume string = 'results-volume'
@description('Name of results mount')
param resultsMount string = 'uploads-mount-rw'

// ------------------
// HINTR workers
// ------------------

resource hintrWorker 'Microsoft.App/jobs@2024-03-01' = {
  name: 'nm-hintr-worker-job'
  location: location
  properties: {
    environmentId: containerAppsEnvironment.id
    template: {
      containers: [
        {
          name: 'hintr-worker-job'
          image: hintrWorkerImage
          command: [
            '/usr/local/bin/hintr_worker_single_job'
          ]
          args: [
            '--fit-only'
          ]
          env: [
            {
              name: 'REDIS_URL'
              value: redisConnectionString
            }
          ]
          resources: {
            cpu: json('4')
            memory: '8Gi'
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
      volumes: [
        {
          name: uploadsVolume
          storageType: 'AzureFile'
          storageName: uploadsMount
        }
        {
          name: resultsVolume
          storageType: 'AzureFile'
          storageName: resultsMount
        }
      ]
    }
    configuration: {
      triggerType: 'Event'
      secrets: [
        {
          name: 'redis-password'
          value: redisPassword
        }
      ]
      eventTriggerConfig: {
        parallelism: 10
        replicaCompletionCount: 1
        scale: {
          minExecutions: 0
          maxExecutions: 10
          pollingInterval: 5
          rules: [
            {
              name: 'job-queued-trigger'
              type: 'redis'
              metadata: {
                address: '${redisHostname}:${redisPort}'
                listName: '{hintr}:queue:run'
                listLength: '1'
              }
              auth: [
                {
                  secretRef: 'redis-password'
                  triggerParameter: 'password'
                }
              ]
            }
          ]
        }
      }
      replicaTimeout: 500
      replicaRetryLimit: 1
    }
    workloadProfileName: 'Consumption'
  }
}
