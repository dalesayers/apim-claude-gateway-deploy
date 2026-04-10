# Legacy Scripts

This folder contains historical or internal-reference scripts that are not part of the supported customer deployment path.

## Current Status

- `deploy-apim-claude-gateway.ps1` is retained for historical context and prior imperative deployment/bootstrap workflows.
- Customers should use `deploy-standard.ps1` from the repository root instead.

## Why These Scripts Are Kept

- preserve earlier implementation history
- support internal troubleshooting or archaeology when comparing the imperative and Bicep-based approaches
- avoid losing validated policy and deployment context from the pre-package workflow

## Customer Guidance

If you are deploying this package as a customer, do not start with scripts in this folder.

Use:

- `main.bicep`
- `main.customer.example.bicepparam`
- `deploy-standard.ps1`
