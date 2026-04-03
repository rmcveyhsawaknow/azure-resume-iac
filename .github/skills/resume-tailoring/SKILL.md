---
name: resume-tailoring
description: "Generate a job-specific styled PDF resume and application form guide. Use when: applying for a job, tailoring resume to a job description, generating resume PDF, filling out job application forms, creating application guide. Inputs: job description, POC notes, requirements. Outputs: styled PDF resume matching resume.ryanmcvey.me color scheme, copy-paste application form guide."
argument-hint: "Path to filled-in job-input file (e.g., tmp/job-input.md)"
---

# Resume Tailoring Skill

Generate a professional, job-specific PDF resume styled after the live resume site ([resume.ryanmcvey.me](https://resume.ryanmcvey.me)) and a copy-paste application form guide — tailored to a specific job requisition.

## When to Use

- Applying for a new job and need a tailored resume PDF
- Filling out an online job application form (UltiPro, Workday, Taleo, etc.)
- Need to align resume content to a specific job description's keywords and requirements
- Want to generate both a styled resume PDF and a structured form-fill guide in one workflow

## Prerequisites

The user must provide a filled-in job input file. Copy [the template](./templates/job-input-template.md) to `tmp/job-input.md` and complete all sections before invoking this skill. Alternatively, the user may provide job details inline in the chat prompt or via a GitHub Issue created from the resume-generation issue template.

## Procedure

### Step 1 — Install Tools

Install document conversion and PDF generation tools. These are required in the Codespace environment (Debian 12):

```bash
sudo apt-get update -qq && sudo apt-get install -y -qq pandoc poppler-utils libglib2.0-0 libpango-1.0-0 libpangocairo-1.0-0 libpangoft2-1.0-0 libharfbuzz0b libfontconfig1 libcairo2
pip3 install --break-system-packages weasyprint
```

Verify: `weasyprint --version` should return without error.

### Step 2 — Parse Binary Resume Files

Convert any `.docx` and `.pdf` resume files in `tmp/` to plain text for content extraction:

```bash
# For each .docx file:
pandoc "tmp/<filename>.docx" -t plain --wrap=none -o "tmp/<filename>.txt"

# For each .pdf file:
pdftotext "tmp/<filename>.pdf" "tmp/<filename>.txt"
```

Read all generated `.txt` files to extract work history, skills, certifications, education, and other content not present on the live site.

### Step 3 — Read Live Site Content

Read `frontend/index.html` to extract the current resume content:
- Work experience entries (job titles, companies, dates, descriptions)
- Certifications (names, badge images, dates)
- Skills and expertise areas
- Education entries
- Projects section
- Professional summary / about text

This is the **primary content source**. Binary resume files from Step 2 provide supplementary detail (additional roles, deeper bullet points, cover letter language).

### Step 4 — Read Job Input

Read the user's filled-in job input file (default: `tmp/job-input.md`). Extract:
- **Job title and company** — for resume header title alignment
- **Full job description** — for keyword extraction and requirement mapping
- **POC/referral notes** — for contextual framing in summary and role descriptions
- **Requirements and expectations** — for positioning statements
- **Certification details** — exact cert numbers and dates for the form guide
- **Target resume length** — 2 pages (concise) or 3-4 pages (comprehensive)

### Step 5 — Merge and Align Content

Consolidate content from Steps 2-4:

1. **Extract keywords** from the job description (required skills, desired skills, tools, frameworks, compliance standards, certifications)
2. **Map experience to requirements** — identify which roles and bullet points address each requirement
3. **Prioritize content** — lead with the most JD-relevant accomplishments per role
4. **Fill gaps** — use binary resume content to surface additional relevant experience not on the live site
5. **Frame the narrative** — weave POC meeting context and company-specific positioning into summary and role descriptions

### Step 6 — Generate Styled HTML Resume

Create `tmp/<company>-resume.html` using the [resume template](./templates/resume-template.html) as the structural basis.

**Design tokens** (from the live site — see [design-tokens.md](./references/design-tokens.md)):

| Token | Value | Usage |
|-------|-------|-------|
| Gold | `#C5A028` | Links, accents, date text, section divider borders |
| Navy | `#00205B` | Section headings, company names, clearance bar |
| Crimson | `#BF0A30` | Header name underline border |
| Text | `#46535d` | Body text |
| Heading | `#313131` | Role titles, cert names, school names |
| Background | `#FFFFFF` | Print-friendly white |

**Fonts**: Embed OpenSans from `frontend/css/fonts/opensans/` via `file://` URLs in `@font-face` declarations (Regular 400, Semibold 600, Bold 700, ExtraBold 800, Light 300, Italic 400i).

**Resume sections** (in order):
1. **Header** — Name, aligned title (related to but not identical to the job title), contact info, links
2. **Clearance bar** — U.S. Citizen, USMC Veteran, clearance status (if applicable)
3. **Professional Summary** — 3-5 sentences merging career narrative with JD-specific positioning
4. **Core Competencies** — 3-column grid of keyword-rich items mapping to JD required/desired skills
5. **Professional Experience** — Roles with JD-aligned bullet points; consolidate progressive roles at same company
6. **Certifications** — Active certs with dates/numbers; foundational expired certs noted as background
7. **Education** — Formal and military training
8. **Technical Skills** — Categorized 2-column grid (Cloud Platforms, AI/ML, IaC & CI/CD, Security & Compliance, Observability, Networking & Identity)
9. **Footer** — Links to resume site, GitHub, LinkedIn

### Step 7 — Generate PDF

Convert HTML to PDF using weasyprint:

```bash
weasyprint tmp/<company>-resume.html tmp/<output-filename>.pdf
```

**Verify the output:**
1. Check page count matches target (2 or 3-4 pages): `pdfinfo tmp/<output-filename>.pdf | grep Pages`
2. Verify text is selectable/extractable (ATS-compatible): `pdftotext tmp/<output-filename>.pdf - | head -20`
3. Verify JD keyword coverage: `pdftotext tmp/<output-filename>.pdf - | grep -ioE '<keyword1>|<keyword2>|...' | sort -u`

If page count is wrong, adjust font sizes (body 9-9.5pt range), margins (0.5-0.65in), or content density.

### Step 8 — Generate Application Form Guide

Create `tmp/<company>-application-guide.md` using the [application guide template](./templates/application-guide-template.md) as the structural basis.

For each section, substitute content from Steps 2-5:

1. **Work Experience** — Up to 4 entries (most relevant roles), each with:
   - Job Title, Company, Location, From/To dates
   - Description tailored to JD keywords (verify ≤ 2000 characters)
2. **Education** — Entries with School, Degree/Level, Major, dates, Description (verify ≤ 1500 characters)
3. **Behaviors** — Select 4-5 from dropdown options and explain alignment to role
4. **Motivations** — Select 4-5 from dropdown options and explain alignment to role
5. **Licenses & Certifications** — From user's cert details (exact names, numbers, dates)
6. **Links** — Resume site, GitHub, LinkedIn, Microsoft Learn (or other profiles)

**Validate character counts** for all description fields before finalizing.

### Step 9 — Final Verification Checklist

- [ ] PDF opens correctly and is the target page count
- [ ] All JD required-skill keywords appear in the PDF text
- [ ] PDF text is selectable (not rasterized) for ATS compatibility
- [ ] Colors render: Gold accents, Navy headings, Crimson header border
- [ ] Work Experience descriptions ≤ 2000 characters each
- [ ] Education descriptions ≤ 1500 characters each
- [ ] Application guide has all 6 sections populated
- [ ] Certification numbers and dates match user-provided data
- [ ] No PII errors (correct name, email, phone, address)
- [ ] Output files listed to user with paths

## Output Files

All output files are written to `tmp/`:

| File | Description |
|------|-------------|
| `tmp/<company>-resume.html` | Source HTML (can be opened in browser for preview/adjustment) |
| `tmp/<OutputFilename>.pdf` | Final styled PDF resume for upload |
| `tmp/<company>-application-guide.md` | Copy-paste guide for all application form fields |

## Content Sources

See [resume-sources.md](./references/resume-sources.md) for the complete map of where resume content lives in this repository.

## Design Reference

See [design-tokens.md](./references/design-tokens.md) for the full color scheme, typography, and layout specifications derived from the live resume site.
