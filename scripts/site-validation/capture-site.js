#!/usr/bin/env node
// =============================================================================
// capture-site.js — Capture screenshots, GIF, video, and broken link report
// for a given URL. Used by run-validation.sh for retrospective content
// validation of both local dev sites and deployed production sites.
//
// Usage:
//   node capture-site.js --url <URL> --output <dir> [--sections <ids>] [--label <name>]
//
// Options:
//   --url       Base URL to capture (e.g., http://localhost:8080 or https://resume.ryanmcvey.me)
//   --output    Output directory for artifacts
//   --sections  Comma-separated section IDs for navigation video (default: home,about,resume,agentgitops,projects)
//   --label     Label for this capture set (default: "site")
// =============================================================================

const puppeteer = require('puppeteer');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

// --- Argument parsing ---
function parseArgs() {
  const args = process.argv.slice(2);
  const opts = {
    url: null,
    output: null,
    sections: ['home', 'about', 'resume', 'agentgitops', 'projects'],
    label: 'site',
  };

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--url': opts.url = args[++i]; break;
      case '--output': opts.output = args[++i]; break;
      case '--sections': opts.sections = args[++i].split(','); break;
      case '--label': opts.label = args[++i]; break;
    }
  }

  if (!opts.url || !opts.output) {
    console.error('Usage: node capture-site.js --url <URL> --output <dir> [--sections <ids>] [--label <name>]');
    process.exit(1);
  }

  return opts;
}

// --- Screenshot capture ---
async function captureScreenshots(page, url, outputDir) {
  const viewports = [
    { name: 'desktop', width: 1440, height: 900 },
    { name: 'tablet', width: 768, height: 1024 },
    { name: 'mobile', width: 375, height: 812 },
  ];

  const results = [];
  for (const vp of viewports) {
    await page.setViewport({ width: vp.width, height: vp.height });
    await page.goto(url, { waitUntil: 'networkidle2', timeout: 30000 });
    // Wait a moment for animations to settle
    await sleep(1500);

    const filePath = path.join(outputDir, `full-page-${vp.name}.png`);
    await page.screenshot({ path: filePath, fullPage: true });

    const stat = fs.statSync(filePath);
    console.log(`  ✓ Screenshot: full-page-${vp.name}.png (${vp.width}×${vp.height}, ${formatBytes(stat.size)})`);
    results.push({ name: `full-page-${vp.name}.png`, viewport: `${vp.width}×${vp.height}`, size: stat.size });
  }
  return results;
}

// --- Animated GIF (frame capture + ImageMagick) ---
async function captureGif(page, url, outputDir) {
  const frameDir = path.join(outputDir, '.gif-frames');
  fs.mkdirSync(frameDir, { recursive: true });

  await page.setViewport({ width: 1440, height: 900 });
  await page.goto(url, { waitUntil: 'networkidle2', timeout: 30000 });
  await sleep(1000);

  const totalHeight = await page.evaluate(() => document.body.scrollHeight);
  const viewportHeight = 900;
  const step = 200; // pixels per scroll step
  let frame = 0;

  // Capture initial viewport
  await page.screenshot({ path: path.join(frameDir, `frame-${String(frame).padStart(4, '0')}.png`) });
  frame++;

  // Scroll down capturing frames
  for (let y = step; y < totalHeight; y += step) {
    await page.evaluate((scrollY) => window.scrollTo(0, scrollY), y);
    await sleep(80);
    await page.screenshot({ path: path.join(frameDir, `frame-${String(frame).padStart(4, '0')}.png`) });
    frame++;
  }

  // Scroll to bottom for final frame
  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  await sleep(200);
  await page.screenshot({ path: path.join(frameDir, `frame-${String(frame).padStart(4, '0')}.png`) });

  const gifPath = path.join(outputDir, 'site-scroll.gif');

  // Use ImageMagick to create GIF — resize to reduce file size
  try {
    execSync(
      `convert -delay 8 -loop 0 -resize 720x ${frameDir}/frame-*.png "${gifPath}"`,
      { stdio: 'pipe', timeout: 120000 }
    );
    const stat = fs.statSync(gifPath);
    console.log(`  ✓ GIF: site-scroll.gif (${frame + 1} frames, ${formatBytes(stat.size)})`);

    // Clean up frames
    fs.rmSync(frameDir, { recursive: true, force: true });
    return { name: 'site-scroll.gif', frames: frame + 1, size: stat.size };
  } catch (err) {
    console.error(`  ✗ GIF generation failed: ${err.message}`);
    fs.rmSync(frameDir, { recursive: true, force: true });
    return null;
  }
}

