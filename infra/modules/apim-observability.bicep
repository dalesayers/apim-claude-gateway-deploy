targetScope = 'resourceGroup'

@description('API Management service name.')
param apimName string

@description('Application Insights resource ID.')
param appInsightsResourceId string

@description('Application Insights connection string.')
@secure()
param appInsightsConnectionString string

@description('Log Analytics workspace resource ID.')
param logAnalyticsWorkspaceId string

resource apim 'Microsoft.ApiManagement/service@2022-08-01' existing = {
	name: apimName
}

resource logger 'Microsoft.ApiManagement/service/loggers@2022-08-01' = {
	parent: apim
	name: 'appinsights-logger'
	properties: {
		loggerType: 'applicationInsights'
		description: 'Application Insights logger for Claude gateway'
		resourceId: appInsightsResourceId
		credentials: {
			connectionString: appInsightsConnectionString
		}
	}
}

resource serviceDiagnostic 'Microsoft.ApiManagement/service/diagnostics@2022-08-01' = {
	parent: apim
	name: 'applicationinsights'
	properties: {
		loggerId: logger.id
		alwaysLog: 'allErrors'
		httpCorrelationProtocol: 'W3C'
		metrics: true
		sampling: {
			samplingType: 'fixed'
			percentage: 100
		}
		verbosity: 'information'
	}
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
	name: 'apim-to-log-analytics'
	scope: apim
	properties: {
		workspaceId: logAnalyticsWorkspaceId
		logs: [
			{
				category: 'GatewayLogs'
				enabled: true
			}
		]
		metrics: [
			{
				category: 'AllMetrics'
				enabled: true
			}
		]
	}
}

output loggerId string = logger.id
output diagnosticName string = serviceDiagnostic.name
