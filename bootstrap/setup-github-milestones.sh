#!/usr/bin/env bash
# setup-github-milestones.sh
# Creates GitHub Milestones for each project phase (0–5).
# Milestones provide date boundaries for retrospective stats collection
# and drive the Roadmap view when due dates are set.
#
# Usage:
#   ./bootstrap/setup-github-milestones.sh [owner/repo]
#
# Environment Variables (optional — for setting due dates on milestones):
#   PHASE_0_DUE  — ISO 8601 date for Phase 0 due date (e.g., 2025-06-15)
#   PHASE_1_DUE  — ISO 8601 date for Phase 1 due date
#   PHASE_2_DUE  — ISO 8601 date for Phase 2 due date
#   PHASE_3_DUE  — ISO 8601 date for Phase 3 due date
#   PHASE_4_DUE  — ISO 8601 date for Phase 4 due date
#   PHASE_5_DUE  — ISO 8601 date for Phase 5 due date
#
# Prerequisites:
#   - gh CLI authenticated (gh auth login)

set -euo pipefail

REPO="${1:-$(git remote get-url origin 2>/dev/null | sed -E 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$#\1#')}"

echo "Setting up milestones for: $REPO"
echo ""

# Milestone definitions: title|description|env_var_for_due_date
MILESTONES=(
  "Phase 0 - Assessment|Harvest current Azure and Cloudflare state, verify credentials, document actuals, gap analysis|PHASE_0_DUE"
  "Phase 1 - Fix Function App|Restore visitor counter: runtime upgrade, connectivity, data verification|PHASE_1_DUE"
  "Phase 2 - Content Update|Update resume site HTML/CSS/JS with GitHub profile content|PHASE_2_DUE"
  "Phase 3 - Dev Deployment|Deploy updated stack to development environment, validate end-to-end|PHASE_3_DUE"
  "Phase 4 - Prod Deployment|Deploy validated stack to production, verify live site|PHASE_4_DUE"
  "Phase 5 - Cleanup & Docs|Remove old resources, update documentation, close project|PHASE_5_DUE"
)

# Get existing milestones
EXISTING=$(gh api "repos/${REPO}/milestones?state=all&per_page=100" --jq '.[].title' 2>/dev/null || echo "")

for entry in "${MILESTONES[@]}"; do
  IFS='|' read -r title description due_var <<< "$entry"
  due_date="${!due_var:-}"

  # Validate due_date format if provided
  if [[ -n "$due_date" ]] && ! [[ "$due_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "  ⚠️  Invalid date format for $due_var='$due_date' (expected YYYY-MM-DD) — skipping due date"
    due_date=""
  fi

  if echo "$EXISTING" | grep -qxF "$title"; then
    echo "  ✓ Already exists: $title"
    # Update due date if provided and milestone exists
    if [[ -n "$due_date" ]]; then
      milestone_number=$(gh api "repos/${REPO}/milestones?state=all&per_page=100" \
        --jq ".[] | select(.title == \"$title\") | .number" 2>/dev/null || echo "")
      if [[ -n "$milestone_number" ]]; then
        echo "    Updating due date: $due_date"
        gh api -X PATCH "repos/${REPO}/milestones/${milestone_number}" \
          -f due_on="${due_date}T23:59:59Z" \
          --silent
        echo "    ✅ Due date set: $due_date"
      fi
    fi
  else
    echo "  Creating milestone: $title"
    if [[ -n "$due_date" ]]; then
      gh api "repos/${REPO}/milestones" \
        -f title="$title" \
        -f description="$description" \
        -f state="open" \
        -f due_on="${due_date}T23:59:59Z" \
        --silent
      echo "  ✅ Created: $title (due: $due_date)"
    else
      gh api "repos/${REPO}/milestones" \
        -f title="$title" \
        -f description="$description" \
        -f state="open" \
        --silent
      echo "  ✅ Created: $title (no due date — set via PHASE_N_DUE env vars)"
    fi
  fi
done

echo ""
echo "=== Done! Milestones created/verified for $REPO ==="
echo ""
echo "To set due dates (required for Roadmap view):"
echo '  PHASE_0_DUE=2025-06-15 PHASE_1_DUE=2025-06-30 ./bootstrap/setup-github-milestones.sh'
echo ""
echo "Or manually per milestone:"
echo '  gh api -X PATCH "repos/${REPO}/milestones/{number}" -f due_on="2025-07-15T23:59:59Z"'
echo ""
echo "To assign issues to milestones:"
echo '  gh issue edit <number> --milestone "Phase 0 - Assessment"'
echo ""
echo "To list milestones:"
echo '  gh api repos/${REPO}/milestones --jq '\''.[] | "\(.number) \(.title) [\(.state)] due:\(.due_on // "none")"'\'''
