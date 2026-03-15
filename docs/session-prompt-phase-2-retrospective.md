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

Install rendering and validation tools in the Codespace:

```bash
# Install Node.js-based tools for rendering and link checking
npm install -g puppeteer-cli broken-link-checker serve

# For GIF recording (optional, requires Xvfb)
sudo apt-get update && sudo apt-get install -y xvfb ffmpeg imagemagick

# Verify
npx puppeteer --version
blc --version
```

### 11. Serve the site locally

```bash
# Start a local HTTP server for the frontend
npx serve frontend/ -l 8080 &
SERVER_PID=$!
echo "Server running on http://localhost:8080 (PID: $SERVER_PID)"
sleep 2
```

### 12. Generate full-page screenshots

Capture a full-page screenshot of each major section viewport:

```bash
mkdir -p docs/retrospectives/phase-2-assets

# Full-page screenshot (desktop 1440px)
npx puppeteer screenshot http://localhost:8080 \
  --viewport 1440x900 \
  --full-page \
  docs/retrospectives/phase-2-assets/full-page-desktop.png

# Mobile screenshot (375px iPhone)
npx puppeteer screenshot http://localhost:8080 \
  --viewport 375x812 \
  --full-page \
  docs/retrospectives/phase-2-assets/full-page-mobile.png

# Tablet screenshot (768px iPad)
npx puppeteer screenshot http://localhost:8080 \
  --viewport 768x1024 \
  --full-page \
  docs/retrospectives/phase-2-assets/full-page-tablet.png
```

**Alternative using Node.js script:**

```bash
cat > /tmp/screenshot.js << 'EOF'
const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();

  const viewports = [
    { name: 'desktop', width: 1440, height: 900 },
    { name: 'tablet', width: 768, height: 1024 },
    { name: 'mobile', width: 375, height: 812 },
  ];

  for (const vp of viewports) {
    await page.setViewport({ width: vp.width, height: vp.height });
    await page.goto('http://localhost:8080', { waitUntil: 'networkidle2' });
    await page.screenshot({
      path: `docs/retrospectives/phase-2-assets/full-page-${vp.name}.png`,
      fullPage: true,
    });
    console.log(`Screenshot saved: full-page-${vp.name}.png`);
  }

  await browser.close();
})();
EOF

node /tmp/screenshot.js
```

### 13. Generate animated GIF of site navigation

Record a scrolling walkthrough as GIF:

```bash
cat > /tmp/record-gif.js << 'EOF'
const puppeteer = require('puppeteer');
const { execSync } = require('child_process');

(async () => {
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1440, height: 900 });
  await page.goto('http://localhost:8080', { waitUntil: 'networkidle2' });

  // Capture frames while scrolling
  const frameDir = '/tmp/gif-frames';
  execSync(`mkdir -p ${frameDir}`);

  const totalHeight = await page.evaluate(() => document.body.scrollHeight);
  const step = 100;
  let frame = 0;

  for (let y = 0; y < totalHeight; y += step) {
    await page.evaluate((scrollY) => window.scrollTo(0, scrollY), y);
    await page.waitForTimeout(100);
    await page.screenshot({
      path: `${frameDir}/frame-${String(frame).padStart(4, '0')}.png`,
    });
    frame++;
  }

  await browser.close();

  // Convert frames to GIF using ImageMagick
  execSync(`convert -delay 10 -loop 0 ${frameDir}/frame-*.png docs/retrospectives/phase-2-assets/site-scroll.gif`);
  console.log('GIF saved: site-scroll.gif');
})();
EOF

node /tmp/record-gif.js
```

### 14. Record video of site navigation

Record a full video walkthrough with section navigation:

