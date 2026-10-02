using '../../bicep/alerts.bicep'

param prefix = 'nm'

param slackWebhookUrl = readEnvironmentVariable('AVENIR_NM_SLACK_WEBHOOK_URL')

param hintResourceGroup = 'nmHint-RG'
param logAnalyticsWorkspaceName = 'naomiLogs'
param redisName = '${prefix}-hintr-queue'
param postgresServerName = 'nm-hint-db'

param availabilityUrl = 'https://naomi.unaids.org'

param budgetAmount = 500
param budgetNoteAmount = 400
param budgetStartDate = '2026-10-01T00:00:00Z'
param budgetResourceGroups = [
  'nmHint-RG'
  'nmHint-logs-RG'
  'nmHint-backup-RG'
  'ME_nm-hint-env_nmHint-RG_eastus2'
]
