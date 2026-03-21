# Environment & Branch Protection Configuration

This document provides manual click-through instructions and scripted automation for configuring GitHub environment protection rules and branch protection rules for the Azure Resume IaC project.

**Related Issues:**

- Task 3.10 — Add production environment protection rules (gap-analysis F6)
- Task 3.11 — Fix development environment branch policy (gap-analysis F18)

**Context:** This is a public repository with a single code owner (`rmcveyhsawaknow`) and GitHub Copilot as a contributor. The protection rules must allow the owner to review and approve their own PRs (and PRs authored by Copilot) without being blocked.

---

## Table of Contents

1. [Production Environment Protection (Manual Steps)](#1-production-environment-protection-manual-steps)
2. [Development Environment Protection (Manual Steps)](#2-development-environment-protection-manual-steps)
3. [Main Branch Protection (Manual Steps)](#3-main-branch-protection-manual-steps)
4. [Develop Branch Protection (Manual Steps)](#4-develop-branch-protection-manual-steps)
5. [Automated Script](#5-automated-script)
6. [Verification Commands](#6-verification-commands)

---

## 1. Production Environment Protection (Manual Steps)

### Navigate to Environment Settings

1. Go to **https://github.com/rmcveyhsawaknow/azure-resume-iac**
2. Click **Settings** (gear icon in repository top nav)
3. In the left sidebar, under **Code and automation**, click **Environments**
4. Click on **production** (or click **New environment** → name it `production` if it doesn't exist)

### Configure Required Reviewers

5. Under **Deployment protection rules**, check ✅ **Required reviewers**
6. In the search box, type your GitHub username (`rmcveyhsawaknow`) and select it
7. Click **Save protection rules**

> **Why:** This ensures every production deployment is explicitly approved. Since you are the sole owner, you will be the reviewer.

### Configure Wait Timer (Recommended)

8. Check ✅ **Wait timer**
9. Set the timer to **5** minutes
10. Click **Save protection rules**

> **Why:** The 5-minute window allows you to cancel an accidental production deployment.

### Configure Deployment Branch Policy

11. Under **Deployment branches and tags**, change the dropdown from **All branches** to **Selected branches and tags**
12. Click **Add deployment branch or tag rule**
13. In the **Ref pattern** field, type: `main`
14. Click **Add rule**
15. Verify that only `main` appears in the branch list
16. Click **Save protection rules** (if prompted)

> **Why:** This restricts production deployments to the `main` branch only — no feature branches or `develop` can accidentally deploy to production.

### Verify Configuration

17. The environment settings page should now show:
    - ✅ Required reviewers: `rmcveyhsawaknow`
    - ✅ Wait timer: 5 minutes
    - ✅ Deployment branches: Selected branches → `main`

---

## 2. Development Environment Protection (Manual Steps)

### Navigate to Environment Settings

1. Go to **https://github.com/rmcveyhsawaknow/azure-resume-iac/settings/environments**
2. Click on **development** (or click **New environment** → name it `development` if it doesn't exist)

### Configure Deployment Branch Policy

3. Under **Deployment branches and tags**, change the dropdown from **All branches** to **Selected branches and tags**
4. Click **Add deployment branch or tag rule**
5. In the **Ref pattern** field, type: `develop`
6. Click **Add rule**
7. Verify that only `develop` appears in the branch list

> **Why:** This ensures only the `develop` branch can trigger development deployments.

### Optional: Required Reviewers

For development, required reviewers are **not recommended** (to keep iteration speed fast), but if desired:

8. Check ✅ **Required reviewers**
9. Add `rmcveyhsawaknow`
10. Click **Save protection rules**

### Verify Configuration

11. The environment settings page should show:
    - ✅ Deployment branches: Selected branches → `develop`

---

## 3. Main Branch Protection (Manual Steps)

### Navigate to Branch Protection Rules

1. Go to **https://github.com/rmcveyhsawaknow/azure-resume-iac/settings/branches**
2. Click **Add classic branch protection rule** (or **Add rule** depending on your plan)

> **Note:** If you see "Add branch ruleset" instead of "Add classic branch protection rule", you are on the new rulesets UI. The steps below cover both classic rules and rulesets.

### Classic Branch Protection Rule for `main`

3. In **Branch name pattern**, type: `main`

4. Check ✅ **Require a pull request before merging**
   - Set **Required approving reviews** to **1**
   - **Do NOT** check "Dismiss stale pull request approvals when new commits are pushed" (allows flexibility)
   - **Do NOT** check "Require review from Code Owners" (since you are the sole code owner and need to merge your own PRs)

5. Check ✅ **Require status checks to pass before merging** (optional, enable when CI is stable)
   - If enabled, add relevant status checks (e.g., `build`, `test`)

6. Check ✅ **Require conversation resolution before merging** (recommended)

7. **Do NOT** check "Require signed commits" (optional, not required)

8. **Do NOT** check "Require linear history" (optional, allows merge commits)

9. **Include administrators** — leave this **UNCHECKED**
   - ⚠️ **Important:** Leaving this unchecked allows repo admins (you) to bypass the rule when needed. Since you're the sole contributor, you need the ability to self-approve and merge.

10. **Allow force pushes** — leave this **UNCHECKED** (protect history)

11. **Allow deletions** — leave this **UNCHECKED** (protect branch)

12. Click **Create** (or **Save changes**)

### Key Consideration: Self-Approval

Since you are the sole contributor:

- The PR author can submit an approval on their own PR, but it **does not count** toward the required approval threshold
- However, as a **repository admin** with "Include administrators" **unchecked**, you can bypass the review requirement and merge directly regardless
- For Copilot-authored PRs, you (as non-author) can provide the required review approval normally

---

## 4. Develop Branch Protection (Manual Steps)

### Navigate to Branch Protection Rules

1. Go to **https://github.com/rmcveyhsawaknow/azure-resume-iac/settings/branches**
2. Click **Add classic branch protection rule**

### Classic Branch Protection Rule for `develop`

3. In **Branch name pattern**, type: `develop`

4. Check ✅ **Require a pull request before merging**
   - Set **Required approving reviews** to **1**
   - **Do NOT** check "Require review from Code Owners"

5. **Do NOT** check "Require status checks to pass before merging" (optional for dev)

6. Check ✅ **Require conversation resolution before merging** (recommended)

7. **Include administrators** — **Leave UNCHECKED**
   - This allows you to bypass the review requirement on develop when needed for rapid iteration.

8. **Allow force pushes** — **Leave UNCHECKED**

9. **Allow deletions** — **Leave UNCHECKED**

10. Click **Create** (or **Save changes**)

### Flexibility Notes

- **Your PRs:** As admin, you can merge your own PRs even without approval (admin bypass)
- **Copilot PRs:** You review and approve normally, then merge
- **Hotfixes:** As admin, you can bypass rules in emergencies

---

## 5. Automated Script

A script is provided at `scripts/configure-repo-protection.sh` that uses the GitHub API (`gh api`) to programmatically configure all the protection rules described above.

### Usage

```bash
# Dry run — assess current state only (no changes)
bash scripts/configure-repo-protection.sh --dry-run

# Apply all protection rules
bash scripts/configure-repo-protection.sh

# Apply with custom reviewer
bash scripts/configure-repo-protection.sh --reviewer rmcveyhsawaknow

# Apply to a specific repo
bash scripts/configure-repo-protection.sh --repo rmcveyhsawaknow/azure-resume-iac
```

### What the Script Does

1. **Captures pre-configuration state** — snapshots current environment and branch protection settings
2. **Configures production environment** — required reviewer, 5-min wait timer, `main`-only deployment branch
3. **Configures development environment** — `develop`-only deployment branch
4. **Configures `main` branch protection** — require PR, 1 approval, admin bypass enabled
5. **Configures `develop` branch protection** — require PR, 1 approval, admin bypass enabled
6. **Captures post-configuration state** — snapshots updated settings
7. **Compares and displays differences** — shows before/after diff

### Prerequisites

- `gh` CLI authenticated with `repo` scope: `gh auth login --scopes repo`
  - Verify with: `gh auth status -t`
- Repository admin permissions
- `jq` installed for JSON processing

---

## 6. Verification Commands

After configuration, verify settings with these commands:

### Environment Protection

```bash
# Production environment
gh api repos/{owner}/{repo}/environments/production | jq '{
  protection_rules: .protection_rules,
  deployment_branch_policy: .deployment_branch_policy
}'

# Development environment
gh api repos/{owner}/{repo}/environments/development | jq '{
  protection_rules: .protection_rules,
  deployment_branch_policy: .deployment_branch_policy
}'
```

### Branch Protection

```bash
# Main branch protection
gh api repos/{owner}/{repo}/branches/main/protection | jq '{
  required_pull_request_reviews: .required_pull_request_reviews,
  enforce_admins: .enforce_admins,
  required_status_checks: .required_status_checks
}'

# Develop branch protection
gh api repos/{owner}/{repo}/branches/develop/protection | jq '{
  required_pull_request_reviews: .required_pull_request_reviews,
  enforce_admins: .enforce_admins,
  required_status_checks: .required_status_checks
}'
```

### Deployment Branch Policies

```bash
# List allowed deployment branches for production
gh api repos/{owner}/{repo}/environments/production/deployment-branch-policies | jq '.branch_policies'

# List allowed deployment branches for development
gh api repos/{owner}/{repo}/environments/development/deployment-branch-policies | jq '.branch_policies'
```
