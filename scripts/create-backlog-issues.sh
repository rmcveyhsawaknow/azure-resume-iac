#!/usr/bin/env bash
# create-backlog-issues.sh
# Creates GitHub issues from backlog issue .md files using gh CLI.
# Reads YAML frontmatter from each file to extract labels and metadata.
#
# Usage:
#   ./scripts/create-backlog-issues.sh [--dry-run] [owner/repo] [file ...]
#
# When no files are given, processes ALL .md files in backlog-issues/.
# To create issues for specific files only (avoids duplicates):
#   ./scripts/create-backlog-issues.sh scripts/backlog-issues/{1.12,3.10,3.11}.md
#   ./scripts/create-backlog-issues.sh --dry-run scripts/backlog-issues/3.*.md
#
# Prerequisites:
#   - gh CLI authenticated (gh auth login)
#   - Labels created (run setup-github-labels.sh first)
#
# Options:
#   --dry-run       Show what would be created without actually creating issues
#   --no-project    Skip adding issues to the GitHub Project

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISSUES_DIR="${SCRIPT_DIR}/backlog-issues"
DRY_RUN=false
REPO=""
FILES=()
NO_PROJECT=false

# Parse arguments: flags, .md file paths, and repo name
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN=true
  elif [[ "$arg" == "--no-project" ]]; then
    NO_PROJECT=true
  elif [[ "$arg" == *.md ]]; then
    FILES+=("$arg")
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

if [[ ${#FILES[@]} -gt 0 ]]; then
  FILE_MODE="${#FILES[@]} specified file(s)"
else
  FILE_MODE="all files in $ISSUES_DIR"
fi

echo "========================================"
echo "  Backlog Issue Creator"
echo "  Repository: $REPO"
echo "  Files:     $FILE_MODE"
echo "  Dry run:   $DRY_RUN"
echo "  Project:   $(if [[ "$NO_PROJECT" == true ]]; then echo 'skip'; else echo 'auto-add'; fi)"
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

# --- GitHub Project V2 configuration ---
# Project: Azure Resume IaC — Backlog (project #9)
# These IDs are from `gh project field-list 9 --owner <owner> --format json`
PROJECT_NUMBER=9
PROJECT_OWNER="$(echo "$REPO" | cut -d/ -f1)"

# Field IDs
PROJECT_PHASE_FIELD="PVTSSF_lAHOBibeL84BRVsxzg_MiUc"
PROJECT_PRIORITY_FIELD="PVTSSF_lAHOBibeL84BRVsxzg_MiUk"
PROJECT_SIZE_FIELD="PVTSSF_lAHOBibeL84BRVsxzg_MiVQ"
PROJECT_COPILOT_FIELD="PVTSSF_lAHOBibeL84BRVsxzg_MiWA"

# Phase option IDs (keyed by phase number)
declare -A PHASE_OPTION_IDS=(
  [0]="70ee0bd5" [1]="a61899bf" [2]="e6b3e93e"
  [3]="1f731d90" [4]="1777406b" [5]="b96aa0a0"
)

# Priority option IDs (keyed by short prefix: P1, P2, P3, P4)
declare -A PRIORITY_OPTION_IDS=(
  ["P1"]="81541891" ["P2"]="725e03f8" ["P3"]="8c90ab5a" ["P4"]="814739e3"
)

# Size option IDs (keyed by first token: S, M, L, XL)
declare -A SIZE_OPTION_IDS=(
  ["S"]="3d6ca061" ["M"]="da26800f" ["L"]="b2824b4a" ["XL"]="a911bc6a"
)

# Copilot Suitable option IDs
declare -A COPILOT_OPTION_IDS=(
  ["Yes"]="6689ec40" ["Partial"]="34aaaef1" ["No"]="c2894628"
)

# Cache the project node ID once (only if we need it)
PROJECT_ID=""
get_project_id() {
  if [[ -z "$PROJECT_ID" ]]; then
    PROJECT_ID=$(gh project view "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json \
      | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
  fi
  echo "$PROJECT_ID"
}

# Add an issue to the project and set its custom fields
add_issue_to_project() {
  local issue_url="$1"
  local phase="$2"
  local priority="$3"  # e.g. "P2 – High"
  local size="$4"       # e.g. "S (half-day)"
  local copilot="$5"    # e.g. "Yes"

  local proj_id
  proj_id=$(get_project_id)

  # Add item and get its ID
  local item_id
  item_id=$(gh project item-add "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" \
    --url "$issue_url" --format json \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

  # Set Phase
  if [[ -n "${PHASE_OPTION_IDS[$phase]:-}" ]]; then
    gh project item-edit --project-id "$proj_id" --id "$item_id" \
      --field-id "$PROJECT_PHASE_FIELD" --single-select-option-id "${PHASE_OPTION_IDS[$phase]}"
  fi

  # Set Priority (extract "P2" from "P2 – High")
  local pkey="${priority%% *}"
  if [[ -n "${PRIORITY_OPTION_IDS[$pkey]:-}" ]]; then
    gh project item-edit --project-id "$proj_id" --id "$item_id" \
      --field-id "$PROJECT_PRIORITY_FIELD" --single-select-option-id "${PRIORITY_OPTION_IDS[$pkey]}"
  fi

  # Set Size (extract "S" from "S (half-day)")
  local skey="${size%% *}"
  if [[ -n "${SIZE_OPTION_IDS[$skey]:-}" ]]; then
    gh project item-edit --project-id "$proj_id" --id "$item_id" \
      --field-id "$PROJECT_SIZE_FIELD" --single-select-option-id "${SIZE_OPTION_IDS[$skey]}"
  fi

  # Set Copilot Suitable
  if [[ -n "${COPILOT_OPTION_IDS[$copilot]:-}" ]]; then
    gh project item-edit --project-id "$proj_id" --id "$item_id" \
      --field-id "$PROJECT_COPILOT_FIELD" --single-select-option-id "${COPILOT_OPTION_IDS[$copilot]}"
  fi
}

# Sort files by task_id numerically (phase.sequence)
# When FILES array is non-empty, sort only those; otherwise sort all files in ISSUES_DIR.
get_sorted_files() {
  local file_list=()
  if [[ ${#FILES[@]} -gt 0 ]]; then
    file_list=("${FILES[@]}")
  else
    file_list=("$ISSUES_DIR"/*.md)
  fi
  for f in "${file_list[@]}"; do
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

  # Area and extra labels from the labels array
  while IFS= read -r label; do
    if [[ "$label" == area:* || "$label" == "gap-analysis-finding" || "$label" == "phase-retrospective" ]]; then
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
    SKIPPED=$((SKIPPED + 1))
  else
    if gh issue create \
      --repo "$REPO" \
      --title "$issue_title" \
      --body "$body" \
      "${label_args[@]}"; then
      echo "  ✅ Created successfully"
      CREATED=$((CREATED + 1))

      # Add to project and set custom fields
      if [[ "$NO_PROJECT" != "true" ]]; then
        issue_url=$(gh issue list --repo "$REPO" --search "$issue_title" --json url -q '.[0].url' 2>/dev/null || echo "")
        if [[ -n "$issue_url" ]]; then
          echo "  📋 Adding to project..."
          if add_issue_to_project "$issue_url" "$phase" "$priority" "$size" "$copilot_suitable"; then
            echo "  📋 Added to project with fields"
          else
            echo "  ⚠️  Issue created but failed to add to project"
          fi
        fi
      fi

      # Rate limit: pause between issue creation to avoid GitHub API limits
      sleep 2
    else
      echo "  ❌ Failed to create issue (exit code: $?)"
      FAILED=$((FAILED + 1))
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
