# Kestra Flows for Authentik User Approval

This directory contains Kestra workflow definitions for the Authentik email approval system.

## Flows

### new-user-approval.yaml
Receives webhook notifications from Authentik when new users are created and sends approval emails.

### user-approval-action.yaml
Handles approve/deny button clicks from the email and updates user attributes in Authentik.

## Deployment

Kestra flows must be imported via the Kestra API (they are stored in Kestra's database, not as Kubernetes resources).

### Option 1: Import via API

```bash
cd clusters/sirius/apps/kestra/flows

curl -X POST "https://kestra.moonblade.work/api/v1/flows" \
  -H "Content-Type: application/x-yaml" \
  --data-binary @new-user-approval.yaml

curl -X POST "https://kestra.moonblade.work/api/v1/flows" \
  -H "Content-Type: application/x-yaml" \
  --data-binary @user-approval-action.yaml
```

### Option 2: Import via UI

1. Navigate to https://kestra.moonblade.work
2. Go to Flows > Create
3. Paste the YAML content from each file

## Required Secrets

Configure these secrets in Kestra (Settings > Secrets):

| Secret Name | Description |
|-------------|-------------|
| GMAIL_USERNAME | Gmail address (e.g., mnishamk1995@gmail.com) |
| GMAIL_APP_PASSWORD | Gmail App Password for SMTP |
| ADMIN_EMAIL | Email to receive approval requests |
| AUTHENTIK_API_TOKEN | Authentik API token with user write permissions |

### Creating Authentik API Token

1. Login to Authentik admin: https://authentik.moonblade.work/if/admin/
2. Go to Directory > Tokens and App Passwords
3. Create new token with "API Access" intent
4. Copy the token value to Kestra secrets

## Webhook URLs

| Flow | Webhook URL |
|------|-------------|
| new-user-approval | `https://kestra.sirius.moonblade.work/api/v1/executions/webhook/homelab/new-user-approval/696b716e...` |
| user-approval-action | `https://kestra.sirius.moonblade.work/api/v1/executions/webhook/homelab/user-approval-action/8f52833...` |

The webhook keys are configured in the flow YAML files and Authentik blueprint.
