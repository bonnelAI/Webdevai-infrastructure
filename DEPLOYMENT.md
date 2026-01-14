# Kestra Deployment Guide

This guide will help you deploy Kestra to Railway for staging environment automation.

## Prerequisites

- ✅ Railway account with API token (already configured in `.env`)
- ✅ Docker installed (for building Kestra image)
- ✅ Railway CLI installed
- ✅ Git repository (current repo)

## Step 1: Build and Push Kestra Docker Image

### Option A: Use GitHub Container Registry (Recommended)

```bash
# Image already built and pushed!
# Available at: ghcr.io/t0ct0c/kestra-railway:latest
```

### Option B: Use Docker Hub

```bash
# 1. Build the Kestra image
docker build -f docker/Dockerfile.kestra -t your-dockerhub-username/kestra-railway:latest .

# 2. Login to Docker Hub
docker login

# 3. Push the image
docker push your-dockerhub-username/kestra-railway:latest
```

## Step 2: Create Railway Project for Kestra

```bash
# Navigate to project directory
cd /home/chaz/Desktop/copy-wordpress

# Login to Railway (if not already)
export RAILWAY_TOKEN=41b7445a-a466-43d4-857f-b08c5770ed6c

# Create new Railway project
railway init
```

**In the Railway dashboard:**
1. Go to https://railway.app/new
2. Click "Empty Project"
3. Name it "kestra-staging-automation"
4. Click "+ New" → "Database" → "PostgreSQL"
5. Wait for PostgreSQL to provision
6. Click "+ New" → "Empty Service" → Name it "kestra"
7. Go to service Settings → "Source" → Select "Docker Image"
8. Enter image: `ghcr.io/t0ct0c/kestra-railway:latest`

## Step 3: Add PostgreSQL Database

```bash
# Add PostgreSQL to your Railway project
railway add --database postgresql
```

**Or via dashboard:**
1. Click "+ New" in your project
2. Select "Database" → "PostgreSQL"
3. Wait for provisioning to complete

## Step 4: Deploy Kestra Service

### Via Railway CLI

```bash
# Link to your project
railway link

# Deploy Kestra
railway up

# Set environment variables
railway variables set PORT=8080
railway variables set KESTRA_JWT_SECRET=$(openssl rand -hex 32)
```

### Via Railway Dashboard

1. Click "+ New" → "Empty Service"
2. Name it "kestra"
3. Go to "Settings" → "Source"
4. Select "Docker Image"
5. Enter your image: `ghcr.io/bonnelai/kestra-railway:latest`
6. Go to "Variables" and add:
   - `PORT` = `8080`
   - `DATABASE_URL` = (auto-linked from PostgreSQL)
   - `KESTRA_JWT_SECRET` = (generate random string)
   - `RAILWAY_TOKEN` = `41b7445a-a466-43d4-857f-b08c5770ed6c`
7. Go to "Settings" → "Networking"
8. Click "Generate Domain"

## Step 5: Verify Kestra is Running

```bash
# Check deployment status
railway status

# View logs
railway logs
```

**Or visit:**
- Kestra UI: `https://your-kestra-domain.railway.app`
- Health check: `https://your-kestra-domain.railway.app/health`

You should see the Kestra dashboard!

## Step 6: Configure Kestra Secrets

