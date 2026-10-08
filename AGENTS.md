# Engineering workflow (openbackbone)

This project is maintained through a small set of living documents. Each answers one question, and nothing else. Read the relevant ones before you design; keep them true when you change the system.

| Document | Answers | Changes when |
|---|---|---|
| `ROADMAP.md` | What will we build next? | Plans change; an item is removed when it ships |
| `GLOSSARY.md` | What do we call things? | A domain term is settled, the moment it is settled |
| `openspec/specs/` | What does the system do? | A change is archived (delta specs merge in) |
| `docs/architecture.md` | How is the system put together today? | Structure changes; rewritten in place |
| `docs/adr/` | Why is it this way? | A decision passes the ADR bar; append-only |
| `README.md` | How does a newcomer use it? | Anything a newcomer does or sees changes |

Keep each document out of the others' business: no behavior in the glossary, no rationale in the architecture overview, no requirements or designs in an ADR, no plans in the README.

## Changes

- **Large changes go through OpenSpec**: new capabilities, public interface or data model changes, new dependencies, cross-module work. The default schema is `spec-driven-with-impact`: proposal → specs → design → impact → tasks, then apply, verify, archive. Start with the `openspec-propose` skill.
- **Small changes go straight in**: typos, small bugs, local refactors. If one of them makes a living document untrue, fix that document in the same commit.
- **Spikes take the light path**: `--schema minimalist` (specs → tasks) or no process. A spike that graduates returns to the full pipeline; spike code is not promoted as-is.
- **The impact step is the point**: it states what the change does to ADRs, glossary, architecture, roadmap, and README. `Planned` entries become tasks in the final "Living documents" group, and a change is not archived while any of them is open.

## Language

Use `GLOSSARY.md` terms exactly as defined, in specs, docs, code identifiers, and conversation, and never a word it lists under `_Avoid_`. When a needed term is missing or used inconsistently, settle it with the user through the `domain-modeling` skill and write it down before going on.

## Decisions

An ADR records one decision and its reason, usually in a paragraph. Write one only when the decision is hard to reverse, surprising without context, and the result of a real trade-off; all three. Everything else stays in the change's `design.md`. An ADR that lists requirements, interfaces, or steps has become a spec: cut it back.

Accepted ADRs are immutable. An ADR is accepted once it is on the main branch; while it exists only on a feature branch it is a draft and can be revised. Overturn an accepted one by adding a new ADR whose `Supersedes:` field names it. An ADR is in force unless a later one supersedes it. See `docs/adr/README.md`.

## Roadmap

`ROADMAP.md` only looks forward. A proposal names the roadmap item it delivers, or says why the work was unplanned. When the change ships, the item is removed; the history is the OpenSpec archive.

## Working habits

- Prefer a diagram, table, or tree over long prose when explaining structure or flow.
- Create commits, branches, and merges only when asked.