// --- Video (frame capture + ffmpeg) ---
async function captureVideo(page, url, outputDir, sections) {
  const frameDir = path.join(outputDir, '.video-frames');
  fs.mkdirSync(frameDir, { recursive: true });

  await page.setViewport({ width: 1440, height: 900 });
  await page.goto(url, { waitUntil: 'networkidle2', timeout: 30000 });
  await sleep(1000);

  let frame = 0;

  // Helper to capture N frames (holding on a view)
  async function captureHoldFrames(count) {
    for (let i = 0; i < count; i++) {
      await page.screenshot({ path: path.join(frameDir, `frame-${String(frame).padStart(5, '0')}.png`) });
      frame++;
      await sleep(50);
    }
  }

  // Hold on initial view
  await captureHoldFrames(20); // ~2s at 10fps

  // Navigate through each section
  for (const section of sections) {
    const selector = `#${section}`;
    const exists = await page.evaluate((sel) => !!document.querySelector(sel), selector);
    if (!exists) {
      console.log(`  ⚠ Section ${selector} not found, skipping`);
      continue;
    }

    // Smooth scroll to section
    await page.evaluate((sel) => {
      document.querySelector(sel)?.scrollIntoView({ behavior: 'smooth' });
    }, selector);

    // Capture frames during scroll animation
    for (let i = 0; i < 15; i++) {
      await sleep(100);
      await page.screenshot({ path: path.join(frameDir, `frame-${String(frame).padStart(5, '0')}.png`) });
      frame++;
    }

    // Hold on section for ~2s
    await captureHoldFrames(20);
  }

  const videoPath = path.join(outputDir, 'site-walkthrough.mp4');

  try {
    execSync(
      `ffmpeg -y -framerate 10 -i "${frameDir}/frame-%05d.png" -c:v libx264 -pix_fmt yuv420p -vf "scale=1440:-2" "${videoPath}"`,
      { stdio: 'pipe', timeout: 120000 }
    );
    const stat = fs.statSync(videoPath);

    // Get video duration
    let duration = 'unknown';
    try {
      duration = execSync(`ffprobe -v error -show_entries format=duration -of csv=p=0 "${videoPath}"`, { encoding: 'utf-8' }).trim();
      duration = `${parseFloat(duration).toFixed(1)}s`;
    } catch { /* ignore */ }

    console.log(`  ✓ Video: site-walkthrough.mp4 (${frame} frames, ${duration}, ${formatBytes(stat.size)})`);

    fs.rmSync(frameDir, { recursive: true, force: true });
    return { name: 'site-walkthrough.mp4', frames: frame, duration, size: stat.size };
  } catch (err) {
    console.error(`  ✗ Video generation failed: ${err.message}`);
    fs.rmSync(frameDir, { recursive: true, force: true });
    return null;
  }
}

// --- Broken link checker ---
async function checkBrokenLinks(page, url, outputDir) {
  await page.goto(url, { waitUntil: 'networkidle2', timeout: 30000 });

  // Collect all links from the page
  const links = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('a[href]')).map(a => ({
      href: a.href,
      text: a.textContent.trim().substring(0, 60),
      isExternal: a.hostname !== location.hostname,
    })).filter(l => l.href.startsWith('http'));
  });

  // Deduplicate
  const uniqueLinks = [...new Map(links.map(l => [l.href, l])).values()];

  console.log(`  Checking ${uniqueLinks.length} unique links...`);
  const results = [];

  for (const link of uniqueLinks) {
    const status = await checkUrl(link.href);
    results.push({ ...link, status });
  }

  // Build report
  const broken = results.filter(r => typeof r.status === 'string' || (r.status >= 400));
  const working = results.filter(r => typeof r.status === 'number' && r.status < 400);

  let report = '# Broken Link Report\n\n';
  report += `| Metric | Count |\n|---|---|\n`;
  report += `| Total links checked | ${results.length} |\n`;
  report += `| Working (2xx/3xx) | ${working.length} |\n`;
  report += `| Broken/Error | ${broken.length} |\n\n`;

  if (broken.length > 0) {
    report += '## Broken/Unreachable Links\n\n';
    report += '| Status | URL | Link Text |\n|---|---|---|\n';
    for (const b of broken) {
      report += `| ${b.status} | ${b.href} | ${b.text} |\n`;
    }
    report += '\n';
  }

  report += '## All Links\n\n';
  report += '| Status | Type | URL | Link Text |\n|---|---|---|---|\n';
  for (const r of results) {
    const type = r.isExternal ? 'External' : 'Internal';
    const icon = (typeof r.status === 'number' && r.status < 400) ? '✓' : '✗';
    report += `| ${icon} ${r.status} | ${type} | ${r.href} | ${r.text} |\n`;
  }

  const reportPath = path.join(outputDir, 'broken-links-report.md');
  fs.writeFileSync(reportPath, report);

  console.log(`  ✓ Broken links: ${broken.length} broken of ${results.length} total`);
  return { total: results.length, broken: broken.length, working: working.length };
}

