# Wiki Structure Best Practices

This reference distills GitHub Wiki conventions and community best practices into the structural rules the [`wiki-generator`](../SKILL.md) skill applies when planning and producing wiki pages.

## 1. Page set: scope, not sprawl

A great wiki sits between the README (intentionally short) and the source code (intentionally complete). Aim for **8–14 top-level pages** that cover:

- **What is this** — orientation for someone arriving cold
- **Get me running** — setup, dev environment, codespace
- **How it works** — architecture, data flow, key components
- **How to operate it** — CI/CD, deployment, rollback, runbooks
- **How to extend it** — contributing conventions, code style, testing
- **Reference material** — config schema, glossary, security model

Resist the temptation to mirror every doc 1:1. The wiki is an **index and overview**; the source files in `docs/` and inline READMEs remain the canonical detail.

## 2. File naming

GitHub Wiki maps filenames to titles by replacing hyphens with spaces. Stick to:

- **Hyphens for word separators** — `Getting-Started.md` → "Getting Started"
- **Title-Case** — `CI-CD.md`, `Project-Management.md`
- **Reserved files** — exactly `_Sidebar.md` and `_Footer.md` (leading underscore, capital S/F)
- **No special characters** — avoid `:`, `/`, `?`, `#`, `[`, `]`, `\`, spaces (use hyphens)
- **`Home.md`** is the landing page; this name is required

## 3. Linking

Two link styles work in wikis. Prefer the second for portability:

| Style | Example | Notes |
|---|---|---|
| Wiki-style | `[[Getting Started]]` | Resolves to `Getting-Started.md`. Concise but wiki-only. |
| Markdown | `[Getting Started](Getting-Started)` | No `.md` extension. Works in wiki and renders cleanly when previewed elsewhere. |

For links **out** of the wiki, use full HTTPS URLs to repo files (pinned to a branch or tag) so they don't break:

```markdown
See [`docs/ARCHITECTURE.md`](https://github.com/<owner>/<repo>/blob/main/docs/ARCHITECTURE.md)
for the canonical architecture diagram.
```

## 4. Navigation: `_Sidebar.md` and `_Footer.md`

`_Sidebar.md` is the **primary navigation** — it appears on every page. It should:

- Always include a link to `[[Home]]`
- Group links by theme (Overview, Build & Deploy, Reference, Project)
- Stay under ~30 links — beyond that, split into multiple wiki sections or rely on the auto-generated page list
- Avoid deep nesting — wiki sidebars don't render collapsible trees gracefully

`_Footer.md` is for **persistent context** — it appears at the bottom of every page. Use it for:

- A back-link to the source repository
- "Last updated" note (the publish workflow can stamp this)
- Where to file issues / how to contribute

## 5. Page anatomy

Every content page should follow the same shape so readers learn the pattern once:

1. **H1 title** matching the filename (e.g., `# Getting Started`)
2. **Purpose statement** — one sentence under the title
3. **Source link** — link back to the canonical repo file(s) the page summarizes
4. **Table of contents** — for pages over ~150 lines (use `<!-- toc -->` markers or hand-roll)
5. **Body** — sections with H2/H3 headings; avoid going deeper than H4
6. **See also** — 2–4 links to related wiki pages

## 6. Content principles

- **Summarize, don't duplicate.** If the architecture diagram lives in `docs/ARCHITECTURE.md`, the wiki page summarizes it and links there. Duplicating content guarantees drift.
- **Write for a stranger.** Assume the reader has never seen the repo. Define acronyms on first use; link to the [[Glossary]].
- **Show, then tell.** Lead with a diagram, code snippet, or example before launching into prose.
- **Time-stamp anything that ages.** Roadmaps, runbooks, and known issues should note the last review date.
- **No secrets, no PII.** The wiki is a publishing target — treat it with the same care as the public README.

## 7. Lifecycle

The wiki is **generated and published**, not manually edited:

1. The skill produces / refreshes `wiki/` from the current repo state
2. Changes go through PR review like any other code
3. Merging to the default branch triggers `publish-wiki.yml`, which mirrors `wiki/` → `<repo>.wiki.git`
4. The wiki UI is **read-only** for humans — direct edits will be overwritten on the next publish

Treat the wiki like a build artifact of your docs pipeline. This keeps the wiki authoritative and prevents the classic "everyone edits the wiki and nobody knows what's true" failure mode.

## 8. Accessibility & search

- Use real headings (`##`, `###`), not bold-as-heading — screen readers and the wiki search depend on heading structure
- Provide alt text for every image
- Prefer **descriptive link text** over "click here" — "[See the deployment guide](Deployment)" beats "click [here](Deployment)"
- Use tables for tabular data, not screenshots of tables

## 9. References

- [GitHub Docs: About wikis](https://docs.github.com/en/communities/documenting-your-project-with-wikis/about-wikis)
- [GitHub Docs: Adding or editing wiki pages](https://docs.github.com/en/communities/documenting-your-project-with-wikis/adding-or-editing-wiki-pages)
- [GitHub Docs: Creating a footer or sidebar for your wiki](https://docs.github.com/en/communities/documenting-your-project-with-wikis/creating-a-footer-or-sidebar-for-your-wiki)
- [GitHub Docs: Editing wiki content](https://docs.github.com/en/communities/documenting-your-project-with-wikis/editing-wiki-content)
- Daniele Procida, [Diátaxis documentation framework](https://diataxis.fr/) — the four documentation modes (tutorials, how-to, reference, explanation) that inform the page set above