```bash
cat > /tmp/record-video.js << 'EOF'
const puppeteer = require('puppeteer');
const { execSync } = require('child_process');

(async () => {
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 1440, height: 900 });

  // Start screen recording via Xvfb + ffmpeg (alternative)
  // Or use Puppeteer screencast (Chrome DevTools Protocol)
  const client = await page.target().createCDPSession();
  await client.send('Page.startScreencast', { format: 'png', maxWidth: 1440, maxHeight: 900 });

  const frames = [];
  client.on('Page.screencastFrame', async (event) => {
    frames.push(event.data);
    await client.send('Page.screencastFrameAck', { sessionId: event.sessionId });
  });

  await page.goto('http://localhost:8080', { waitUntil: 'networkidle2' });
  await page.waitForTimeout(2000);

  // Navigate through sections
  const sections = ['#home', '#about', '#resume', '#agentgitops', '#projects'];
  for (const section of sections) {
    await page.evaluate((sel) => {
      document.querySelector(sel)?.scrollIntoView({ behavior: 'smooth' });
    }, section);
    await page.waitForTimeout(3000);
  }

  await client.send('Page.stopScreencast');
  await browser.close();

  // Save frames and convert to video
  const frameDir = '/tmp/video-frames';
  execSync(`mkdir -p ${frameDir}`);
  for (let i = 0; i < frames.length; i++) {
    const buf = Buffer.from(frames[i], 'base64');
    require('fs').writeFileSync(`${frameDir}/frame-${String(i).padStart(5, '0')}.png`, buf);
  }

  execSync(`ffmpeg -y -framerate 10 -i ${frameDir}/frame-%05d.png -c:v libx264 -pix_fmt yuv420p docs/retrospectives/phase-2-assets/site-walkthrough.mp4`);
  console.log('Video saved: site-walkthrough.mp4');
})();
EOF

node /tmp/record-video.js
```

### 15. Broken link audit

Scan all links in the site for broken or unreachable targets:

```bash
# Run broken link checker against local server
blc http://localhost:8080 --recursive --ordered --exclude-external \
  > docs/retrospectives/phase-2-assets/broken-links-internal.txt 2>&1

# Include external links (may have timeouts)
blc http://localhost:8080 --recursive --ordered \
  > docs/retrospectives/phase-2-assets/broken-links-full.txt 2>&1

echo "Broken link reports saved to docs/retrospectives/phase-2-assets/"
```

**Alternative using a Node.js script for more control:**

```bash
cat > /tmp/check-links.js << 'EOF'
const puppeteer = require('puppeteer');
const https = require('https');
const http = require('http');

(async () => {
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.goto('http://localhost:8080', { waitUntil: 'networkidle2' });

  // Collect all links
  const links = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('a[href]')).map(a => ({
      href: a.href,
      text: a.textContent.trim().substring(0, 50),
      isExternal: a.hostname !== location.hostname,
    }));
  });

  const results = [];
  for (const link of links) {
    try {
      const mod = link.href.startsWith('https') ? https : http;
      const status = await new Promise((resolve) => {
        mod.get(link.href, { timeout: 5000 }, (res) => resolve(res.statusCode))
           .on('error', () => resolve('ERROR'));
      });
      results.push({ ...link, status });
    } catch {
      results.push({ ...link, status: 'ERROR' });
    }
  }

  // Generate report
  const broken = results.filter(r => r.status !== 200 && r.status !== 301 && r.status !== 302);
  let report = '# Broken Link Report\n\n';
  report += `**Total links:** ${results.length}\n`;
  report += `**Broken/Unreachable:** ${broken.length}\n\n`;

  if (broken.length > 0) {
    report += '| Status | URL | Link Text |\n|---|---|---|\n';
    for (const b of broken) {
      report += `| ${b.status} | ${b.href} | ${b.text} |\n`;
    }
  } else {
    report += 'No broken links found.\n';
  }

  require('fs').writeFileSync('docs/retrospectives/phase-2-assets/broken-links-report.md', report);
  console.log(report);
  await browser.close();
})();
EOF

node /tmp/check-links.js
```

### 16. Commit content validation artifacts

```bash
# Add rendering and validation artifacts
git add docs/retrospectives/phase-2-assets/

git commit -m "docs: Phase 2 content validation artifacts (screenshots, GIF, video, broken links)"
git push origin develop
```

### 17. Stop the local server

```bash
kill $SERVER_PID 2>/dev/null
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
