#!/usr/bin/env bash
# create-backlog-issues.sh
# Creates GitHub issues from backlog issue .md files using gh CLI.
# Reads YAML frontmatter from each file to extract labels and metadata.
#
# Usage:
#   ./scripts/create-backlog-issues.sh [--dry-run] [owner/repo]
#
# Prerequisites:
#   - gh CLI authenticated (gh auth login)
#   - Labels created (run setup-github-labels.sh first)
#
# Options:
#   --dry-run    Show what would be created without actually creating issues

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISSUES_DIR="${SCRIPT_DIR}/backlog-issues"
DRY_RUN=false
REPO=""

# Parse arguments: flags first, then positional
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN=true
  elif [[ "$arg" != --* ]]; then
    REPO="$arg"
  fi
done

# Fall back to current repo if not provided
if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi

if [[ ! -d "$ISSUES_DIR" ]]; then
  echo "Error: Issues directory not found: $ISSUES_DIR"
  exit 1
fi

echo "========================================"
echo "  Backlog Issue Creator"
echo "  Repository: $REPO"
echo "  Issues dir: $ISSUES_DIR"
echo "  Dry run: $DRY_RUN"
echo "========================================"
echo ""

# Extract value from YAML frontmatter
extract_field() {
  local file="$1"
  local field="$2"
  # Extract content between --- markers, then find the field
  sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | head -1 | sed "s/^${field}: *//;s/^\"//;s/\"$//"
}

# Extract labels array from YAML frontmatter
extract_labels() {
  local file="$1"
  sed -n '/^---$/,/^---$/p' "$file" | sed -n '/^labels:$/,/^[a-z]/p' | grep '^ *- ' | sed 's/^ *- *"//;s/"$//'
}

# Extract body content (everything after the second ---)
extract_body() {
  local file="$1"
  awk 'BEGIN{count=0} /^---$/{count++; next} count>=2{print}' "$file"
}

# Sort files by task_id numerically (phase.sequence)
get_sorted_files() {
  for f in "$ISSUES_DIR"/*.md; do
    local task_id
    task_id=$(extract_field "$f" "task_id")
    echo "${task_id} ${f}"
  done | sort -t. -k1,1n -k2,2n | awk '{print $2}'
}

CREATED=0
FAILED=0
SKIPPED=0

echo "Processing backlog issues..."
echo ""

while IFS= read -r file; do
  task_id=$(extract_field "$file" "task_id")
  title=$(extract_field "$file" "title")
  phase=$(extract_field "$file" "phase")
  phase_name=$(extract_field "$file" "phase_name")
  priority=$(extract_field "$file" "priority")
  size=$(extract_field "$file" "size")
  copilot_suitable=$(extract_field "$file" "copilot_suitable")

  # Build the issue title
  issue_title="[Phase ${phase}] ${title}"

  # Build the issue body
  body=$(extract_body "$file")

  # Build label arguments
  label_args=()
  label_args+=("--label" "backlog")

  # Phase label
  if [[ -n "$phase" && -n "$phase_name" ]]; then
    label_args+=("--label" "Phase ${phase} - ${phase_name}")
  fi

  # Priority label
  if [[ -n "$priority" ]]; then
    label_args+=("--label" "${priority}")
  fi

  # Size label
  if [[ -n "$size" ]]; then
    label_args+=("--label" "${size}")
  fi

  # Copilot suitable label
  if [[ -n "$copilot_suitable" ]]; then
    label_args+=("--label" "Copilot: ${copilot_suitable}")
  fi

  # Area labels from the labels array
  while IFS= read -r label; do
    if [[ "$label" == area:* ]]; then
      label_args+=("--label" "$label")
    fi
  done < <(extract_labels "$file")

  echo "--- Task ${task_id}: ${title} ---"
  echo "  Title:    ${issue_title}"
  echo "  Priority: ${priority}"
  echo "  Size:     ${size}"
  echo "  Copilot:  ${copilot_suitable}"
  printf "  Labels:   "
  for ((i=0; i<${#label_args[@]}; i+=2)); do
    printf "%s, " "${label_args[$((i+1))]}"
  done
  echo ""

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [DRY RUN] Would create issue"
    ((SKIPPED++))
  else
    if gh issue create \
      --repo "$REPO" \
      --title "$issue_title" \
      --body "$body" \
      "${label_args[@]}"; then
      echo "  ✅ Created successfully"
      ((CREATED++))
      # Rate limit: pause between issue creation to avoid GitHub API limits
      sleep 2
    else
      echo "  ❌ Failed to create issue (exit code: $?)"
      ((FAILED++))
    fi
  fi
  echo ""

done < <(get_sorted_files)

echo "========================================"
echo "  Summary"
echo "  Created: $CREATED"
echo "  Failed:  $FAILED"
echo "  Skipped: $SKIPPED (dry run)"
echo "========================================"
