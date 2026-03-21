# NotebookLM Media Integration — Development & Testing Guide

This document describes the NotebookLM-generated digital assets integrated into the resume site and provides guidance for local development and testing in a GitHub Codespace.

## Overview

The resume site now includes multimedia content generated using [Google NotebookLM](https://notebooklm.google.com/):

| Asset | File | Location on Site |
|---|---|---|
| Audio Overview (2 min) | `McVey-Ryan_Professional_Overview-2-minutes.m4a` | About section, next to profile image |
| Audio Story (22 min) | `McVey-Ryan_Professional_Story-22-minutes.m4a` | About section, end (before Experience) |
| Infographic (Landscape) | `McVey-Ryan_Professional_Infographic-landscape.png` | Resume section, after Education (desktop) |
| Infographic (Portrait) | `McVey-Ryan_Professional_Infographic-portrait.png` | Resume section, after Education (mobile) |
| Presentation (PPTX) | `McVey-Ryan_Professional_Presentation.pptx` | Presentation section, download link |
| Presentation (PDF) | `McVey-Ryan_Professional_Presentation.pdf` | Presentation section, embedded viewer + download |

## File Structure

```
frontend/
├── media/
│   ├── .gitkeep
│   ├── McVey-Ryan_Professional_Overview-2-minutes.m4a
│   ├── McVey-Ryan_Professional_Story-22-minutes.m4a
│   ├── McVey-Ryan_Professional_Infographic-landscape.png
│   ├── McVey-Ryan_Professional_Infographic-portrait.png
│   ├── McVey-Ryan_Professional_Presentation.pptx
│   └── McVey-Ryan_Professional_Presentation.pdf
├── index.html          (updated — audio players, infographic, presentation section)
├── css/
│   ├── layout.css      (updated — new section styles)
│   └── media-queries.css (updated — responsive rules)
└── ...
```

## Technologies Used

- **HTML5 `<audio>`** — Native browser audio player with `controls` and `preload="metadata"` for the audio overview and narrative story. No JavaScript audio libraries required.
- **HTML5 `<picture>` with `<source media="...">`** — Responsive infographic that switches between landscape (desktop) and portrait (mobile) at the 768px breakpoint.
- **PDF `<iframe>` embed** — Browser-native PDF rendering for the slides viewer. No third-party PDF.js or viewer library needed.
- **CSS Flexbox** — Layout for audio players and download buttons.
- **Font Awesome icons** — `fa-headphones`, `fa-microphone`, `fa-download` (already loaded in the project).

## Setup — Adding Media Files

The media files are binary assets that must be added to `frontend/media/` before deployment. They are not included in the Git repository due to size.

1. Place all six files in `frontend/media/`:
   ```bash
   cp /path/to/assets/McVey-Ryan_Professional_Overview-2-minutes.m4a frontend/media/
   cp /path/to/assets/McVey-Ryan_Professional_Story-22-minutes.m4a frontend/media/
   cp /path/to/assets/McVey-Ryan_Professional_Infographic-landscape.png frontend/media/
   cp /path/to/assets/McVey-Ryan_Professional_Infographic-portrait.png frontend/media/
   cp /path/to/assets/McVey-Ryan_Professional_Presentation.pptx frontend/media/
   cp /path/to/assets/McVey-Ryan_Professional_Presentation.pdf frontend/media/
   ```

2. For production deployment, these files must be present in `frontend/media/` at build time. The CI/CD workflow uses `az storage blob upload-batch` to upload the entire `frontend/` directory to the Azure Storage Account `$web` container. Since the binary media files are **not committed to Git** (only `.gitkeep` is tracked), you must either:
   - **Option A (recommended):** Commit the media files via Git or Git LFS so they are included in the CI checkout.
   - **Option B:** Add a workflow step that retrieves the assets (e.g., from a separate storage location or release artifact) before the upload step.
   - **Option C:** Upload media files directly to the `$web` container via Azure CLI or Azure Portal, bypassing CI/CD.

## Local Development & Testing

### Quick Start (Codespace or Local)

```bash
cd frontend
python3 -m http.server 8080
# Or: npx serve .
```

Open `http://localhost:8080` in the browser.

### What to Verify

1. **Audio Overview Player** (About section)
   - Compact player appears below the profile photo
   - Play/pause, seek, and volume controls work
   - Label reads "2-Min Overview" with headphones icon

2. **Audio Narrative Player** (end of About section)
   - Full-width player with microphone icon and "22 min" duration label
   - Separated from content above by a subtle border
   - Audio controls are functional

3. **Infographic** (Resume section, after Education)
   - Desktop (≥768px): landscape version displayed
   - Mobile (<768px): portrait version displayed
   - Resize the browser window to confirm the `<picture>` source swap
   - Image is full-width with rounded corners and shadow

4. **Presentation Section** (after Projects)
   - Navigation bar includes "Presentation" link
   - PDF viewer iframe renders the slides
   - Audio player for accompaniment works
   - "Download PDF" and "Download PPTX" buttons download files
   - Buttons are styled consistently with the site theme

5. **Responsive Behavior**
   - At ≤767px: audio players stack vertically, download buttons go full-width
   - At ≤900px: presentation section header adjusts

### Testing with Chrome DevTools

- Use **Device Toolbar** (Ctrl+Shift+M) to test mobile breakpoints
- Check the **Network** tab to verify media files load (or 404 if not yet placed)
- Check the **Console** for any JavaScript errors

## Deployment Notes

### Cloudflare CDN Caching

Since the site is fronted by Cloudflare in Proxy mode, the `.m4a` audio files and `.pdf`/`.pptx` documents will be served through Cloudflare's CDN. This is ideal for large media files:

- Cloudflare automatically caches static assets based on file extension
- `.m4a`, `.pdf`, `.pptx`, and `.png` are all cacheable by default
- No additional Cloudflare configuration is needed
- The CDN edge network reduces latency for audio streaming

### Content-Type Headers

Azure Storage automatically sets MIME types for common extensions:
- `.m4a` → `audio/mp4`
- `.pdf` → `application/pdf`
- `.pptx` → `application/vnd.openxmlformats-officedocument.presentationml.presentation`
- `.png` → `image/png`

### No New Azure Resources

This integration requires **zero new Azure resources**. All media files are static assets served from the existing Azure Storage Account static website. The Cloudflare CDN layer provides edge caching and bandwidth optimization for the larger audio files.

## Git Considerations

Large binary files (`.m4a` audio especially) should be handled carefully:

- **Option A**: Commit directly if files are reasonably sized (<50 MB total)
- **Option B**: Use Git LFS for large audio files
- **Option C**: Upload media files directly to the Azure Storage Account via CLI/portal, bypassing Git

The `.gitkeep` file in `frontend/media/` ensures the directory structure exists in the repository regardless of which option is chosen.
