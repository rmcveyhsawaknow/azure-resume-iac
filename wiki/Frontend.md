# Frontend

> A vanilla HTML/CSS/JS resume website — no frameworks, no build step, just static files served from Azure Storage.

**Source:** [`frontend/`](https://github.com/rmcveyhsawaknow/azure-resume-iac/tree/main/frontend)

---

## Overview

The frontend is a single-page resume website. It loads directly from Azure Storage's static website hosting (`$web` container) and is fronted by Cloudflare CDN for TLS and caching.

There is **no build step** — the files in `frontend/` are uploaded as-is to Azure Storage by the CI/CD workflow.

## File Layout

```
frontend/
├── index.html               # Single-page resume (semantic HTML5)
├── main.js                  # Visitor counter fetch + text rotation animation
├── config.js                # Runtime config injected by CI/CD
├── js/
│   ├── azure_app_insights.js  # App Insights SDK bootstrap (reads config.js)
│   ├── jquery-1.10.2.min.js   # jQuery (local copy)
│   ├── jquery-migrate-1.2.1.min.js
│   └── modernizr.js          # Feature detection
├── css/
│   ├── default.css           # Core styles
│   ├── layout.css            # Grid/flex layout
│   ├── media-queries.css     # Responsive breakpoints
│   └── magnific-popup.css    # Lightbox plugin
├── images/                   # Profile photo, cert badges, overlays
└── media/                    # Additional media assets
```

## How the Visitor Counter Works

1. **`config.js`** is generated at deploy time by the CI/CD workflow. It provides the Function App base URL, App Insights connection string, Clarity project ID, and stack metadata:

   ```javascript
   const defined_FUNCTION_API_BASE = 'https://cus1-resumectr-prod-v12-fa.azurewebsites.net';
   const defined_APPINSIGHTS_CONNECTION_STRING = '...';
   const defined_STACK_VERSION = 'v12';
   const defined_STACK_ENVIRONMENT = 'prod';
   ```

2. **`main.js`** reads `defined_FUNCTION_API_BASE` and calls `fetch()` to `/api/GetResumeCounter`
3. The Function App returns `{ "id": "1", "count": N }` — `main.js` reads `data.count` and displays it on the page
4. The counter value is also displayed in the page footer alongside stack information

## Text Rotation

`main.js` includes a `TxtRotate` class that cycles through an array of phrases in the header banner with a typing animation effect. The phrases are defined in a `data-rotate` attribute on the HTML element.

## Monitoring

- **Application Insights** — `azure_app_insights.js` initializes the App Insights SDK using the connection string from `config.js`
- **Microsoft Clarity** — if `defined_CLARITY_PROJECT_ID` is set in `config.js`, Clarity is loaded for end-user session recording

## Libraries

| Library | Version | Notes |
|---|---|---|
| jQuery | 1.10.2 | Several major versions behind (functional, low-priority upgrade) |
| jQuery Migrate | 1.2.1 | Compatibility shim |
| Font Awesome | 4.x | Icon library (local copy, not CDN) |
| Modernizr | Custom build | Feature detection |

All libraries are loaded from local copies — no external CDN dependencies at runtime.

## Responsive Design

The site uses a combination of CSS grid and flexbox with breakpoints in `media-queries.css`. Semantic HTML5 elements (`<header>`, `<section>`, `<footer>`, etc.) structure the page.

---

## See also

- [Backend](Backend) — the Function App API that the counter calls
- [Configuration](Configuration) — how `config.js` is generated at deploy time
- [Deployment](Deployment) — how frontend files are uploaded to Azure Storage
- [Architecture](Architecture) — where the frontend fits in the system