In Kestra UI (https://your-kestra-domain.railway.app):

1. Go to "Settings" → "Secrets"
2. Add the following secrets:
   - `RAILWAY_TOKEN`: `41b7445a-a466-43d4-857f-b08c5770ed6c`
   - `CLONE_WEBHOOK_KEY`: (generate random string, e.g., `openssl rand -hex 16`)
   - `LIST_WEBHOOK_KEY`: (generate random string)
   - `DELETE_WEBHOOK_KEY`: (generate random string)

## Step 7: Deploy Kestra Workflows

### Upload via Kestra UI

1. Go to "Flows" in Kestra dashboard
2. Click "Create Flow"
3. Copy contents from:
   - `kestra/workflows/clone_staging_api.yaml`
   - `kestra/workflows/list_staging_environments.yaml`
   - `kestra/workflows/delete_staging_environment.yaml`
4. Paste and save each workflow

### Or use Kestra CLI (if available)

```bash
# Install Kestra CLI
npm install -g @kestra-io/cli

# Deploy workflows
kestra flow namespace files kestra/workflows/
```

## Step 8: Test the API

### Test Clone Endpoint

```bash
KESTRA_URL="https://your-kestra-domain.railway.app"
WEBHOOK_KEY="your-clone-webhook-key"

curl -X POST "$KESTRA_URL/api/v1/executions/webhook/dev.deployment/clone-staging-api/$WEBHOOK_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "client_name": "test-client",
    "source_environment": "production"
  }'
```

Expected response:
```json
{
  "executionId": "01HQRS...",
  "state": "CREATED"
}
```

### Check Execution Status

```bash
EXECUTION_ID="01HQRS..."

curl "$KESTRA_URL/api/v1/executions/dev.deployment/clone-staging-api/$EXECUTION_ID"
```

### Test List Endpoint

```bash
LIST_KEY="your-list-webhook-key"

curl "$KESTRA_URL/api/v1/executions/webhook/dev.deployment/list-staging-environments/$LIST_KEY"
```

## Architecture Overview

```
┌─────────────────┐
│   Frontend      │
│   (Your App)    │
└────────┬────────┘
         │ HTTP POST
         ▼
┌─────────────────┐
│  Kestra API     │ ← Deployed on Railway
│  (Webhooks)     │
└────────┬────────┘
         │ Executes
         ▼
┌─────────────────┐
│  Clone Script   │
│  (Bash + CLI)   │
└────────┬────────┘
         │ Creates
         ▼
┌─────────────────┐
│  Railway Env    │
│  + Database     │
└─────────────────┘
```

## Troubleshooting

### Kestra won't start
- Check logs: `railway logs`
- Verify `DATABASE_URL` is set correctly
- Ensure PostgreSQL is running and accessible

### Railway CLI authentication issues
- Verify token: `echo $RAILWAY_TOKEN`
- Re-export token: `export RAILWAY_TOKEN=41b7445a-a466-43d4-857f-b08c5770ed6c`

### Workflow execution fails
- Check Kestra execution logs in UI
- Verify `RAILWAY_TOKEN` secret is set in Kestra
- Ensure Railway CLI is properly installed in Docker image

### Database sync slow or fails
- Check network connectivity
- Verify `pg_dump` and `psql` are installed
- Test database URLs manually

## Next Steps

1. ✅ Kestra deployed and accessible
2. ✅ Workflows uploaded
3. ✅ API tested successfully
4. 🔜 Integrate with your frontend application
5. 🔜 Set up monitoring and alerts
6. 🔜 Configure auto-cleanup for old staging environments

## Maintenance

### Update Kestra Image

```bash
# Rebuild and push new image
docker build -f docker/Dockerfile.kestra -t ghcr.io/bonnelai/kestra-railway:latest .
docker push ghcr.io/bonnelai/kestra-railway:latest

# Trigger Railway deployment
railway up --detach
```

### View Kestra Logs

```bash
railway logs --service kestra
```

### Scale Kestra

In Railway dashboard:
- Go to Kestra service → Settings → Resources
- Adjust memory (2GB → 4GB for more concurrent executions)
- Adjust CPU (1 core → 2 cores for faster execution)

## Cost Estimation

**Railway Costs (Approximate):**
- Kestra Service: ~$5-10/month (2GB RAM, 1 CPU)
- PostgreSQL: ~$5/month (512MB)
- **Total: ~$10-15/month**

**Per staging environment cloned:**
- Environment creation: Free (Railway includes 500GB transfer/month)
- Database sync: Minimal (network egress covered in plan)
- Storage: $0.25/GB/month (only active environments)

## Support

- Railway Docs: https://docs.railway.app
- Kestra Docs: https://kestra.io/docs
- GitHub Issues: https://github.com/bonnelAI/Webdevai-infrastructure/issues
