// ------------------
//    PARAMETERS
// ------------------

@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('The prefix to use for all resource names')
param prefix string = 'nm'

@secure()
@description('Slack incoming webhook URL that alerts are posted to')
param slackWebhookUrl string

@description('The name of the main hint resource group')
param hintResourceGroup string

@description('The name of the log analytics workspace, must be in the same resource group as the alerts')
param logAnalyticsWorkspaceName string

@description('Name of the redis service')
param redisName string

@description('Name of the postgres server')
param postgresServerName string

@description('Monthly budget in USD, a warning is sent when spend reaches this')
param budgetAmount int

@description('Spend in USD at which an early note is sent')
param budgetNoteAmount int

@description('First day of the month the budget starts from')
param budgetStartDate string

@description('Resource groups the budget covers')
param budgetResourceGroups array

@description('Public URL of the app, checked for availability')
param availabilityUrl string

// ------------------
//    EXISTING RESOURCES
// ------------------

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource redis 'Microsoft.Cache/redisEnterprise@2025-08-01-preview' existing = {
  name: redisName
  scope: resourceGroup(hintResourceGroup)
}

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2025-06-01-preview' existing = {
  name: postgresServerName
  scope: resourceGroup(hintResourceGroup)
}

// ------------------
// Slack notifications
// ------------------

module slackNotifier 'alerts/slack_notifier.bicep' = {
  name: 'slackNotifier'
  params: {
    location: location
    prefix: prefix
    slackWebhookUrl: slackWebhookUrl
  }
}

var actionGroupIds = {
  info: slackNotifier.outputs.infoActionGroupId
  critical: slackNotifier.outputs.criticalActionGroupId
}

@description('Sev0 and Sev1 alerts go to the critical action group, everything else to info')
func severityLevel(severity int) string => severity <= 1 ? 'critical' : 'info'

// ------------------
// Budget
// ------------------

module budget 'alerts/budget.bicep' = {
  name: 'budget'
  scope: subscription()
  params: {
    budgetName: '${prefix}-hint-budget'
    budgetAmount: budgetAmount
    noteAmount: budgetNoteAmount
    startDate: budgetStartDate
    resourceGroups: budgetResourceGroups
    noteActionGroupId: actionGroupIds.info
    warningActionGroupId: actionGroupIds.critical
  }
}

// ------------------
// Availability
// ------------------

module availability 'alerts/availability.bicep' = {
  name: 'availability'
  params: {
    location: location
    prefix: prefix
    url: availabilityUrl
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
    actionGroupId: actionGroupIds[severityLevel(0)]
  }
}

// ------------------
// Metric alerts
// ------------------

var metricAlerts = [
  {
    name: 'redis-memory-high'
    description: 'Redis memory is above 75%. Writes will fail when it is full.'
    action: 'Find what is filling Redis, e.g. old task results not being cleaned up. If the growth is expected, move to a bigger SKU in bicep/storage/redis.bicep.'
    severity: 2
    scope: redis.id
    namespace: 'Microsoft.Cache/redisEnterprise'
    metric: 'usedmemorypercentage'
    aggregation: 'Maximum'
    operator: 'GreaterThan'
    threshold: 75
  }
  {
    name: 'redis-memory-critical'
    description: 'Redis memory is above 90%. Writes will fail when it is full.'
    action: 'Urgent: when Redis is full no new model runs can be queued. Free up memory or move to a bigger SKU in bicep/storage/redis.bicep now.'
    severity: 0
    scope: redis.id
    namespace: 'Microsoft.Cache/redisEnterprise'
    metric: 'usedmemorypercentage'
    aggregation: 'Maximum'
    operator: 'GreaterThan'
    threshold: 90
  }
  {
    name: 'db-down'
    description: 'Postgres database is not responding.'
    action: 'Check nm-hint-db in the portal (status and Resource health) and restart it if it is stopped. Users cannot log in or load projects while it is down.'
    severity: 0
    scope: postgresServer.id
    namespace: 'Microsoft.DBforPostgreSQL/flexibleServers'
    metric: 'is_db_alive'
    aggregation: 'Minimum'
    operator: 'LessThan'
    threshold: 1
  }
  {
    name: 'db-storage-high'
    description: 'Postgres storage is above 80% full.'
    action: 'Increase storageSizeGB in bicep/storage/db.bicep and deploy. Storage can only be increased, never reduced.'
    severity: 2
    scope: postgresServer.id
    namespace: 'Microsoft.DBforPostgreSQL/flexibleServers'
    metric: 'storage_percent'
    aggregation: 'Maximum'
    operator: 'GreaterThan'
    threshold: 80
  }
  {
    // Burstable server, it gets throttled when it runs out of CPU credits
    name: 'db-cpu-credits-low'
    description: 'Postgres CPU credits are running low, the server will be throttled when they run out.'
    action: 'Check Query Performance Insight on nm-hint-db for what is using CPU. If the load is sustained, move off the Burstable SKU in bicep/storage/db.bicep.'
    severity: 2
    scope: postgresServer.id
    namespace: 'Microsoft.DBforPostgreSQL/flexibleServers'
    metric: 'cpu_credits_remaining'
    aggregation: 'Minimum'
    operator: 'LessThan'
    threshold: 50
  }
]

resource metricAlertRules 'Microsoft.Insights/metricAlerts@2018-03-01' = [for alert in metricAlerts: {
  name: '${prefix}-${alert.name}'
  location: 'global'
  properties: {
    description: '${alert.description}\nAction: ${alert.action}'
    severity: alert.severity
    enabled: true
    scopes: [
      alert.scope
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          name: alert.metric
          metricNamespace: alert.namespace
          metricName: alert.metric
          timeAggregation: alert.aggregation
          operator: alert.operator
          threshold: alert.threshold
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroupIds[severityLevel(alert.severity)]
      }
    ]
  }
}]

