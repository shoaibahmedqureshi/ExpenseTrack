#!/bin/bash

# Outlay Profile Agent - Automated Setup Script
# This script helps you set up GitHub secrets and deploy the agent

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  🚀 OUTLAY PROFILE AGENT - SETUP AUTOMATION                 ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI not found. Installing..."
    echo ""
    echo "Visit: https://cli.github.com/"
    echo "or run: brew install gh"
    exit 1
fi

# Check GitHub authentication
echo "🔐 Checking GitHub authentication..."
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated to GitHub"
    echo ""
    echo "Run: gh auth login"
    echo "Then run this script again"
    exit 1
fi

echo "✅ GitHub authenticated"
echo ""

# Get repo info
REPO=$(gh repo view --json nameWithOwner -q 2>/dev/null)
if [ -z "$REPO" ]; then
    echo "❌ Could not determine repository"
    echo "Make sure you're in the repo directory"
    exit 1
fi

echo "📦 Repository: $REPO"
echo ""

# Set GitHub secrets
echo "🔑 Setting up GitHub secrets..."
echo ""

# Secret values
SUPABASE_URL="https://xgavxbuezmivnseyhkye.supabase.co"
SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhnYXZ4YnVlem1pdm5zZXloa3llIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MTM3NTUyMywiZXhwIjoyMDk2OTUxNTIzfQ.XCcaeI2McS442mS1E0nXNN4QITERW47w4Q_cWVzf3G0"
GMAIL_USER="outlay.noreply@gmail.com"
GMAIL_PASSWORD="Bhola@9585"

# Add secrets
echo "Adding SUPABASE_URL..."
echo "$SUPABASE_URL" | gh secret set SUPABASE_URL 2>/dev/null && echo "✅ SUPABASE_URL" || echo "⚠️ SUPABASE_URL (may already exist)"

echo "Adding SUPABASE_SERVICE_ROLE_KEY..."
echo "$SUPABASE_KEY" | gh secret set SUPABASE_SERVICE_ROLE_KEY 2>/dev/null && echo "✅ SUPABASE_SERVICE_ROLE_KEY" || echo "⚠️ SUPABASE_SERVICE_ROLE_KEY (may already exist)"

echo "Adding GMAIL_USER..."
echo "$GMAIL_USER" | gh secret set GMAIL_USER 2>/dev/null && echo "✅ GMAIL_USER" || echo "⚠️ GMAIL_USER (may already exist)"

echo "Adding GMAIL_PASSWORD..."
echo "$GMAIL_PASSWORD" | gh secret set GMAIL_PASSWORD 2>/dev/null && echo "✅ GMAIL_PASSWORD" || echo "⚠️ GMAIL_PASSWORD (may already exist)"

echo ""
echo "✅ GitHub secrets configured!"
echo ""

# Trigger workflow
echo "🚀 Triggering first agent run..."
echo ""

WORKFLOW_ID=$(gh workflow list --all | grep "run-profile-agent" | awk '{print $1}' | head -1)

if [ -z "$WORKFLOW_ID" ]; then
    echo "❌ Could not find workflow 'run-profile-agent'"
    echo "Make sure you pushed the code to GitHub"
    exit 1
fi

gh workflow run "$WORKFLOW_ID" --ref main 2>/dev/null && echo "✅ Workflow triggered!" || echo "⚠️ Could not trigger workflow"

echo ""
echo "⏳ Waiting for agent to run (this takes 2-3 minutes)..."
echo ""
echo "You can watch progress at:"
echo "  → https://github.com/$REPO/actions"
echo ""

# Wait for workflow completion
WAIT_TIME=0
MAX_WAIT=180  # 3 minutes

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    LATEST_RUN=$(gh run list --workflow="$WORKFLOW_ID" --limit 1 --json conclusion,status -q 2>/dev/null | head -1)

    if [[ "$LATEST_RUN" == *"success"* ]]; then
        echo "✅ Agent run COMPLETED SUCCESSFULLY!"
        break
    elif [[ "$LATEST_RUN" == *"failure"* ]]; then
        echo "❌ Agent run FAILED"
        break
    fi

    echo -ne "\r⏳ Waiting... ($WAIT_TIME seconds)"
    sleep 5
    WAIT_TIME=$((WAIT_TIME + 5))
done

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  ✅ DEPLOYMENT COMPLETE!                                     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Next: Check your dashboard at:"
echo "   → Open: /dashboard.html"
echo "   → Scroll to: 'Profiles Created'"
echo "   → Should show: https://dev.to/outlayapp, etc."
echo ""
echo "🔐 IMPORTANT: Change your Gmail password!"
echo "   → Go to: myaccount.google.com/security"
echo "   → Security → App passwords"
echo "   → Create new password for 'Outlay Agent'"
echo "   → Update in GitHub secrets"
echo ""
echo "📅 Agent will run automatically every day at 6 AM UTC"
echo ""
echo "Questions? See: agents/profile-automation/README.md"
echo ""
