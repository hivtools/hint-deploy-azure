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

@description('Name of existing redis container app')
param redisName string

@description('Worker image name with registry and tag')
param hintrWorkerImage string

// ------------------
//    EXISTING RESOURCES
// ------------------

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: containerAppsEnvironmentName
}

resource redis 'Microsoft.App/containerApps@2024-03-01' existing = {
  name: redisName
}

// ------------------
// HINTR
// ------------------

@description('Name of uploads volume')
param uploadsVolume string = 'uploads-volume'

@description('Name of results volume')
param resultsVolume string = 'results-volume'


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
              value: 'redis://nm-redis:6379'
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
          storageName: 'uploads-mount'
        }
        {
          name: resultsVolume
          storageType: 'AzureFile'
          storageName: 'results-mount'
        }
      ]
    }
    configuration: {
      triggerType: 'Event'
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
                address: 'nm-redis:${redis.properties.configuration.ingress.targetPort}'
                listName: 'hintr:queue:run'
                listLength: '1'
              }
            }
          ]
        }
      }
      replicaTimeout: 500
      replicaRetryLimit: 1
    }
    workloadProfileName: 'consumption'
  }
}
