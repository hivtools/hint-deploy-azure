targetScope = 'subscription'

@description('Name of the budget')
param budgetName string

@description('Monthly budget in USD, a warning is sent when spend reaches this')
param budgetAmount int

@description('Spend in USD at which an early note is sent')
param noteAmount int

@description('First day of the month the budget starts from, e.g. 2026-10-01T00:00:00Z')
param startDate string

@description('Resource groups the budget covers')
param resourceGroups array

param noteActionGroupId string
param warningActionGroupId string

// The subscription contains other projects, so filter down to just the hint resource groups
resource budget 'Microsoft.Consumption/budgets@2023-11-01' = {
  name: budgetName
  properties: {
    category: 'Cost'
    amount: budgetAmount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
    }
    filter: {
      dimensions: {
        name: 'ResourceGroupName'
        operator: 'In'
        values: resourceGroups
      }
    }
    notifications: {
      note: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: noteAmount * 100 / budgetAmount
        thresholdType: 'Actual'
        contactEmails: []
        contactGroups: [noteActionGroupId]
      }
      overBudget: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Actual'
        contactEmails: []
        contactGroups: [warningActionGroupId]
      }
    }
  }
}
