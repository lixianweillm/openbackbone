# ADR Format

ADRs live in `docs/adr/` as `NNNN-slug.md`: four digits, one above the highest existing number, never reused.

## Template

```md
# {The choice, as a statement: "Use X for Y"}

- Date: YYYY-MM-DD
- Supersedes: —

{One paragraph. What forced a choice, what we chose, and why the alternative lost.}
```

That is a complete ADR. The value is that the decision and its reason are on record, not that sections are filled in.

## Optional sections

Add one only when it carries something the paragraph cannot:

- `## Rejected`: alternatives someone is likely to propose again, each with the reason it lost.
- `## Consequences`: downstream effects that are not obvious from the decision itself.

Nothing else. No Requirements, Scenarios, Design, Implementation, or Tasks sections: those belong in `openspec/specs/` and the change's `design.md`. An ADR longer than about 40 lines is almost always a design document; cut it back to the choice and the reason.

## Superseding

Accepted ADRs are never edited, renamed, or deleted. To change a decision, write a new ADR, set `Supersedes: ADR-NNNN`, and say in the paragraph why the earlier choice no longer holds. An ADR is in force unless a later ADR's `Supersedes:` names it.

## What usually qualifies

- The shape of the system: monorepo or not, where state lives, sync or event-driven.
- How bounded contexts talk to each other, and who owns which data.
- Technology with lock-in: database, message bus, auth provider, deployment target. Not every library.
- A deliberate departure from the obvious path, which the next person would otherwise "fix".
- A constraint the code cannot show: compliance, a partner contract, a latency budget.
- A rejected alternative whose rejection is not obvious.

## What does not

- Anything you could change next week without much cost.
- The obvious choice, made for the obvious reason.
- How a feature behaves (a spec) or how a change is built (a design).

## Example

```md
# Keep durable decisions outside the change folder

- Date: 2026-03-02
- Supersedes: —

A decision recorded inside `openspec/changes/<change>/` is archived with that
change and stops being read. We keep ADRs in `docs/adr/` instead, so the set of
in-force decisions is one directory listing. We accept that a change and its
ADRs are no longer a single folder; the change's `impact.md` links them.
```
