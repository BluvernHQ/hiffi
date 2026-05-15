---
name: caveman
description: Installs and uses the Caveman Cursor skill from JuliusBrussee/caveman via `npx skills add ... --skill caveman`. Use when the user asks to add/install/update the Caveman skill, runs that command, or says “use caveman skill”.
---

# Caveman

Install and use the Caveman skill from `https://github.com/JuliusBrussee/caveman`.

## When to use this skill

- The user asks to **install/add/update** the Caveman Cursor skill.
- The user references this command (or close variants):

```bash
npx skills add https://github.com/JuliusBrussee/caveman --skill caveman
```

Do not apply this skill for “caveman tone/style” requests unless the user explicitly wants the **Caveman skill** installed/used (not just a writing style).

## Workflow

### 1) Install (or update) the skill

Run:

```bash
npx skills add https://github.com/JuliusBrussee/caveman --skill caveman
```

Guidance:
- Prefer `npx` (no global install).
- If it fails, use the **full error output** to pick the fix.

### 2) Verify the skill is available

If the `skills` tool provides a list/inspect command, use it and confirm `caveman` is present. Otherwise, verify by invoking the skill in the way the Caveman repository README documents.

### 3) Use the Caveman skill

Treat the Caveman repository README as the source of truth for:
- Invocation format (slash command, prompt prefix, etc.)
- Flags/modes and configuration
- Expected output

If the user asks “how do I use it?”, provide:
- Install command
- How to invoke (from README)
- One short example invocation

## Troubleshooting checklist

- **Node/NPM**: ensure Node is installed; try a newer Node LTS if needed.
- **npx prompts/permissions**: re-run and accept prompts; avoid `sudo` unless required.
- **Network/GitHub**: retry; if GitHub blocked, suggest a mirror/offline path if supported by the tool.
- **Name conflict**: if `caveman` already exists, only overwrite/rename if the user requests it.

## Examples

Install/update:

```bash
npx skills add https://github.com/JuliusBrussee/caveman --skill caveman
```
