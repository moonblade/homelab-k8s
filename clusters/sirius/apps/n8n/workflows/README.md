# n8n Workflows for Authentik User Approval

## Workflows

### new-user-approval.json
Receives webhook from Authentik when new users are created, sends approval email with approve/deny buttons.

### user-approval-action.json
Handles approve/deny button clicks from the email, updates user attributes in Authentik.

## Manual Import

Since n8n workflows are stored in its database, import these via the UI:

1. Go to https://n8n.sirius.moonblade.work
2. Settings > Import from file
3. Import each JSON file

## Required Credentials

Create these credentials in n8n (Settings > Credentials):

### 1. Gmail SMTP (id: gmail-smtp)
- **Type**: SMTP
- **Host**: smtp.gmail.com
- **Port**: 465
- **SSL/TLS**: true
- **User**: Your Gmail address
- **Password**: Gmail App Password

### 2. Authentik API Token (id: authentik-api)
- **Type**: Header Auth
- **Name**: Authorization
- **Value**: Bearer <your-authentik-api-token>

## Required Environment Variables

Set in n8n deployment:
- `ADMIN_EMAIL`: Email address to receive approval requests

## Webhook URLs

After import, the webhooks will be available at:
- New user notification: `http://n8n.n8n.svc.cluster.local:5678/webhook/authentik-new-user`
- User action: `https://n8n.sirius.moonblade.work/webhook/authentik-user-action`

## Authentik Blueprint

The Authentik blueprint at `infra/authentik/blueprints/06-notification-new-user.yaml` is configured to send webhooks to n8n.
