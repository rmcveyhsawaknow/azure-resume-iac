# Design Tokens — resume.ryanmcvey.me

Visual identity reference for PDF resume generation. All values derived from the live site's CSS (`frontend/css/layout.css`, `frontend/css/default.css`, `frontend/css/fonts.css`).

## Color Palette

| Token | Hex | CSS Variable | Usage |
|-------|-----|-------------|-------|
| **Gold** | `#C5A028` | `--gold` | Links, accents, date text, section divider borders, CTA buttons |
| **Dark Navy** | `#00205B` | `--navy` | Section headings, company names, skill categories, clearance bar border |
| **Crimson** | `#BF0A30` | `--crimson` | Header name underline border, active nav state, counter text |
| **Text** | `#46535d` | `--text` | Body text, secondary descriptions |
| **Heading** | `#313131` | `--heading` | Role titles, certification names, school names |
| **Light BG** | `#f4f5f7` | `--light-bg` | Clearance bar background, callout boxes |
| **Meta** | `#7A7A7A` | — | Certification meta text (dates, numbers) |
| **White** | `#FFFFFF` | — | Print background (site uses dark sections; PDF uses white for print) |

## Typography

| Element | Font | Weight | Size | Line Height |
|---------|------|--------|------|-------------|
| Body | OpenSans | 400 (Regular) | 9.2pt | 1.42 |
| Section Title | OpenSans | 700 (Bold) | 10.5pt | — |
| Role Title | OpenSans | 700 (Bold) | 10pt | — |
| Candidate Name | OpenSans | 800 (ExtraBold) | 22pt | 1.1 |
| Subtitle | OpenSans | 600 (Semibold) | 10.5pt | — |
| Company Name | OpenSans | 600 (Semibold) | 9pt | — |
| Dates | OpenSans | 600 (Semibold) | 8.5pt | — |
| Competency Item | OpenSans | 400 (Regular) | 8.5pt | 1.5 |
| Skills Category | OpenSans | 700 (Bold) | 8.5pt | — |
| Skills List | OpenSans | 400 (Regular) | 8.5pt | 1.45 |
| Cert Name | OpenSans | 600 (Semibold) | 8.8pt | 1.5 |
| Cert Meta | OpenSans | 400 (Regular) | 8pt | — |
| Footer | OpenSans | 400 (Regular) | 7.5pt | — |

### Font Files

Located at `frontend/css/fonts/opensans/`:

| Weight | File |
|--------|------|
| 300 Light | `OpenSans-Light-webfont.ttf` |
| 400 Regular | `OpenSans-Regular-webfont.ttf` |
| 400 Italic | `OpenSans-Italic-webfont.ttf` |
| 600 Semibold | `OpenSans-Semibold-webfont.ttf` |
| 700 Bold | `OpenSans-Bold-webfont.ttf` |
| 800 ExtraBold | `OpenSans-ExtraBold-webfont.ttf` |

Embed via `@font-face` with `file:///workspaces/azure-resume-iac/frontend/css/fonts/opensans/<filename>` URLs.

## Page Layout

| Property | Value |
|----------|-------|
| Page size | US Letter (8.5 × 11 in) |
| Margins | 0.55in top/bottom, 0.6in left/right |
| Target pages | 2 (concise) or 3-4 (comprehensive) |
| Columns | Single column with flex grids for competencies (3-col) and skills (2-col) |

### Tuning Page Count

If the generated PDF has too many or too few pages:

- **Reduce pages**: Decrease body font to 9pt, reduce margins to 0.5in, tighten `margin-bottom` on `.role` to 6pt
- **Increase pages**: Increase body font to 9.5pt, increase margins to 0.65in, add more bullet points per role

## Section Styling

| Section | Background | Text Color | Border |
|---------|-----------|-----------|--------|
| Header | White | Navy (name), Gold (subtitle) | Crimson 2.5pt bottom border |
| Clearance Bar | `#f4f5f7` | Navy (bold), Text (normal) | Navy 3pt left border |
| Section Title | White | Navy | Gold 1.5pt bottom border |
| Role | White | Heading (title), Gold (dates), Navy (company), Text (body) | — |
| Footer | White | `#999` | `#ddd` 1pt top border |

## Site Section Backgrounds (for reference, not used in PDF)

The live site alternates dark (#2B2B2B) and light (#b0bac5) sections. The PDF uses **white background** throughout for print compatibility, with color accents from the palette above.
