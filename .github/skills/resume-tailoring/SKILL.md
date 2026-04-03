---
name: resume-tailoring
description: "Generate a job-specific styled PDF resume, candidate briefing, and application form guide. Use when: applying for a job, tailoring resume to a job description, generating resume PDF, preparing for interviews, filling out job application forms, creating application guide. Inputs: job description, POC notes, requirements. Outputs: styled PDF resume matching resume.ryanmcvey.me color scheme, candidate briefing PDF for interview prep, copy-paste application form guide."
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

The user provides job details through one of three methods:
1. **Pre-filled job input file** — Copy [the template](./templates/job-input-template.md) to `tmp/job-input.md` and complete all sections before invoking this skill.
2. **Inline in chat** — Provide job title, company, full job description, and any POC notes directly in the chat prompt. The skill will auto-create and populate `tmp/job-input.md`.
3. **GitHub Issue** — Create an issue from the `resume-generation.yml` template and reference it when invoking the skill. The skill will fetch the issue body and populate `tmp/job-input.md`.

Additionally, the user should place any binary resume files (`.pdf`, `.docx`, `.doc`) into `tmp/` before invoking the skill. These provide supplementary content beyond the live site. The skill discovers all supported files automatically — no specific filenames are required.

## Procedure

### Step 1 — Install Tools & Prepare Workspace

Install document conversion and PDF generation tools. These are required in the Codespace environment (Debian 12):

```bash
mkdir -p tmp/
sudo apt-get update -qq && sudo apt-get install -y -qq pandoc poppler-utils libglib2.0-0 libpango-1.0-0 libpangocairo-1.0-0 libpangoft2-1.0-0 libharfbuzz0b libfontconfig1 libcairo2
pip3 install --break-system-packages weasyprint
```

Verify: `weasyprint --version` should return without error.

> **Note:** The `tmp/` directory is gitignored and ephemeral. All resume inputs (binary resumes, job descriptions) and outputs (PDFs, HTML, application guides) live here and are never committed to the repository.

### Step 2 — Discover & Parse Binary Resume Files

Dynamically discover all resume files the user has placed in `tmp/`. The skill is agnostic to filenames — it processes whatever `.pdf`, `.docx`, or `.doc` files are present:

```bash
# Discover and convert all supported resume files in tmp/
for f in tmp/*.docx tmp/*.doc; do
  [ -f "$f" ] && pandoc "$f" -t plain --wrap=none -o "${f%.*}.txt"
done

for f in tmp/*.pdf; do
  [ -f "$f" ] && pdftotext "$f" "${f%.*}.txt"
done
```

Read all generated `.txt` files to extract work history, skills, certifications, education, and other content not present on the live site.

> **No hardcoded filenames.** The user drops their resume variants (any number, any naming convention) into `tmp/` before invoking the skill. The skill discovers and converts them all.

### Step 3 — Read Live Site Content

Read `frontend/index.html` to extract the current resume content:
- Work experience entries (job titles, companies, dates, descriptions)
- Certifications (names, badge images, dates)
- Skills and expertise areas
- Education entries
- Projects section
- Professional summary / about text

This is the **primary content source**. Binary resume files from Step 2 provide supplementary detail (additional roles, deeper bullet points, cover letter language).

### Step 4 — Collect & Read Job Input

The job input file (`tmp/job-input.md`) captures all job-specific details in a structured format. The skill supports three input modes:

1. **Pre-filled file** — If `tmp/job-input.md` already exists and is filled in, read it directly.
2. **Auto-populate from user input** — If `tmp/job-input.md` does not exist, copy the template from `.github/skills/resume-tailoring/templates/job-input-template.md` to `tmp/job-input.md`, then populate it using details the user provided in the chat prompt (job title, company, JD text, POC notes, requirements).
3. **Auto-populate from GitHub Issue** — If the user references a GitHub Issue created from the `resume-generation.yml` template, fetch the issue body text via `gh issue view <number> --json body`. That command returns the rendered markdown issue body, not inherently structured JSON form fields, so parse the markdown body using the expected template headings/sections before populating `tmp/job-input.md`. If actual issue form field data is available through GraphQL or another GitHub API surface, that may be used instead.

