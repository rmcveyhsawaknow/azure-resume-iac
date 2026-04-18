# Wiki Input — Wiki Generator Skill (optional)

> **All fields are optional.** Fill in only what you want to override. Leave others blank to use the skill's defaults (audience = contributors + reviewers + new hires; full standard page set inferred from repo content).
>
> Copy this file to `tmp/wiki-input.md` before invoking the skill if you want to provide overrides.

---

## Target Audience

> Who is the primary reader of this wiki? Influences tone, depth, and which pages are emphasized.

- [ ] **Contributors** (developers extending the codebase) — *default*
- [ ] **Operators** (people deploying / running the system)
- [ ] **Reviewers** (auditors, security, compliance)
- [ ] **New hires** (zero context, need ramp-up)
- [ ] **External users** (consumers of the deployed product)

Other notes about the audience:

```
(Optional free text)
```

---

## Focus Areas

> Topics to expand with extra depth. The skill will allocate more detail and examples to these areas.

```
Examples:
- Deep-dive on the Bicep module structure (one section per module)
- Step-by-step blue/green deployment runbook with screenshots
- AgentGitOps workflow with end-to-end example issue lifecycle
```

(Your focus areas here)

---

## Excluded Sections

> Pages or topics to skip entirely. Use the standard page names from `references/wiki-structure-best-practices.md`.

```
Examples:
- Skills-and-Agents (no Copilot agent skills configured yet)
- Project-Management (project workflow not yet defined)
```

(Your exclusions here)

---

## Tone / Voice Override

> By default, the skill matches the existing voice in `docs/`. Override here if you want different.

- [ ] Formal / corporate
- [ ] Friendly / conversational *(default for personal projects)*
- [ ] Terse / reference-style
- [ ] Tutorial / step-by-step

---

## Custom Page Additions

> Pages outside the standard set that you want generated. Provide a name and a one-line scope.

| Page name (filename will be hyphenated) | Scope (one line) |
|---|---|
|  |  |
|  |  |

---

## Other Notes

```
Anything else the agent should know — e.g., "this repo is being prepared for open-source release,
emphasize licensing and contribution guidelines."
```
