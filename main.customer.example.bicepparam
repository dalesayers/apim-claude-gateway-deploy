using './main.bicep'

// Replace with the customer's own Claude-capable Azure AI Foundry endpoint.
// Example format: https://<your-foundry-resource>.services.ai.azure.com/anthropic
param environmentName = 'sample-prod'
param location = 'eastus2'
param resourceGroupName = 'rg-ai-gateway-sample-prod'
param apimName = 'apim-sample-claude-gateway'
param appInsightsName = 'appi-sample-claude-gateway'
param logAnalyticsName = 'law-sample-claude-gateway'
param publisherEmail = 'platformops@example.com'
param publisherName = 'Sample Customer'
param foundryBackendUrl = 'https://replace-with-your-foundry-resource.services.ai.azure.com/anthropic'
param modelName = 'claude-sonnet-4-6'
param createApimSubscriptions = true
param tags = {
  Environment: 'prod'
  Owner: 'Sample Customer'
  Workload: 'ClaudeGateway'
}