For modes 2 and 3, pre-fill the **Certification Details** section from the authoritative data in [resume-sources.md](./references/resume-sources.md) — the user only needs to confirm or adjust.

After `tmp/job-input.md` has been completed or normalized from the parsed issue markdown, extract:
- **Job title and company** — for resume header title alignment
- **Full job description** — for keyword extraction and requirement mapping
- **POC/referral notes** — for contextual framing in summary and role descriptions
- **Candidate Objectives & Interview Context** — structured sub-fields that drive the taskboard and briefing:
  - *Must-Haves* — non-negotiable requirements (compensation, clearance, location, benefits)
  - *Key Messages to Convey* — 3-6 bold statements the candidate must communicate; feeds the resume taskboard + briefing key messages
  - *Tools / Platforms / Tech Stack Priorities* — technologies to emphasize
  - *Questions for the Interviewer* — feeds the briefing "Prepared Questions" section
  - *Personal Context* — optional background (not included in any output files)
- **Interview Process & Contacts** — structured fields that drive the briefing header and contacts sections:
  - *Interview Round* — which stage of the interview pipeline (e.g., "Round 1 — Phone Screen", "Round 2 — Technical Panel"); defaults to "Initial Application" if not specified
  - *Interview Contacts* — table of people involved in the process (Name, Title, Role in Process, Email/Phone, Notes); also auto-populated from POC/Referral Notes when structured contacts aren't provided
- **Certification details** — exact cert numbers and dates for the form guide
- **Target resume length** — 2 pages (concise) or 3-4 pages (comprehensive)

### Step 5 — Merge and Align Content

Consolidate content from Steps 2-4:

1. **Extract keywords** from the job description (required skills, desired skills, tools, frameworks, compliance standards, certifications)
2. **Map experience to requirements** — identify which roles and bullet points address each requirement
3. **Prioritize content** — lead with the most JD-relevant accomplishments per role
4. **Fill gaps** — use binary resume content to surface additional relevant experience not on the live site
5. **Frame the narrative** — weave POC meeting context and company-specific positioning into summary and role descriptions
6. **Synthesize taskboard content** — distill "Key Messages to Convey" into 4-6 concise talking points for the resume taskboard's left column; generate 3-4 follow-up/action items for the right column
7. **Build briefing talking points** — from the competency alignment matrix and JD requirements, generate conversation starters, structured Q&A prompts, and the interviewer questions list for the candidate briefing PDF

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
5. **Interview Taskboard** *(print copy only — omit for ATS upload)* — Two-column panel: left column "Key Points for Interviewer" (4-6 ★ items from Key Messages), right column "Follow-Up & Notes" (3-4 ☐ checkbox items). Fills the page-1 gap between competencies and experience.
6. **Professional Experience** — Roles with JD-aligned bullet points; consolidate progressive roles at same company
7. **Certifications** — Active certs with dates/numbers; foundational expired certs noted as background
8. **Education** — Formal and military training
9. **Technical Skills** — Categorized 2-column grid (Cloud Platforms, AI/ML, IaC & CI/CD, Security & Compliance, Observability, Networking & Identity)
10. **Footer** — Links to resume site, GitHub, LinkedIn

> **ATS Note:** The taskboard (section 5) is intended for the candidate's printed interview copy. When uploading to an ATS portal, the agent should note that the taskboard adds visual richness but the PDF text remains fully selectable and keyword-rich.

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

### Step 8a — Generate Candidate Briefing PDF

Create `tmp/<company>-briefing.html` using the [candidate briefing template](./templates/candidate-briefing-template.html) as the structural basis.

Populate the template with content from Steps 2-5:

