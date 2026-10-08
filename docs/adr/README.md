# Architecture Decision Records

One file per durable decision, for anyone asking "why is it this way?". Read the in-force ones before designing a change.

## What earns an ADR

All three, or there is no ADR:

1. **Hard to reverse**: changing your mind later costs real work.
2. **Surprising without context**: a reader of the code would ask why.
3. **A real trade-off**: a genuine alternative existed and lost for specific reasons.

## What an ADR is

A decision and its reason. Not a specification, not a design.

```md
# {The choice, as a statement: "Use X for Y"}

- Date: YYYY-MM-DD
- Supersedes: —

{One paragraph. What forced a choice, what we chose, and why the alternative lost.}
```

Optional, only when they add something: `## Rejected` (alternatives likely to be proposed again) and `## Consequences` (effects that are not obvious). Requirements, scenarios, interfaces, layouts, and task lists never belong here; they live in `openspec/specs/` and the change's `design.md`. One decision per file.

## Rules

- File names are `NNNN-kebab-title.md`: four digits, repository-wide, increasing, never reused.
- **Accepted ADRs are immutable.** An ADR is accepted once it is on the main branch; while it exists only on a feature branch it is a draft and can be revised. To overturn an accepted one, add a new ADR whose `Supersedes:` field names it, and leave the old file alone.
- An ADR is in force unless a later ADR's `Supersedes:` names it.

The pre-commit hook rejects edits to accepted ADRs, and ADRs that contain `Requirement:` or `Scenario:` headings.

<!-- managed-by: openbackbone (replaced on upgrade; delete this line to keep your edits) -->
