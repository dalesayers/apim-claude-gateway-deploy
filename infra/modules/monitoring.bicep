targetScope = 'resourceGroup'

@description('Deployment location.')
param location string

@description('Log Analytics workspace name.')
param logAnalyticsName string

@description('Application Insights component name.')
param appInsightsName string

@description('Tags applied to monitoring resources.')
param tags object = {}

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
	name: logAnalyticsName
	location: location
	tags: tags
	properties: {
		sku: {
			name: 'PerGB2018'
		}
		retentionInDays: 30
		features: {
			searchVersion: 1
			enableLogAccessUsingOnlyResourcePermissions: true
		}
	}
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
	name: appInsightsName
	location: location
	tags: tags
	kind: 'web'
	properties: {
		Application_Type: 'web'
		WorkspaceResourceId: workspace.id
	}
}

output logAnalyticsWorkspaceId string = workspace.id
output appInsightsResourceId string = appInsights.id
output appInsightsConnectionString string = appInsights.properties.ConnectionString