// ------------------
// Log alerts
// ------------------

// Used to look up the timeout for each worker job
var workerConfig = loadJsonContent('../config/workers.json')
var jobTimeouts = join(map(items(workerConfig.workers), worker => '"nm-hintr-${worker.key}-job", ${worker.value.deployment_options.timeout}'), ', ')

// Thresholds are based on the ContainerAppSystemLogs from Sep 2026.
// Columns in dimensions are included in the alert, and each distinct value
// fires as a separate alert.
var logAlerts = [
  {
    // The active jobs function app is how KEDA knows to start workers, if it
    // is failing no model runs will start. There are a few timeouts a day
    // normally, an outage gives ~30 failures per 30 mins.
    name: 'worker-scaler-failing'
    description: 'KEDA cannot reach the active jobs function app, workers will not be started.'
    action: 'Check the nm-active-jobs function app is running, getActiveJobs is not disabled (app setting AzureWebJobs.getActiveJobs.Disabled) and its App Insights failures. Model runs queue but never start until this is fixed.'
    severity: 0
    query: 'ContainerAppSystemLogs | where Reason == "KEDAScalerFailed"'
    window: 'PT30M'
    frequency: 'PT5M'
    threshold: 15
  }
  {
    // Normal usage is <90 executions per hour, runaway job creation was ~1500
    // per hour and kept the dedicated workload profiles running.
    name: 'worker-executions-runaway'
    description: 'More than 300 worker job executions created in the last hour. Workers may be starting with no work to do, keeping dedicated nodes running and running up cost.'
    action: 'Check getActiveJobs returns the real number of queued and running tasks for each queue. Stale tasks in Redis keep starting workers. To stop the spend straight away disable getActiveJobs, but no model runs will start until it is re-enabled.'
    severity: 1
    query: 'ContainerAppSystemLogs | where Reason == "SuccessfulCreate" and isnotempty(JobName)'
    window: 'PT1H'
    frequency: 'PT15M'
    threshold: 300
  }
  {
    name: 'worker-waiting-for-node'
    description: 'A worker has been waiting more than 10 minutes for a node, the model run is queued and the user is waiting.'
    action: 'Check how many nodes the job\'s workload profile is running against its maximumCount in config/workers.json. If it is at the maximum because of genuine load, raise maximumCount. If nodes are busy with workers that have no work, see the runaway executions alert.'
    severity: 1
    query: loadTextContent('alerts/queries/worker_waiting_for_node.kql')
    window: 'PT1H'
    frequency: 'PT5M'
    threshold: 1
    dimensions: ['JobName']
  }
  {
    name: 'worker-job-timeout'
    description: 'A worker job ran longer than its replica timeout and was killed. TaskId is the hintr task it was running.'
    action: 'Look up the task to find the country, and let the user know their run was stopped. If the fit genuinely needs longer, raise the queue\'s timeout or move the country to a bigger queue in config/workers.json.'
    severity: 2
    query: replace(loadTextContent('alerts/queries/worker_job_timeout.kql'), '{{JOB_TIMEOUTS}}', jobTimeouts)
    window: 'PT15M'
    frequency: 'PT5M'
    threshold: 1
    dimensions: ['JobName', 'TaskId']
    // Look back far enough to find when the task started on the longest running worker
    queryTimeRange: 'PT3H'
    // A timeout is a one-off event, there is nothing to resolve
    notifyResolved: false
  }
]

resource logAlertRules 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = [for alert in logAlerts: {
  name: '${prefix}-${alert.name}'
  location: location
  kind: 'LogAlert'
  properties: {
    description: '${alert.description}\nAction: ${alert.action}'
    severity: alert.severity
    enabled: true
    scopes: [
      logAnalyticsWorkspace.id
    ]
    evaluationFrequency: alert.frequency
    windowSize: alert.window
    overrideQueryTimeRange: alert.?queryTimeRange
    criteria: {
      allOf: [
        {
          query: alert.query
          timeAggregation: 'Count'
          operator: 'GreaterThanOrEqual'
          threshold: alert.threshold
          dimensions: [for dimension in alert.?dimensions ?? []: {
            name: dimension
            operator: 'Include'
            values: ['*']
          }]
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    actions: {
      actionGroups: [
        actionGroupIds[severityLevel(alert.severity)]
      ]
    }
  }
}]

// Alerts stay stateful so an event is only notified once while it is in the
// alert window, but don't send "Resolved" for one-off events like a timeout
var eventAlertNames = map(filter(logAlerts, alert => !(alert.?notifyResolved ?? true)), alert => '${prefix}-${alert.name}')

resource suppressResolvedEvents 'Microsoft.AlertsManagement/actionRules@2021-08-08' = {
  name: '${prefix}-suppress-resolved-events'
  location: 'global'
  properties: {
    description: 'Do not notify when one-off event alerts (e.g. a job timing out) resolve'
    enabled: true
    scopes: [
      resourceGroup().id
    ]
    conditions: [
      {
        field: 'AlertRuleName'
        operator: 'Equals'
        values: eventAlertNames
      }
      {
        field: 'MonitorCondition'
        operator: 'Equals'
        values: ['Resolved']
      }
    ]
    actions: [
      {
        actionType: 'RemoveAllActionGroups'
      }
    ]
  }
  dependsOn: [
    logAlertRules
  ]
}