function checkUrl(url) {
  return new Promise((resolve) => {
    const mod = url.startsWith('https') ? https : http;
    const req = mod.get(url, { timeout: 8000, headers: { 'User-Agent': 'Site-Validation-Bot/1.0' } }, (res) => {
      resolve(res.statusCode);
    });
    req.on('error', (err) => resolve(`ERROR: ${err.code || err.message}`));
    req.on('timeout', () => { req.destroy(); resolve('TIMEOUT'); });
  });
}

// --- Generate capture summary ---
function generateSummary(outputDir, label, url, screenshots, gif, video, linkReport) {
  let summary = `# Capture Summary: ${label}\n\n`;
  summary += `| Field | Value |\n|---|---|\n`;
  summary += `| URL | ${url} |\n`;
  summary += `| Label | ${label} |\n`;
  summary += `| Timestamp | ${new Date().toISOString()} |\n\n`;

  summary += '## Screenshots\n\n';
  summary += '| File | Viewport | Size |\n|---|---|---|\n';
  for (const s of screenshots) {
    summary += `| ${s.name} | ${s.viewport} | ${formatBytes(s.size)} |\n`;
  }

  if (gif) {
    summary += `\n## Animated GIF\n\n`;
    summary += `| File | Frames | Size |\n|---|---|---|\n`;
    summary += `| ${gif.name} | ${gif.frames} | ${formatBytes(gif.size)} |\n`;
  }

  if (video) {
    summary += `\n## Video\n\n`;
    summary += `| File | Frames | Duration | Size |\n|---|---|---|---|\n`;
    summary += `| ${video.name} | ${video.frames} | ${video.duration} | ${formatBytes(video.size)} |\n`;
  }

  summary += `\n## Link Audit\n\n`;
  summary += `| Metric | Count |\n|---|---|\n`;
  summary += `| Total links | ${linkReport.total} |\n`;
  summary += `| Working | ${linkReport.working} |\n`;
  summary += `| Broken | ${linkReport.broken} |\n`;

  const summaryPath = path.join(outputDir, 'capture-summary.md');
  fs.writeFileSync(summaryPath, summary);
  console.log(`  ✓ Summary: capture-summary.md`);
}

// --- Utilities ---
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

// --- Main ---
async function main() {
  const opts = parseArgs();

  console.log(`\n=== Capturing: ${opts.label} ===`);
  console.log(`URL: ${opts.url}`);
  console.log(`Output: ${opts.output}`);
  console.log(`Sections: ${opts.sections.join(', ')}\n`);

  fs.mkdirSync(opts.output, { recursive: true });

  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
  });

  try {
    const page = await browser.newPage();

    console.log('1/4 Screenshots...');
    const screenshots = await captureScreenshots(page, opts.url, opts.output);

    console.log('2/4 Animated GIF...');
    const gif = await captureGif(page, opts.url, opts.output);

    console.log('3/4 Navigation video...');
    const video = await captureVideo(page, opts.url, opts.output, opts.sections);

    console.log('4/4 Broken link audit...');
    const linkReport = await checkBrokenLinks(page, opts.url, opts.output);

    generateSummary(opts.output, opts.label, opts.url, screenshots, gif, video, linkReport);

    console.log(`\n=== ${opts.label} capture complete ===\n`);
  } finally {
    await browser.close();
  }
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