1. **Role Snapshot** — Company, position, location, compensation (from job-input.md)
2. **Job Posting Reference** — Posting URL (clickable), posted date, and source (from job-input.md Target Position fields). If URL is unavailable, note "URL not available — search company careers page." Gives the candidate one-glance access to the original listing.
3. **Interview Contacts** — Table of people involved in the interview process (Name, Title, Role in Process, Contact, Notes) from the "Interview Process & Contacts" section in job-input.md. For cold applications with no contacts, display: "No contacts identified — update before interview." Also extract any contacts mentioned in POC/Referral Notes into this table.
4. **Key Messages to Convey** — 4-6 items from "Key Messages to Convey" in job-input.md, tailored to JD alignment
5. **Competency Alignment Matrix** — 6-10 rows mapping major JD requirements to the candidate's specific experience/evidence
6. **Conversation Starters** — 4-6 agent-generated prompts based on JD + candidate experience ("When they ask about [topic]...")
7. **Prepared Questions** — From "Questions for the Interviewer" in job-input.md + agent-suggested additions (6-8 questions across categories)
8. **Notes area** — Blank lines for handwritten interview notes

**Interview Round** is displayed in the header metadata line alongside Company and Interview Date (e.g., "Booz Allen Hamilton | Round 2 — Technical Panel | Interview Date: ___"). When no round is specified, display "Initial Application / Round TBD."

Generate PDF:

```bash
weasyprint tmp/<company>-briefing.html tmp/Ryan_McVey_<Company>_<Role>_Candidate_Briefing.pdf
```

Verify: `pdfinfo tmp/Ryan_McVey_<Company>_<Role>_Candidate_Briefing.pdf | grep Pages` — target 2-3 pages.

> **This document is for the candidate's personal use only — not submitted to the employer.**

### Step 8b — Generate Application Form Guide

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

**Resume PDF:**
- [ ] PDF opens correctly and is the target page count
- [ ] All JD required-skill keywords appear in the PDF text
- [ ] PDF text is selectable (not rasterized) for ATS compatibility
- [ ] Colors render: Gold accents, Navy headings, Crimson header border
- [ ] Interview Taskboard present on page 1 (Key Points + Follow-Up columns)
- [ ] No PII errors (correct name, email, phone, address)

**Candidate Briefing PDF:**
- [ ] Briefing is 2-3 pages
- [ ] Job Posting Reference section has clickable URL (or "URL not available" note)
- [ ] Interview Contacts table populated (or "No contacts identified" placeholder for cold applications)
- [ ] Interview Round displayed in header meta line
- [ ] Competency Alignment Matrix has 6-10 rows with specific evidence
- [ ] Conversation Starters reference actual projects/achievements
- [ ] Prepared Questions are role-specific (not generic)

**Application Form Guide:**
- [ ] Work Experience descriptions ≤ 2000 characters each
- [ ] Education descriptions ≤ 1500 characters each
- [ ] Application guide has all 6 sections populated
- [ ] Certification numbers and dates match user-provided data

**All Outputs:**
- [ ] Output files listed to user with paths

## Output Files

All output files are written to `tmp/`:

| File | Description |
|------|-------------|
| `tmp/<company>-resume.html` | Source HTML (can be opened in browser for preview/adjustment) |
| `tmp/<OutputFilename>.pdf` | Final styled PDF resume for upload |
| `tmp/<company>-briefing.html` | Candidate briefing source HTML |
| `tmp/Ryan_McVey_<Company>_<Role>_Candidate_Briefing.pdf` | Interview-day prep document (personal use only) |
| `tmp/<company>-application-guide.md` | Copy-paste guide for all application form fields |

## Content Sources

See [resume-sources.md](./references/resume-sources.md) for the complete map of where resume content lives in this repository.

## Design Reference

See [design-tokens.md](./references/design-tokens.md) for the full color scheme, typography, and layout specifications derived from the live resume site.
