@description('The location where the resources will be created.')
param location string = resourceGroup().location

@description('The prefix to use for all resource names')
param prefix string

@secure()
@description('Slack incoming webhook URL that alerts are posted to')
param slackWebhookUrl string

var workflowSchema = 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'

// Action groups call the logic app with ?level=info or ?level=critical so we can
// format the message differently. Budget alerts don't use the common alert schema
// so they need their own message.
var budgetMessage = '''@{if(equals(triggerOutputs()?['queries']?['level'], 'critical'), ':rotating_light: *Over budget*', ':information_source: *Spend note*')}: @{triggerBody()?['data']?['BudgetName']} spend this month is @{triggerBody()?['data']?['SpendingAmount']} @{triggerBody()?['data']?['Unit']}, passing the @{triggerBody()?['data']?['NotificationThresholdAmount']} @{triggerBody()?['data']?['Unit']} threshold of the @{triggerBody()?['data']?['Budget']} @{triggerBody()?['data']?['Unit']} monthly budget.
Action: Check Cost management > Cost analysis for the hint resource groups grouped by resource to see what is driving the spend. In Sep 2026 it was runaway worker executions keeping dedicated nodes running.'''

// condition is allOf[0] from the alert context, it holds the measured value,
// threshold, dimensions (log alerts split by column) and a link to the logs
var alertMessage = '''@{if(equals(triggerBody()?['data']?['essentials']?['monitorCondition'], 'Resolved'), ':white_check_mark: *Resolved*', if(equals(triggerOutputs()?['queries']?['level'], 'critical'), ':rotating_light: *Critical*', ':warning: *Warning*'))}: @{coalesce(triggerBody()?['data']?['essentials']?['alertRule'], 'Unrecognised alert')}
@{coalesce(triggerBody()?['data']?['essentials']?['description'], take(string(triggerBody()), 2000))}@{if(equals(outputs('condition')?['metricValue'], null), '', concat(decodeUriComponent('%0A'), 'Value: ', string(outputs('condition')?['metricValue']), ' (', outputs('condition')?['operator'], ' ', string(outputs('condition')?['threshold']), ')'))}@{if(empty(body('formatDimensions')), '', concat(decodeUriComponent('%0A'), join(body('formatDimensions'), decodeUriComponent('%0A'))))}@{if(empty(outputs('condition')?['linkToFilteredSearchResultsUI']), '', concat(decodeUriComponent('%0A'), '<', outputs('condition')?['linkToFilteredSearchResultsUI'], '|View logs>'))}'''

resource slackNotifier 'Microsoft.Logic/workflows@2019-05-01' = {
  name: '${prefix}-slack-alerts-app'
  location: location
  properties: {
    definition: {
      '$schema': workflowSchema
      contentVersion: '1.0.0.0'
      parameters: {
        slackWebhookUrl: {
          type: 'SecureString'
        }
      }
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {}
        }
      }
      actions: {
        initMessage: {
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'message'
                type: 'string'
                value: ''
              }
            ]
          }
        }
        isBudgetAlert: {
          type: 'If'
          runAfter: {
            initMessage: ['Succeeded']
          }
          expression: {
            and: [
              {
                equals: [
                  '@triggerBody()?[\'schemaId\']'
                  'AIP Budget Notification'
                ]
              }
            ]
          }
          actions: {
            setBudgetMessage: {
              type: 'SetVariable'
              inputs: {
                name: 'message'
                value: budgetMessage
              }
            }
          }
          else: {
            actions: {
              condition: {
                type: 'Compose'
                inputs: '@first(coalesce(triggerBody()?[\'data\']?[\'alertContext\']?[\'condition\']?[\'allOf\'], createArray(json(\'{}\'))))'
              }
              formatDimensions: {
                type: 'Select'
                runAfter: {
                  condition: ['Succeeded']
                }
                inputs: {
                  from: '@coalesce(outputs(\'condition\')?[\'dimensions\'], json(\'[]\'))'
                  select: '@concat(item()?[\'name\'], \': \', item()?[\'value\'])'
                }
              }
              setAlertMessage: {
                type: 'SetVariable'
                runAfter: {
                  formatDimensions: ['Succeeded']
                }
                inputs: {
                  name: 'message'
                  value: alertMessage
                }
              }
            }
          }
        }
        postToSlack: {
          type: 'Http'
          runAfter: {
            isBudgetAlert: ['Succeeded']
          }
          inputs: {
            method: 'POST'
            uri: '@parameters(\'slackWebhookUrl\')'
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              text: '@variables(\'message\')'
            }
          }
          // Stop the webhook URL showing up in the run history
          runtimeConfiguration: {
            secureData: {
              properties: ['inputs']
            }
          }
        }
      }
    }
    parameters: {
      slackWebhookUrl: {
        value: slackWebhookUrl
      }
    }
  }
}

var callbackUrl = listCallbackUrl('${slackNotifier.id}/triggers/manual', '2019-05-01').value

resource infoActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: '${prefix}-slack-info-ag'
  location: 'global'
  properties: {
    groupShortName: '${prefix}-info'
    enabled: true
    webhookReceivers: [
      {
        name: 'slack-info'
        serviceUri: '${callbackUrl}&level=info'
        useCommonAlertSchema: true
      }
    ]
  }
}

resource criticalActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: '${prefix}-slack-critical-ag'
  location: 'global'
  properties: {
    groupShortName: '${prefix}-critical'
    enabled: true
    webhookReceivers: [
      {
        name: 'slack-critical'
        serviceUri: '${callbackUrl}&level=critical'
        useCommonAlertSchema: true
      }
    ]
  }
}

output infoActionGroupId string = infoActionGroup.id
output criticalActionGroupId string = criticalActionGroup.id
