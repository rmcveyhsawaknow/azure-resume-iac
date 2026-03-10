#!/usr/bin/env bash
# generate-phase-retrospective.sh
# Generates a phase retrospective report with planned-vs-actual metrics,
# Human/Copilot KPI, and gap analysis summary.
#
# Usage:
#   ./scripts/generate-phase-retrospective.sh <phase_number> [--dry-run] [owner/repo]
#
# Output:
#   - docs/retrospectives/phase-{N}-retrospective.md (committed artifact)
#   - Optionally posts as comment on the retrospective issue
#
# Prerequisites:
#   - gh CLI authenticated
#   - Milestones created (run setup-github-milestones.sh first)
#   - Phase issues assigned to milestone

set -euo pipefail

PHASE=""
DRY_RUN=false
REPO=""

for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN=true
  elif [[ "$arg" =~ ^[0-5]$ ]]; then
    PHASE="$arg"
  elif [[ "$arg" == */* ]]; then
    REPO="$arg"
  fi
done

if [[ -z "$PHASE" ]]; then
  echo "Usage: $0 <phase_number> [--dry-run] [owner/repo]"
  echo "  phase_number: 0-5"
  exit 1
fi

if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi

OWNER="$(echo "$REPO" | cut -d/ -f1)"

# Phase name mapping
declare -A PHASE_NAMES=(
  [0]="Assessment"
  [1]="Fix Function App"
  [2]="Content Update"
  [3]="Dev Deployment"
  [4]="Prod Deployment"
  [5]="Cleanup & Docs"
)

PHASE_NAME="${PHASE_NAMES[$PHASE]}"
MILESTONE_TITLE="Phase ${PHASE} - ${PHASE_NAME}"
RETRO_DIR="docs/retrospectives"
RETRO_FILE="${RETRO_DIR}/phase-${PHASE}-retrospective.md"
DATE_NOW=$(date -u +"%Y-%m-%d")

echo "========================================"
echo "  Phase Retrospective Generator"
echo "  Repository: $REPO"
echo "  Phase:      ${PHASE} - ${PHASE_NAME}"
echo "  Milestone:  $MILESTONE_TITLE"
echo "  Dry run:    $DRY_RUN"
echo "========================================"
echo ""

# --- Collect Milestone Data ---
echo "Collecting milestone data..."
MILESTONE_JSON=$(gh api "repos/${REPO}/milestones?state=all&per_page=100" \
  --jq ".[] | select(.title == \"${MILESTONE_TITLE}\")" 2>/dev/null || echo "{}")

if [[ -z "$MILESTONE_JSON" || "$MILESTONE_JSON" == "{}" ]]; then
  echo "⚠️  Milestone '${MILESTONE_TITLE}' not found. Stats will be limited."
  MILESTONE_NUMBER=""
  MILESTONE_CREATED=""
  MILESTONE_CLOSED=""
  MILESTONE_STATE="not found"
  MILESTONE_OPEN_ISSUES=0
  MILESTONE_CLOSED_ISSUES=0
else
  MILESTONE_NUMBER=$(echo "$MILESTONE_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['number'])")
  MILESTONE_CREATED=$(echo "$MILESTONE_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['created_at'][:10])")
  MILESTONE_CLOSED=$(echo "$MILESTONE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['closed_at'][:10] if d.get('closed_at') else 'open')")
  MILESTONE_STATE=$(echo "$MILESTONE_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['state'])")
  MILESTONE_OPEN_ISSUES=$(echo "$MILESTONE_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['open_issues'])")
  MILESTONE_CLOSED_ISSUES=$(echo "$MILESTONE_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin)['closed_issues'])")
fi

TOTAL_ISSUES=$((MILESTONE_OPEN_ISSUES + MILESTONE_CLOSED_ISSUES))
echo "  Milestone issues: ${MILESTONE_CLOSED_ISSUES} closed / ${TOTAL_ISSUES} total"

# --- Collect Issue Breakdown by Label ---
echo "Collecting issue label breakdown..."

if [[ -n "$MILESTONE_NUMBER" ]]; then
  # Issues by Copilot suitability
  COPILOT_YES=$(gh issue list --repo "$REPO" --milestone "$MILESTONE_TITLE" --state all --label "Copilot: Yes" --json number --jq 'length' 2>/dev/null || echo "0")
  COPILOT_PARTIAL=$(gh issue list --repo "$REPO" --milestone "$MILESTONE_TITLE" --state all --label "Copilot: Partial" --json number --jq 'length' 2>/dev/null || echo "0")
  COPILOT_NO=$(gh issue list --repo "$REPO" --milestone "$MILESTONE_TITLE" --state all --label "Copilot: No" --json number --jq 'length' 2>/dev/null || echo "0")

  # Issues from gap analysis
  GAP_ISSUES=$(gh issue list --repo "$REPO" --milestone "$MILESTONE_TITLE" --state all --label "gap-analysis-finding" --json number --jq 'length' 2>/dev/null || echo "0")

  # Closed Copilot-suitable issues (task-level AI attribution)
  COPILOT_YES_CLOSED=$(gh issue list --repo "$REPO" --milestone "$MILESTONE_TITLE" --state closed --label "Copilot: Yes" --json number --jq 'length' 2>/dev/null || echo "0")
else
  COPILOT_YES=0; COPILOT_PARTIAL=0; COPILOT_NO=0; GAP_ISSUES=0; COPILOT_YES_CLOSED=0
fi

echo "  Copilot: Yes=${COPILOT_YES}, Partial=${COPILOT_PARTIAL}, No=${COPILOT_NO}"
echo "  Gap analysis findings: ${GAP_ISSUES}"

# --- Collect PR Data ---
echo "Collecting PR data..."

# Determine date range for PRs and commits.
# Prefer deriving START_DATE from earliest issue activity within the milestone
# rather than milestone creation time (milestones are often created up-front for
# all phases at once, which would produce inflated/misleading metrics).
START_DATE=""
if [[ -n "${MILESTONE_TITLE:-}" && -n "${MILESTONE_NUMBER:-}" ]]; then
  ISSUES_JSON=$(gh issue list --repo "$REPO" --milestone "$MILESTONE_TITLE" --state all --json createdAt,closedAt 2>/dev/null || echo "[]")
  START_DATE=$(echo "$ISSUES_JSON" | python3 -c "
import json, sys
issues = json.load(sys.stdin)
dates = []
for issue in issues:
    for key in ('createdAt', 'closedAt'):
        v = issue.get(key)
        if v:
            dates.append(v[:10])
print(min(dates) if dates else '')
" 2>/dev/null || echo "")
fi

# Fall back to milestone creation date, then a safe default if nothing is available.
if [[ -z "$START_DATE" ]]; then
  START_DATE="${MILESTONE_CREATED:-2024-01-01}"
fi

END_DATE="${DATE_NOW}"

# Get PRs that mention phase issues or were merged during milestone period
PRS_JSON=$(gh pr list --repo "$REPO" --state merged --json number,title,author,mergedAt,additions,deletions --limit 200 2>/dev/null || echo "[]")

# Filter PRs by date range
PRS_IN_RANGE=$(echo "$PRS_JSON" | python3 -c "
import json, sys
prs = json.load(sys.stdin)
start = '${START_DATE}'
end = '${END_DATE}'
filtered = [p for p in prs if p.get('mergedAt','')[:10] >= start and p.get('mergedAt','')[:10] <= end]
print(len(filtered))
" 2>/dev/null || echo "0")

PRS_BY_AUTHOR=$(echo "$PRS_JSON" | python3 -c "
import json, sys
from collections import Counter
prs = json.load(sys.stdin)
start = '${START_DATE}'
end = '${END_DATE}'
filtered = [p for p in prs if p.get('mergedAt','')[:10] >= start and p.get('mergedAt','')[:10] <= end]
authors = Counter(p.get('author',{}).get('login','unknown') for p in filtered)
rows = sorted(authors.items(), key=lambda x: -x[1])
if rows:
    for author, count in rows:
        print(f'| {author} | {count} |')
else:
    print('| — | 0 |')
" 2>/dev/null || echo "| — | 0 |")

echo "  PRs merged in range: ${PRS_IN_RANGE}"

# --- Collect Commit Data ---
echo "Collecting commit data..."

# Get commits on develop in the date range
COMMIT_COUNT=$(git log --oneline --after="${START_DATE}" --before="${END_DATE}T23:59:59" --all 2>/dev/null | wc -l || echo "0")
COMMIT_COUNT=$(echo "$COMMIT_COUNT" | tr -d ' ')

# Commits by author
COMMITS_BY_AUTHOR=$(
  rows=$(git log --format='%aN' --after="${START_DATE}" --before="${END_DATE}T23:59:59" --all 2>/dev/null \
    | sort | uniq -c | sort -rn \
    | while read -r count name; do echo "| ${name} | ${count} |"; done || true)
  if [[ -z "$rows" ]]; then echo "| — | 0 |"; else echo "$rows"; fi
)

# Copilot-attributed commits (Co-authored-by trailer)
COPILOT_COMMITS=$(git log --all --after="${START_DATE}" --before="${END_DATE}T23:59:59" --format='%b' 2>/dev/null | grep -ci 'co-authored-by.*copilot' || true)
COPILOT_COMMITS=${COPILOT_COMMITS:-0}
COPILOT_COMMITS=$(echo "$COPILOT_COMMITS" | tr -d '[:space:]')

echo "  Commits: ${COMMIT_COUNT} (${COPILOT_COMMITS} Copilot co-authored)"

# --- Collect Branch Data ---
echo "Collecting branch data..."
BRANCH_COUNT=$(git branch -r 2>/dev/null | wc -l || echo "0")
BRANCH_COUNT=$(echo "$BRANCH_COUNT" | tr -d ' ')

# --- Collect Unique Contributors ---
echo "Collecting contributor data..."
UNIQUE_COMMITTERS=$(git log --format='%aN' --after="${START_DATE}" --before="${END_DATE}T23:59:59" --all 2>/dev/null | sort -u | wc -l || echo "0")
UNIQUE_COMMITTERS=$(echo "$UNIQUE_COMMITTERS" | tr -d ' ')

COMMITTER_LIST=$(git log --format='%aN' --after="${START_DATE}" --before="${END_DATE}T23:59:59" --all 2>/dev/null | sort -u || echo "—")

# --- Calculate Duration ---
if [[ "$MILESTONE_CLOSED" != "open" && "$MILESTONE_CLOSED" != "" && -n "$MILESTONE_CREATED" ]]; then
  DURATION_DAYS=$(python3 -c "
from datetime import datetime
start = datetime.strptime('${MILESTONE_CREATED}', '%Y-%m-%d')
end = datetime.strptime('${MILESTONE_CLOSED}', '%Y-%m-%d')
print((end - start).days)
" 2>/dev/null || echo "—")
else
  DURATION_DAYS=$(python3 -c "
from datetime import datetime
start = datetime.strptime('${START_DATE}', '%Y-%m-%d')
end = datetime.now()
print((end - start).days)
" 2>/dev/null || echo "—")
fi

# --- Calculate Human/Copilot KPI ---
echo "Calculating Human vs Copilot KPI..."

if [[ "$TOTAL_ISSUES" -gt 0 ]]; then
  COPILOT_TASK_RATIO=$(python3 -c "
yes=${COPILOT_YES_CLOSED}
total=${MILESTONE_CLOSED_ISSUES}
print(f'{(yes/total*100):.1f}%' if total > 0 else '0.0%')
" 2>/dev/null || echo "0.0%")
else
  COPILOT_TASK_RATIO="0.0%"
fi

if [[ "$COMMIT_COUNT" -gt 0 ]]; then
  COPILOT_COMMIT_RATIO=$(python3 -c "
cop=${COPILOT_COMMITS}
total=${COMMIT_COUNT}
print(f'{(int(cop)/int(total)*100):.1f}%' if int(total) > 0 else '0.0%')
" 2>/dev/null || echo "0.0%")
else
  COPILOT_COMMIT_RATIO="0.0%"
fi

echo "  Task-level AI ratio: ${COPILOT_TASK_RATIO}"
echo "  Commit-level AI ratio: ${COPILOT_COMMIT_RATIO}"

# --- Check for Gap Analysis Artifacts ---
echo "Checking for assessment artifacts..."
GAP_FILE="assessment-output/gaps-and-recommendations.md"
INVENTORY_FILE="assessment-output/resource-inventory.json"
ACTUAL_VS_EXPECTED="assessment-output/actual-vs-expected.md"

HAS_GAP_ANALYSIS=false
GAP_FINDINGS_COUNT=0
if [[ -f "$GAP_FILE" ]]; then
  HAS_GAP_ANALYSIS=true
  GAP_FINDINGS_COUNT=$(grep -c '^| F[0-9]' "$GAP_FILE" 2>/dev/null || echo "0")
  echo "  Gap analysis found: ${GAP_FINDINGS_COUNT} findings"
else
  echo "  No gap analysis artifacts (assessment-output/ not present)"
fi

# --- Generate Report ---
echo ""
echo "Generating retrospective report..."

mkdir -p "$RETRO_DIR"

cat > "$RETRO_FILE" << REPORT
# Phase ${PHASE} Retrospective: ${PHASE_NAME}

**Generated:** ${DATE_NOW}
**Repository:** ${REPO}
**Milestone:** ${MILESTONE_TITLE}
**Milestone State:** ${MILESTONE_STATE}
**Period:** ${MILESTONE_CREATED:-unknown} → ${MILESTONE_CLOSED:-${DATE_NOW}}
**Duration:** ${DURATION_DAYS} days

---

## Phase Summary

**Phase ${PHASE} — ${PHASE_NAME}** covered the following workstreams:

$(if [[ -n "$MILESTONE_NUMBER" ]]; then
  echo "- **${TOTAL_ISSUES}** issues assigned to milestone"
  echo "- **${MILESTONE_CLOSED_ISSUES}** issues closed, **${MILESTONE_OPEN_ISSUES}** remaining open"
  echo "- **${GAP_ISSUES}** issues originated from gap analysis"
else
  echo "- Milestone not found — stats collected from date range only"
fi)

---

## Planned vs Actual Effort

| Metric | Value |
|---|---|
| Issues planned (milestone) | ${TOTAL_ISSUES} |
| Issues closed | ${MILESTONE_CLOSED_ISSUES} |
| Issues remaining | ${MILESTONE_OPEN_ISSUES} |
| Completion rate | $(python3 -c "print(f'{${MILESTONE_CLOSED_ISSUES}/${TOTAL_ISSUES}*100:.0f}%' if ${TOTAL_ISSUES} > 0 else 'N/A')" 2>/dev/null || echo "N/A") |
| PRs merged | ${PRS_IN_RANGE} |
| Commits | ${COMMIT_COUNT} |
| Gap analysis findings | ${GAP_FINDINGS_COUNT} |
| Issues from gap analysis | ${GAP_ISSUES} |

---

## Capacity & Duration Metrics

| Metric | Value |
|---|---|
| Duration (days) | ${DURATION_DAYS} |
| Remote branches | ${BRANCH_COUNT} |
| Unique contributors | ${UNIQUE_COMMITTERS} |
| Contributors | $(echo "$COMMITTER_LIST" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g') |

---

## PRs by Author

| Author | PRs Merged |
|---|---|
${PRS_BY_AUTHOR}

## Commits by Author

| Author | Commits |
|---|---|
${COMMITS_BY_AUTHOR}

---

## Human vs Copilot AI Productivity KPI

### Task-Level Attribution (Issue Labels)

| Metric | Count | Percentage |
|---|---|---|
| Issues labeled Copilot: Yes | ${COPILOT_YES} | — |
| Issues labeled Copilot: Partial | ${COPILOT_PARTIAL} | — |
| Issues labeled Copilot: No | ${COPILOT_NO} | — |
| Copilot: Yes issues closed | ${COPILOT_YES_CLOSED} | ${COPILOT_TASK_RATIO} of closed |

### Commit-Level Attribution (Co-authored-by Trailers)

| Metric | Count | Percentage |
|---|---|---|
| Total commits | ${COMMIT_COUNT} | $([ "${COMMIT_COUNT}" -gt 0 ] && echo "100%" || echo "N/A") |
| Copilot co-authored commits | ${COPILOT_COMMITS} | ${COPILOT_COMMIT_RATIO} |
| Human-only commits | $((COMMIT_COUNT - COPILOT_COMMITS)) | $(python3 -c "
cop=${COPILOT_COMMITS}; total=${COMMIT_COUNT}
print(f'{(int(total)-int(cop))/int(total)*100:.1f}%' if int(total)>0 else 'N/A')
" 2>/dev/null || echo "N/A") |

### AI-Human Productivity Index

> **Definition:** The AI-Human Productivity Index measures the proportion of project work
> that was AI-assisted at both the task level (issues) and code level (commits).
> A higher index indicates greater AI leverage in the development workflow.

| KPI | Value |
|---|---|
| Task-level AI ratio | ${COPILOT_TASK_RATIO} |
| Commit-level AI ratio | ${COPILOT_COMMIT_RATIO} |

$(if [[ "$HAS_GAP_ANALYSIS" == "true" ]]; then
cat << GAP
---

## Gap Analysis Summary

**Gap analysis artifacts were present in \`assessment-output/\` during this retrospective.**

| Metric | Value |
|---|---|
| Total findings | ${GAP_FINDINGS_COUNT} |
| Issues created from findings | ${GAP_ISSUES} |
| Inventory file | \`assessment-output/resource-inventory.json\` |
| Actual vs Expected | \`assessment-output/actual-vs-expected.md\` |
| Gaps & Recommendations | \`assessment-output/gaps-and-recommendations.md\` |

> **Note:** The \`assessment-output/\` directory is gitignored. The gap analysis
> was captured as issues labeled \`gap-analysis-finding\` and the summary above
> preserves the key metrics in this committed retrospective file.
GAP
fi)

---

## Next Phase Readiness

- [ ] All phase issues closed or deferred with rationale
- [ ] Milestone closed
- [ ] Retrospective committed to \`docs/retrospectives/\`
- [ ] Retrospective posted as comment on retrospective issue
- [ ] Project board updated — retrospective issue moved to Done
- [ ] No blocking issues for next phase

---

*Generated by \`scripts/generate-phase-retrospective.sh\` — AgentGitOps workflow*
REPORT

echo "✅ Report written to: ${RETRO_FILE}"

if [[ "$DRY_RUN" == "true" ]]; then
  echo ""
  echo "[DRY RUN] Report generated but not posted to any issue."
  echo "Preview:"
  echo "---"
  head -40 "$RETRO_FILE"
  echo "..."
  echo "---"
else
  # Find the retrospective issue for this phase
  RETRO_ISSUE=$(gh issue list --repo "$REPO" --state open --label "phase-retrospective" \
    --label "Phase ${PHASE} - ${PHASE_NAME}" --json number --jq '.[0].number' 2>/dev/null || echo "")

  if [[ -n "$RETRO_ISSUE" ]]; then
    echo "📋 Posting retrospective to issue #${RETRO_ISSUE}..."
    gh issue comment "$RETRO_ISSUE" --repo "$REPO" --body-file "$RETRO_FILE"
    echo "✅ Posted to issue #${RETRO_ISSUE}"
  else
    echo "⚠️  No open retrospective issue found with labels: phase-retrospective + Phase ${PHASE} - ${PHASE_NAME}"
    echo "   Create one or manually post the report."
  fi
fi

echo ""
echo "========================================"
echo "  Retrospective Complete"
echo "  File: ${RETRO_FILE}"
echo "  Phase: ${PHASE} - ${PHASE_NAME}"
echo "========================================"
