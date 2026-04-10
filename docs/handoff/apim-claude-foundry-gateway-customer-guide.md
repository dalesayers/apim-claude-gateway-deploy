# Azure APIM Claude Gateway
## Customer Guide — Access, Usage, Headers, and Support

**Purpose:** Explain how consumers connect to the Claude-compatible APIM gateway, what headers and authentication are required, what rate-limit headers to expect, and what information to provide when requesting onboarding or support.

**Audience:** Application teams, client developers, and customer stakeholders consuming the gateway.

---

## What This Gateway Provides

The gateway exposes a Claude-compatible endpoint through Azure API Management. It adds:

- Subscription-based access control
- Tier-based token rate limiting and monthly quotas
- Anthropic-compatible synthetic rate-limit headers
- Gateway-level correlation headers for support and diagnostics
- Centralized observability and policy enforcement

The gateway is designed so client applications can call a Claude-style endpoint without needing direct access to the backend Azure AI resource.

---

## What You Need Before You Start

Your team needs the following from the gateway administrator:

- Gateway base URL
- APIM subscription key
- Assigned tier: `claude-enterprise`, `claude-standard`, or `claude-restricted`
- Team identifier for `x-team-id`
- Approved model name, if your organization restricts model choices

Consumer teams do not need a direct Azure AI Foundry backend URL. The gateway owner configures the gateway to use the customer's own Claude-capable Azure AI Foundry deployment behind the scenes.

---

## Endpoint Format

Base URL:

```text
https://apim-claude-gateway.azure-api.net/claude/v1
```

Messages endpoint:

```text
POST https://apim-claude-gateway.azure-api.net/claude/v1/messages
```

---

## Required Request Headers

Include these headers on every request:

| Header | Required | Description |
|---|---|---|
| `Ocp-Apim-Subscription-Key` | Yes | Your APIM subscription key |
| `x-team-id` | Yes | Team or department identifier used for reporting |
| `Content-Type: application/json` | Yes | Request content type |

The gateway automatically adds the Anthropic version header to the backend call. Clients do not need to send `anthropic-version` directly unless instructed otherwise.

---

## Default Sample Subscriptions

Customer packages can ship with three neutral sample subscriptions aligned to the three product tiers:

| Subscription Name | Product |
|---|---|
| `sample-enterprise-prod` | `claude-enterprise` |
| `sample-standard-prod` | `claude-standard` |
| `sample-restricted-prod` | `claude-restricted` |

These names are intended only as onboarding examples. Customers can replace them later with application-specific subscription names if needed.

---

## Example Request

```bash
curl -X POST "https://apim-claude-gateway.azure-api.net/claude/v1/messages" \
  -H "Ocp-Apim-Subscription-Key: <your-subscription-key>" \
  -H "x-team-id: engineering" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "max_tokens": 100,
    "messages": [
      {
        "role": "user",
        "content": "Hello. Please confirm the gateway is working."
      }
    ]
  }'
```

---

## Example Response Headers

The gateway can return headers similar to the following:

| Header | Example | Meaning |
|---|---|---|
| `anthropic-ratelimit-requests-limit` | `10000` | Tier request/token window limit |
| `anthropic-ratelimit-requests-remaining` | `10000` | Remaining current window allowance |
| `anthropic-ratelimit-requests-reset` | `2026-04-10T04:11:34Z` | Window reset time |
| `anthropic-ratelimit-tokens-limit` | `10000` | Tier token window limit |
| `anthropic-ratelimit-tokens-remaining` | `10000` | Remaining token allowance |
| `anthropic-ratelimit-tokens-reset` | `2026-04-10T04:11:34Z` | Token reset time |
| `x-token-usage` | `8in/25out` | Prompt and completion token count for the request |
| `x-remaining-tokens` | `10000` | Friendly duplicate of remaining window tokens |
| `x-remaining-monthly` | `500000` | Remaining monthly quota |
| `x-product-tier` | `claude-standard` | Your assigned gateway tier |
| `x-gateway-request-id` | GUID | Correlation ID for support |

These values are enforced by the gateway tier assigned to your APIM subscription.

---

## Tier Summary

| Tier | Intended Use | Example Limits |
|---|---|---|
| `claude-enterprise` | High-volume production apps | 50,000 TPM, 5,000,000 monthly |
| `claude-standard` | Department and line-of-business apps | 10,000 TPM, 500,000 monthly |
| `claude-restricted` | Low-volume, external, or controlled use cases | 2,000 TPM, 100,000 monthly |

Actual values may be adjusted by your administrator.

---

## Common Errors

### HTTP 429 Too Many Requests

This means your current token or request window has been exhausted.

Typical response shape:

```json
{
  "error": {
    "type": "rate_limit_error",
    "code": "RateLimitExceeded",
    "message": "Token rate limit exceeded for subscription 'sample-restricted-prod'. Retry after 60 seconds.",
    "department": "engineering",
    "product": "claude-restricted",
    "gateway": "apim-claude-foundry",
    "retry_after_seconds": 60
  }
}
```

What to do:

1. Wait for the reset window.
2. Reduce concurrency or prompt volume.
3. Request a higher tier if sustained demand justifies it.

### HTTP 403 Forbidden

This usually means the monthly quota has been exceeded or the subscription is not authorized for the requested usage.

What to do:

1. Confirm your subscription is active.
2. Check remaining monthly quota if the gateway returned it.
3. Contact the gateway administrator with the request ID.

---

## Support Checklist

When opening a support request, include:

- Timestamp of the failing request
- `x-gateway-request-id`, if present
- Your `x-team-id`
- Your assigned subscription or product tier
- Full HTTP status code
- Response body, if available
- Whether the issue is reproducible

This reduces time to resolution significantly.

---

## Onboarding Checklist

Before moving an application into production, confirm:

- APIM subscription key received
- Team identifier agreed
- Expected tier confirmed
- Basic request validated successfully
- Client app stores subscription key securely
- Retry handling added for `429` responses
- Logging captures `x-gateway-request-id`

---

## Contact Your Gateway Admin For

- New subscriptions
- Tier upgrades
- Quota changes
- New model enablement
- Production onboarding approval
- Incident investigation

---

*Last updated: April 9, 2026*
