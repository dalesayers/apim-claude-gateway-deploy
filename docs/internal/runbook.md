# Internal Runbook

This repo is the customer-facing live-only deployment package.

## Operational intent

- Keep product names and token policies stable by default.
- Keep APIM subscriptions customer-managed.
- Keep mock and tunnel validation workflows out of the customer repo.

## Source of truth

If policy behavior needs to be compared against the original successful deployment, use `deploy-apim-claude-gateway.ps1` as the reference implementation.