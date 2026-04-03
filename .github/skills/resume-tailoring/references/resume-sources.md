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

Located in `tmp/` (extracted during skill Step 2):

| File | Format | Variant | Key Differentiator |
|------|--------|---------|--------------------|
| `Ryan McVey_Resume_InsightArchitect_2025.docx` | DOCX | Insight Architect | Enterprise architecture focus, data analytics emphasis |
| `Ryan McVey_Resume_PrivateSector_2024.docx` | DOCX | Private Sector | Aprimo/Teradata progressive career, marketing tech |
| `Ryan McVey_Resume_PublicSectorLeadership_2024.pdf` | PDF | Public Sector Leadership | Government leadership, policy, NASCIO award emphasis |
| `Ryan McVey_Resume_PublicSector_2026.pdf` | PDF | Public Sector 2026 | Most current public sector roles, forward-looking |

### Extraction Commands

```bash
# DOCX → text
pandoc "tmp/Ryan McVey_Resume_InsightArchitect_2025.docx" -t plain --wrap=none -o tmp/insight-architect.txt

# PDF → text
pdftotext "tmp/Ryan McVey_Resume_PublicSector_2026.pdf" tmp/public-sector-2026.txt
```

## Certification Data

Authoritative certification details (update as certs renew):

| Certification | Issuer | Credential ID | Cert Number | Earned | Expires |
|--------------|--------|---------------|-------------|--------|---------|
| Azure Administrator Associate (AZ-104) | Microsoft | E3A915D12B7A92CF | 2072979 | Jul 2023 | Jul 2025 |
| Azure Fundamentals (AZ-900) | Microsoft | H794-6652 | — | Feb 2021 | No Expiry |
| Azure AI Fundamentals (AI-900) | Microsoft | I551-4370 | — | Sep 2021 | No Expiry |
| Azure Data Fundamentals (DP-900) | Microsoft | I545-2254 | — | Sep 2021 | No Expiry |

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
