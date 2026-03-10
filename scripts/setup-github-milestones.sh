#!/usr/bin/env bash
# setup-github-milestones.sh
# Creates GitHub Milestones for each project phase (0–5).
# Milestones provide date boundaries for retrospective stats collection.
#
# Usage:
#   ./scripts/setup-github-milestones.sh [owner/repo]
#
# Prerequisites:
#   - gh CLI authenticated (gh auth login)

set -euo pipefail

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

echo "Setting up milestones for: $REPO"
echo ""

# Milestone definitions: title|description
MILESTONES=(
  "Phase 0 - Assessment|Harvest current Azure and Cloudflare state, verify credentials, document actuals, gap analysis"
  "Phase 1 - Fix Function App|Restore visitor counter: runtime upgrade, connectivity, data verification"
  "Phase 2 - Content Update|Update resume site HTML/CSS/JS with GitHub profile content"
  "Phase 3 - Dev Deployment|Deploy updated stack to development environment, validate end-to-end"
  "Phase 4 - Prod Deployment|Deploy validated stack to production, verify live site"
  "Phase 5 - Cleanup & Docs|Remove old resources, update documentation, close project"
)

# Get existing milestones
EXISTING=$(gh api "repos/${REPO}/milestones?state=all&per_page=100" --jq '.[].title' 2>/dev/null || echo "")

for entry in "${MILESTONES[@]}"; do
  IFS='|' read -r title description <<< "$entry"

  if echo "$EXISTING" | grep -qxF "$title"; then
    echo "  ✓ Already exists: $title"
  else
    echo "  Creating milestone: $title"
    gh api "repos/${REPO}/milestones" \
      -f title="$title" \
      -f description="$description" \
      -f state="open" \
      --silent
    echo "  ✅ Created: $title"
  fi
done

echo ""
echo "=== Done! Milestones created/verified for $REPO ==="
echo ""
echo "To assign issues to milestones:"
echo '  gh issue edit <number> --milestone "Phase 0 - Assessment"'
echo ""
echo "To list milestones:"
echo "  gh api repos/${REPO}/milestones --jq '.[] | \"\(.number) \(.title) [\(.state)]\"'"
