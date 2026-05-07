---
description: "Write or update the changelog for the current session. Appends to today's file if it exists, creates a new one otherwise. Always English, always matches the project's changelog format. Uses conversation context and file metadata to infer the date and content."
---

Write a changelog entry for the current session following the Task Manager project conventions.

## Instructions for the agent

1. **Determine the session date** — use the date provided in the system context. Today is inferred automatically; do not ask unless truly ambiguous.

2. **Identify the target file**:
   - Check `docs/changelogs/` for a file named `changelog_DDMMYYYY.md` matching today's date
   - If it **exists** → append new sections (do not rewrite the file header or existing entries)
   - If it **does not exist** → create it with the full header

3. **Gather content from this conversation**:
   - Which files were created or modified?
   - What features, fixes, or refactors were implemented?
   - Were there any problems solved with a specific approach?

4. **Write the entry** using this exact format:

```markdown
# Changelog – DD/MM/YYYY

## Summary

<One paragraph describing the session focus.>

---

## [Category] Short title

### Added / Changed / Fixed / Removed

<Description. Use tables for structured data.>
```

Available categories: `[Feature]`, `[Fix]`, `[Refactor]`, `[Testing]`, `[Tooling]`, `[Docker]`, `[Backend]`, `[Frontend]`, `[Angular]`, `[DB]`, `[Auth]`, `[Docs]`

5. **Output language**: English only — no exceptions.

6. **Never overwrite** existing content. If appending, add a `---` separator before the new section if it follows existing content on the same day.
