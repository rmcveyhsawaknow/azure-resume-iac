#!/usr/bin/env bash
# setup-github-labels.sh
# Creates GitHub labels required for backlog issue management and project views.
# Usage: ./scripts/setup-github-labels.sh [owner/repo]
# Requires: gh CLI authenticated

set -euo pipefail

REPO="${1:-$(git remote get-url origin 2>/dev/null | sed -E 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$#\1#')}"

echo "Setting up labels for: $REPO"

# Helper function to create or update a label
create_label() {
  local name="$1"
  local color="$2"
  local description="$3"

  if gh label list --repo "$REPO" --search "$name" --json name -q '.[].name' | grep -qx "$name"; then
    echo "  Updating label: $name"
    gh label edit "$name" --repo "$REPO" --color "$color" --description "$description"
  else
    echo "  Creating label: $name"
    gh label create "$name" --repo "$REPO" --color "$color" --description "$description"
  fi
}

echo ""
echo "=== Phase Labels ==="
create_label "Phase 0 - Assessment"       "0E8A16" "Phase 0: Assessment and credential verification"
create_label "Phase 1 - Fix Function App"  "0E8A16" "Phase 1: Restore visitor counter functionality"
create_label "Phase 2 - Content Update"    "0E8A16" "Phase 2: Update resume site content"
create_label "Phase 3 - Dev Deployment"    "0E8A16" "Phase 3: Deploy to development environment"
create_label "Phase 4 - Prod Deployment"   "0E8A16" "Phase 4: Deploy to production environment"
create_label "Phase 5 - Cleanup & Docs"    "0E8A16" "Phase 5: Cleanup and documentation"

echo ""
echo "=== Priority Labels ==="
create_label "P1 – Critical" "B60205" "Priority 1: Critical — must be done immediately"
create_label "P2 – High"     "D93F0B" "Priority 2: High — important for this phase"
create_label "P3 – Medium"   "FBCA04" "Priority 3: Medium — should be done this phase"
create_label "P4 – Low"      "0075CA" "Priority 4: Low — nice to have"

echo ""
echo "=== Size Labels ==="
create_label "S (half-day)"  "C2E0C6" "Estimated effort: half-day"
create_label "M (1–2 days)"  "C2E0C6" "Estimated effort: 1–2 days"
create_label "L (3–5 days)"  "C2E0C6" "Estimated effort: 3–5 days"
create_label "XL (1 week+)"  "C2E0C6" "Estimated effort: 1 week or more"

echo ""
echo "=== Copilot Suitable Labels ==="
create_label "Copilot: Yes"     "6F42C1" "Fully suitable for GitHub Copilot agent completion"
create_label "Copilot: Partial" "D4C5F9" "Partially suitable — Copilot can assist but needs human review"
create_label "Copilot: No"      "E4E669" "Not suitable for Copilot — requires manual/human work"

echo ""
echo "=== Domain Area Labels ==="
create_label "area: infrastructure" "1D76DB" "Azure infrastructure and Bicep IaC"
create_label "area: backend"        "1D76DB" "Azure Functions backend (.NET)"
create_label "area: frontend"       "1D76DB" "Static site frontend (HTML/CSS/JS)"
create_label "area: ci-cd"          "1D76DB" "GitHub Actions workflows and CI/CD"
create_label "area: dns-cdn"        "1D76DB" "Cloudflare DNS and CDN configuration"
create_label "area: documentation"  "1D76DB" "Documentation and knowledge base"
create_label "area: credentials"    "1D76DB" "Secrets, tokens, and service principals"

echo ""
echo "=== Source Labels ==="
create_label "gap-analysis-finding" "F9D0C4" "Identified during Phase 0 gap analysis assessment"
create_label "phase-retrospective"  "FEF2C0" "Phase wrap-up retrospective — AgentGitOps"

echo ""
echo "=== Status Labels ==="
create_label "backlog"    "EDEDED" "In the backlog, not yet started"
create_label "ready"      "0E8A16" "Groomed and ready to start"
create_label "blocked"    "B60205" "Blocked by dependency or external factor"

echo ""
echo "=== Done! All labels created/updated for $REPO ==="
