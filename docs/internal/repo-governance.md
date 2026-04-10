# Repository Governance

## Current Constraint

This repository is private under a personal GitHub account. GitHub returned a `403` when attempting to enable branch protection on `main` because that feature requires GitHub Pro for private personal repositories or a public repository.

## Intended `main` Branch Settings

Apply these settings when the repository plan supports branch protection:

- Require a pull request before merging
- Require 1 approving review
- Dismiss stale approvals when new commits are pushed
- Require conversation resolution before merging
- Block force pushes
- Block branch deletion

## Recommended Review Discipline Until Protection Is Available

- Treat `main` as protected operationally even if GitHub cannot enforce it yet.
- Make changes on short-lived branches.
- Use pull requests for all non-trivial updates.
- Avoid direct pushes to `main` unless the change is urgent and low risk.
- Re-run Bicep build and `what-if` validation before merging deployment-related changes.
