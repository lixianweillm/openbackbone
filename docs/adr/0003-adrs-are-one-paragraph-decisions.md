# Keep ADRs to the decision and its reason

- Date: 2026-10-08
- Supersedes: —

Sectioned ADR templates (MADR and similar) invite filling every section, and the record grows into a second specification that nobody keeps true. Our ADRs are a title that states the choice and a paragraph that gives the reason, gated by three tests: hard to reverse, surprising without context, a real trade-off. We lose the uniform structure that tooling for MADR expects, and most changes will produce no ADR at all. That is intended.

## Rejected

- Offering a choice of ADR templates per project: it moves the bloat decision to each project instead of making it once.
