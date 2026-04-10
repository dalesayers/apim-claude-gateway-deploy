# Azure APIM Claude Gateway

This folder is the customer deployment package for the Claude-compatible Azure API Management gateway.

## What deploys

- Log Analytics workspace
- Application Insights component linked to the workspace
- API Management Developer tier with system-assigned managed identity
- APIM logger and diagnostics wired to Application Insights and Log Analytics
- Claude gateway API at `POST /claude/v1/messages`
- Three default products with fixed token and quota policies:
  - `claude-enterprise`
  - `claude-standard`
  - `claude-restricted`
- Sample APIM subscriptions for customer onboarding and validation

Default sample subscriptions:

- `sample-enterprise-prod`
- `sample-standard-prod`
- `sample-restricted-prod`

The template creates sample APIM subscriptions so a customer can onboard and validate against their own Azure AI Foundry backend without hand-creating test subscriptions first.

## Quickstart

1. Copy `main.customer.example.bicepparam` to `main.customer.bicepparam`.
2. Fill in the environment-specific values.
3. Replace `foundryBackendUrl` with the customer's own Claude-capable Azure AI Foundry endpoint.
4. Do not leave the sample placeholder URL in place.
5. Run:

```powershell
.\deploy-standard.ps1 -SubscriptionId "<subscription-id>" -ParametersFile ".\main.customer.bicepparam"
```

6. Grant the APIM managed identity `Cognitive Services User` on the target Azure AI Foundry resource.
7. Use one of the created APIM subscriptions to validate `POST /claude/v1/messages` through the APIM gateway.

## Automation

The repo includes GitHub Actions workflows under `.github/workflows`:

- `bicep-whatif.yml`: manual or pull request `what-if`
- `bicep-deploy.yml`: manual deployment using the same wrapper script

Both workflows expect these repository or environment secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

## Customer Validation

This repo does not include a mock backend path. Customers must provide their own Azure AI Foundry Claude backend URL and validate against their own deployment using the created APIM products, subscriptions, and policies.

## Layout

- `main.bicep`: deployment entry point
- `infra/modules`: modular resource definitions
- `infra/policies`: APIM policy XML loaded by Bicep
- `docs/customer`: customer-facing deployment and validation notes
- `docs/internal`: operator runbook notes