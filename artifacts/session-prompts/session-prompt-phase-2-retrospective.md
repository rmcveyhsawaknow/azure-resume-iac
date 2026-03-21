# Codespace Agent Session — Phase 2 Retrospective: Content Update

## Setup

Set up this Codespace for executing the Phase 2 retrospective on `develop` branch.

- **Issue:** https://github.com/rmcveyhsawaknow/azure-resume-iac/issues/149
- **Phase:** 2 — Content Update
- **Milestone:** Phase 2 - Content Update
- **Branch:** `develop`

---

## Phase 2 Rationalization

### Objective

Phase 2 updated the static resume site with current professional content sourced from the [rmcveyhsawaknow GitHub Profile README](https://github.com/rmcveyhsawaknow). The scope covered a full content overhaul of the HTML/CSS frontend — banner, about, resume, projects, certifications, social links, metadata, and styling.

### Tasks Completed (10 of 11)

| Task | Issue | PR | Title | Copilot | Status |
|---|---|---|---|---|---|
| 2.1 | #94 | #173 | Design content layout | Partial | ✅ Closed |
| 2.2 | #95 | #174 | Update banner text | Yes | ✅ Closed |
| 2.3 | #96 | #175 | Update About section | Yes | ✅ Closed |
| 2.4 | #97 | #176 | Update Resume section | Yes | ✅ Closed |
| 2.5 | #98 | #177 | Add Projects section | Yes | ✅ Closed |
| 2.6 | #99 | #178 | Update profile photo | No | ✅ Closed |
| 2.7 | #100 | #179 | Update certification badges | Partial | ✅ Closed |
| 2.8 | #101 | #181 | Update social links | Yes | ✅ Closed |
| 2.9 | #102 | #182 | Update page metadata | Yes | ✅ Closed |
| 2.10 | #103 | #183 | Review CSS/styling | Yes | ✅ Closed |
| 2.11 | #149 | — | Phase 2 Retrospective | Partial | 🔲 This session |

### Key Deliverables

- **Layout:** Restructured HTML sections — banner, about, resume, AgentGitOps, projects
- **Content:** USMC service background, Azure/cloud skills, 9 portfolio projects, professional experience
- **Images:** Optimized WebP/JPEG profile photo with `<picture>` element and `srcset` fallback
- **Certifications:** Verification links, USMC 5974 equivalents, NERC CIP entry
- **Social:** Microsoft Learn profile added, `target="_blank" rel="noopener noreferrer"` enforced
- **SEO:** Updated OG tags, meta descriptions, canonical URL
- **CSS:** Fixed banner `h4` visibility, responsive rules at all 4 breakpoints, resume list styling

### PRs Merged to `develop` (Phase 2)

| PR | Title | Merged |
|---|---|---|
| #173 | Redesign resume site content layout | 2026-03-14 |
| #174 | Update banner/hero section text | 2026-03-14 |
| #175 | Update About section | 2026-03-15 |
| #176 | Update Resume section | 2026-03-15 |
| #177 | Add Projects section | 2026-03-15 |
| #178 | Update profile photo | 2026-03-15 |
| #179 | Update certification badges | 2026-03-15 |
| #181 | Update social links | 2026-03-15 |
| #182 | Update page metadata | 2026-03-15 |
| #183 | Fix CSS: banner text visibility | 2026-03-15 |

### Copilot AI Leverage (Pre-Retrospective Estimate)

- **Task-level:** 14 of 20 closed issues labeled `Copilot: Yes` (~70%)
- **Commit-level:** All 10 PRs authored by Copilot coding agent, reviewed and merged by PM
- **Phase velocity:** 11 tasks scoped, 10 completed in ~1 day (2026-03-14 to 2026-03-15)

---

## Steps

1. **Authenticate CLI tools:**
   ```bash
   bash scripts/setup-codespace-auth.sh
   ```

2. **Verify you are on `develop` branch with latest changes:**
   ```bash
   git checkout develop && git pull origin develop
   ```

3. **Run the retrospective generator:**
   ```bash
   bash scripts/generate-phase-retrospective.sh 2
   ```
   This generates `docs/retrospectives/phase-2-retrospective.md` with metrics pulled from GitHub API and git history.

4. **Review the generated report:**
   ```bash
   cat docs/retrospectives/phase-2-retrospective.md
   ```
   Verify the metrics look reasonable:
   - Issues planned: ~21, closed: ~20 (the 21st is this retrospective)
   - PRs merged: 10 (Phase 2 PRs #173–#183)
   - Copilot task ratio should be ~70% (14 `Copilot: Yes` of 20 closed)
   - Copilot commit ratio should reflect `Co-authored-by` trailers

5. **Commit the retrospective to `develop`:**
   ```bash
   git add docs/retrospectives/phase-2-retrospective.md
   git commit -m "docs: Phase 2 retrospective"
   ```

6. **Post the full retrospective as a comment on issue #149:**
   ```bash
   gh issue comment 149 --repo rmcveyhsawaknow/azure-resume-iac \
     --body-file docs/retrospectives/phase-2-retrospective.md
   ```

7. **Close the Phase 2 milestone:**
   ```bash
   # First, find the milestone number
   gh api repos/rmcveyhsawaknow/azure-resume-iac/milestones?state=all \
     --jq '.[] | select(.title == "Phase 2 - Content Update") | .number'

   # Then close it (replace {N} with the milestone number from above)
   gh api -X PATCH repos/rmcveyhsawaknow/azure-resume-iac/milestones/{N} \
     -f state=closed
   ```

8. **Close the retrospective issue #149:**
   ```bash
   gh issue close 149 --repo rmcveyhsawaknow/azure-resume-iac \
     --comment "Phase 2 retrospective completed. Report committed to docs/retrospectives/phase-2-retrospective.md and posted above."
   ```

9. **Push to develop:**
   ```bash
   git push origin develop
   ```

10. **Update the project board:**
    Move issue #149 to **Done** in the GitHub Project board.

---

## Content Rendering & Validation (Codespace-Only Steps)

> **These steps require a Codespace with browser/display access.** They produce visual
> artifacts (screenshots, GIF, video) and a broken-link report that document the state
> of the site content after Phase 2. Artifacts are committed to `docs/retrospectives/phase-2-assets/`.

### Prerequisites

The validation toolkit under `scripts/site-validation/` handles all dependency installation
automatically. No manual setup is required — `run-validation.sh` calls `install-deps.sh`
which installs system packages (ffmpeg, ImageMagick, zip, Chromium libs) and Node.js
packages (puppeteer, serve) on first run.

### Step 11. Run the site validation toolkit

```bash
# Capture both local (develop branch) and live (production) sites
bash scripts/site-validation/run-validation.sh \
  --phase 2 \
  --local-dir frontend/ \
  --live-url https://resume.ryanmcvey.me \
  --output-base docs/retrospectives/phase-2-assets

# Or capture only local site
bash scripts/site-validation/run-validation.sh \
  --phase 2 \
  --local-dir frontend/ \
  --output-base docs/retrospectives/phase-2-assets \
  --skip-live

# Or capture only live site
bash scripts/site-validation/run-validation.sh \
  --phase 2 \
  --live-url https://resume.ryanmcvey.me \
  --output-base docs/retrospectives/phase-2-assets \
  --skip-local
```

This runs the full validation pipeline for each target:
1. **Screenshots** — Full-page captures at desktop (1440px), tablet (768px), and mobile (375px)
2. **Animated GIF** — Scrolling walkthrough of the full page
3. **Navigation Video** — Section-by-section walkthrough (home → about → resume → agentgitops → projects)
4. **Broken Link Audit** — Checks all `<a href>` links and generates a markdown report

Output is organized as:
```
docs/retrospectives/phase-2-assets/
├── local/                         # Local site artifacts
│   ├── full-page-desktop.png
│   ├── full-page-tablet.png
│   ├── full-page-mobile.png
│   ├── site-scroll.gif
│   ├── site-walkthrough.mp4
│   ├── broken-links-report.md
│   └── capture-summary.md
├── live/                          # Live site artifacts
│   └── (same structure)
├── phase-2-local-site.zip         # Packaged local artifacts
├── phase-2-live-site.zip          # Packaged live artifacts
└── comparison-summary.md          # Side-by-side inventory
```

### Step 12. Review broken link reports

```bash
# Check local site broken links
cat docs/retrospectives/phase-2-assets/local/broken-links-report.md

# Check live site broken links
cat docs/retrospectives/phase-2-assets/live/broken-links-report.md
```

Document any unexpected broken links. Expected false positives include:
- Government sites (SSL certificate issues, bot protection)
- Private GitHub repositories
- Rate-limited external APIs

### Step 13. Commit content validation artifacts

```bash
git add docs/retrospectives/phase-2-assets/
git commit -m "docs: Phase 2 content validation artifacts (screenshots, GIF, video, broken links)"
git push origin develop
```

### Step 14. Stop any remaining processes

The validation script cleans up after itself via a trap handler. If you need to
manually stop a leftover serve process:

```bash
# Find and stop any lingering serve processes
ps aux | grep serve | grep -v grep
# kill <PID> if found
```

---

## Post-Retrospective: Next Phase Readiness

Before starting Phase 3 (Dev Deployment), verify:

- [ ] All 10 Phase 2 content issues are closed
- [ ] Phase 2 milestone is closed
- [ ] Retrospective committed and posted
- [ ] Content validation artifacts generated and committed
- [ ] No broken links blocking deployment
- [ ] No blocking issues remain from Phase 2
- [ ] `develop` branch has all Phase 2 changes merged
- [ ] Phase 3 dependencies on Phase 2 are satisfied

## Notes

- The retrospective script (`scripts/generate-phase-retrospective.sh`) queries GitHub API for milestone/issue/PR data and git history for commit attribution. It requires `gh` CLI authentication.
- If the script reports `⚠️ Milestone not found`, verify the milestone title exactly matches `Phase 2 - Content Update`.
- The script uses the earliest issue activity date (not milestone creation date) as the period start to avoid inflated duration metrics.
- Content rendering steps (screenshots, GIF, video) require a Codespace with `puppeteer`, `ffmpeg`, and `imagemagick`.
- Broken link checks may show false positives for external links behind authentication or rate limiting.
- Phase 2 was completed in ~1 day, reflecting very high Copilot AI leverage on content update tasks.
