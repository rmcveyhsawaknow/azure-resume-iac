# Resume Source Content Map

This reference documents all locations where candidate resume content can be found. The skill reads from these sources to build a comprehensive, tailored resume.

## Primary Source: Live Site

| Source | Path | Content |
|--------|------|---------|
| HTML resume | `frontend/index.html` | Canonical resume: roles, certifications, skills grid, education, summary |
| JavaScript | `frontend/main.js` | Visitor counter API call (not resume content) |
| Site config | `frontend/config.js` | API endpoint configuration |

### Sections in `index.html`

| HTML ID / Class | Content |
|-----------------|---------|
| `#about` | Professional summary, location, clearance notice |
| `#experience` / `.role` | Work experience roles with title, company, dates, bullet points |
| `#certifications` | Certification cards with name, issuer, dates, credential IDs |
| `#education` | Degree entries with school, dates, details |
| `#skills` | Technical skills organized by category |
| `#awards` | Awards (e.g., NASCIO 2020) |
| `.counter-number` | Visitor counter display (not resume content) |

## Secondary Sources: Binary Resumes

The user places resume files into `tmp/` before invoking the skill. The skill dynamically discovers all `.pdf`, `.docx`, and `.doc` files — no specific filenames are required. These provide supplementary detail beyond the live site (additional roles, deeper bullet points, cover letter language).

**Supported formats:** `.pdf` (converted via `pdftotext`), `.docx` / `.doc` (converted via `pandoc`)

**Typical resume variants a user might provide:**

| Variant | Key Differentiator |
|---------|--------------------|
| Insight / Consulting focus | Enterprise architecture, data analytics, client delivery |
| Private Sector focus | Progressive SaaS operations career, cloud migration |
| Public Sector Leadership | Government leadership, policy, NASCIO award emphasis |
| Public Sector (current) | Most recent roles, forward-looking positioning |

> **Note:** `tmp/` is gitignored and ephemeral. Binary resumes contain PII and are never committed to the repository.

## Certification Data

Authoritative certification details — **single source of truth** for all resume tailoring runs. Update this table as certifications renew or new ones are earned. The skill's Step 4 pre-fills the Certification Details section of `job-input.md` from this data.

### Active Certifications

| Certification | Issuer | Cert Number | Earned | Expires |
|--------------|--------|-------------|--------|---------|
| Azure Solutions Architect Expert | Microsoft | 32AB75-C5C6KA | Dec 2021 | Dec 2026 |
| Azure AI Engineer Associate | Microsoft | 5FAE84-038M4E | Mar 2024 | Mar 2027 |
| Azure Data Scientist Associate | Microsoft | DAF19E-4A2F44 | Apr 2024 | Apr 2027 |
| Azure AI Fundamentals | Microsoft | 545E8I-2DD55F | Feb 2024 | No Expiry |

### Retired / Expired Certifications (Historical)

These are no longer active but may be referenced as foundational background on resumes:

| Certification | Issuer | Credential ID | Earned | Expired |
|--------------|--------|---------------|--------|---------|
| Azure Administrator Associate (AZ-104) | Microsoft | E3A915D12B7A92CF | Jul 2023 | Jul 2025 |
| Azure Fundamentals (AZ-900) | Microsoft | H794-6652 | Feb 2021 | No Expiry (retired from active use) |
| Azure AI Fundamentals (AI-900) | Microsoft | I551-4370 | Sep 2021 | No Expiry (superseded by 2024 renewal) |
| Azure Data Fundamentals (DP-900) | Microsoft | I545-2254 | Sep 2021 | No Expiry (foundational) |
| NERC Reliability Coordinator | NERC | — | Jul 2013 | Past / Not Active |

### Military Training Equivalencies (MOS-5974)

Foundational credentials mapped from USMC MOS-5974 via [Marine Corps COOL](https://www.cool.osd.mil/usmc/moc/index.html?moc=5974&tab=cred). Not individually credentialed but represent the breadth of the military technical curriculum:

- CompTIA A+, Network+, Security+
- Cisco Certified Network Associate (CCNA)
- Microsoft Certified: Windows Server Hybrid Administrator Associate
- CISSP, CISM, EC-Council CND

## Contact & Profile

| Field | Value |
|-------|-------|
| Full Name | Ryan McVey |
| Address | 201 N Muessing St, Indianapolis, IN |
| Email | rjmcvey2013@gmail.com |
| Phone | 317-441-2052 |
| LinkedIn | https://www.linkedin.com/in/ryan-mcvey-897008228/ |
| Site | https://resume.ryanmcvey.me |

## Education

| Institution | Degree | Dates | Status |
|------------|--------|-------|--------|
| Western Governors University (WGU) | BS, IT — Security Emphasis | 2012 – 2016 | Incomplete (capstone + 2 courses remaining) |
| Marine Corps Communications-Electronics School (MCCES) | Certificate, Data Network Specialist | 2006 – 2007 | Completed |

## Career History (Chronological)

| # | Role | Organization | Dates |
|---|------|-------------|-------|
| 1 | Technology Architect | Indiana Office of Technology (IOT) | Oct 2018 – Present |
| 2 | Senior Technical Consultant → Director, Managed Services | Aprimo / Teradata | Mar 2012 – Apr 2018 |
| 3 | Contract Energy Analyst | MISO / Entergy | Apr 2013 – Dec 2013 |
| 4 | Data Communications Specialist | MTC Services (JINTACCS) | Apr 2007 – Nov 2007 |
| 5 | Data Network Specialist (MOS 0651) | United States Marine Corps | Oct 2005 – Jul 2009 |

## Awards

| Award | Year | Details |
|-------|------|---------|
| NASCIO State IT Recognition Award | 2020 | Enhanced Research Environment (cross-agency, COVID-era) |
