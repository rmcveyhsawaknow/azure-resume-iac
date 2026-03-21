#!/usr/bin/env bash
# setup-github-project.sh
# Creates a GitHub Project (V2) and adds all open backlog issues.
# Requires: gh CLI with 'project' scope (not available via Codespace GITHUB_TOKEN).
#
# Usage:
#   gh auth login --scopes "project,repo,read:org"  # one-time auth with project scope
#   ./scripts/setup-github-project.sh [owner]
#
# Or run outside Codespace where your gh CLI has full scopes.

set -euo pipefail

OWNER="${1:-rmcveyhsawaknow}"
REPO="${OWNER}/azure-resume-iac"
PROJECT_TITLE="Azure Resume IaC — Backlog"

echo "========================================"
echo "  GitHub Project Setup"
echo "  Owner:   $OWNER"
echo "  Repo:    $REPO"
echo "  Project: $PROJECT_TITLE"
echo "========================================"
echo ""

# --- Step 1: Create the project (or find existing) ---
echo "=== Step 1: Create/find project ==="
EXISTING_PROJECT=$(gh project list --owner "$OWNER" --format json 2>/dev/null \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)
for p in data.get('projects', []):
    if p.get('title') == '$PROJECT_TITLE':
        print(p['number'])
        break
" 2>/dev/null || echo "")

if [[ -n "$EXISTING_PROJECT" ]]; then
  PROJECT_NUMBER="$EXISTING_PROJECT"
  echo "  Found existing project #${PROJECT_NUMBER}"
else
  echo "  Creating project: $PROJECT_TITLE"
  PROJECT_NUMBER=$(gh project create --owner "$OWNER" --title "$PROJECT_TITLE" --format json | python3 -c "import json,sys; print(json.load(sys.stdin)['number'])")
  echo "  Created project #${PROJECT_NUMBER}"
fi
echo ""

# --- Step 2: Add custom fields ---
echo "=== Step 2: Add custom fields ==="

# Phase field (single select)
echo "  Adding 'Phase' single-select field..."
gh project field-create "$PROJECT_NUMBER" --owner "$OWNER" \
  --name "Phase" --data-type "SINGLE_SELECT" \
  --single-select-options "Phase 0 - Assessment,Phase 1 - Fix Function App,Phase 2 - Content Update,Phase 3 - Dev Deployment,Phase 4 - Prod Deployment,Phase 5 - Cleanup & Docs" \
  2>/dev/null || echo "  (field may already exist)"

# Priority field (single select)
echo "  Adding 'Priority' single-select field..."
gh project field-create "$PROJECT_NUMBER" --owner "$OWNER" \
  --name "Priority" --data-type "SINGLE_SELECT" \
  --single-select-options "P1 – Critical,P2 – High,P3 – Medium,P4 – Low" \
  2>/dev/null || echo "  (field may already exist)"

# Size field (single select)
echo "  Adding 'Size' single-select field..."
gh project field-create "$PROJECT_NUMBER" --owner "$OWNER" \
  --name "Size" --data-type "SINGLE_SELECT" \
  --single-select-options "S (half-day),M (1–2 days),L (3–5 days),XL (1 week+)" \
  2>/dev/null || echo "  (field may already exist)"

# Copilot Suitable field (single select)
echo "  Adding 'Copilot Suitable' single-select field..."
gh project field-create "$PROJECT_NUMBER" --owner "$OWNER" \
  --name "Copilot Suitable" --data-type "SINGLE_SELECT" \
  --single-select-options "Yes,Partial,No" \
  2>/dev/null || echo "  (field may already exist)"

# Start Date field (date) — required for Roadmap view
echo "  Adding 'Start Date' date field..."
gh project field-create "$PROJECT_NUMBER" --owner "$OWNER" \
  --name "Start Date" --data-type "DATE" \
  2>/dev/null || echo "  (field may already exist)"

# End Date field (date) — required for Roadmap view
echo "  Adding 'End Date' date field..."
gh project field-create "$PROJECT_NUMBER" --owner "$OWNER" \
  --name "End Date" --data-type "DATE" \
  2>/dev/null || echo "  (field may already exist)"

# Story Points field (number) — for velocity tracking
echo "  Adding 'Story Points' number field..."
gh project field-create "$PROJECT_NUMBER" --owner "$OWNER" \
  --name "Story Points" --data-type "NUMBER" \
  2>/dev/null || echo "  (field may already exist)"

echo ""

# --- Step 3: Add all open issues to the project ---
echo "=== Step 3: Add open issues to project ==="
ISSUE_NUMBERS=$(gh issue list --repo "$REPO" --state open --limit 200 --json number -q '.[].number' | sort -n)
TOTAL=$(echo "$ISSUE_NUMBERS" | wc -l)
COUNT=0

for num in $ISSUE_NUMBERS; do
  COUNT=$((COUNT + 1))
  echo "  [$COUNT/$TOTAL] Adding issue #${num}..."
  gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "https://github.com/${REPO}/issues/${num}" 2>/dev/null || echo "    (may already be added)"
  sleep 0.5
done

echo ""
echo "========================================"
echo "  Done! Project #${PROJECT_NUMBER} is set up."
echo "  URL: https://github.com/users/${OWNER}/projects/${PROJECT_NUMBER}"
echo ""
echo "  Fields created: Phase, Priority, Size, Copilot Suitable,"
echo "                   Start Date, End Date, Story Points"
echo ""
echo "  Manual steps remaining (Step 6):"
echo "  Follow the Project Views Guide: bootstrap/project-views-guide.md"
echo ""
echo "  Minimum views to create:"
echo "     1. Board (group by Status)"
echo "     2. Roadmap (date: Start Date/End Date, group by Phase)"
echo "     3. Current Sprint (filter: current phase, Status ≠ Done)"
echo "     4. Copilot Queue (filter: Copilot Suitable = Yes)"
echo "     5. Priority Triage (sort by Priority)"
echo ""
echo "  Required fields in every view:"
echo "     Title, Assignees, Status, Copilot Suitable, Phase, Priority, Size"
echo ""
echo "  For full 10-view setup by team size, see:"
echo "     bootstrap/project-views-guide.md"
echo "========================================"
