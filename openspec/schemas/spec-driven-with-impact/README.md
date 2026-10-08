# Spec-Driven With Impact OpenSpec Schema

`spec-driven-with-impact` is the default schema of this project (see
`openspec/config.yaml`). It is the standard proposal-to-tasks OpenSpec flow plus
one step that keeps the project's other living documents in step with the change.

- Good fit: new capabilities, public interface or data model changes, new
  dependencies, cross-module work.
- Not a good fit: small fixes, local refactors, content-only edits. Those go
  straight in, or use `minimalist` (`specs -> tasks`) for a spike.

## Stage gates

`proposal -> specs -> design -> impact -> tasks`

- `proposal` names the `ROADMAP.md` item it delivers and uses `GLOSSARY.md` terms.
- `specs` use glossary terms only.
- `design` starts from `docs/architecture.md` and the in-force ADRs.
- `impact` writes `openspec/changes/<change>/impact.md`: one section each for
  decisions, glossary, architecture, roadmap, and README. Every entry is
  `Updated:`, `Planned:`, or `Not affected:`. ADRs and glossary terms are
  written in this step; the rest become tasks.
- `tasks` ends with a "Living documents" group holding one task per `Planned:` entry.

The pre-commit hook rejects an `impact.md` with an empty section, and an archived
change whose tasks, including "Living documents", are not all checked.

## Decisions are not specs

Durable ADRs live in `docs/adr/`, outside the change folder, and are immutable
once accepted. An ADR is created only for a decision that is hard to reverse,
surprising without context, and the result of a real trade-off. It records the
choice and the reason in a paragraph. Everything else about the change stays in
`design.md` and the specs. Most changes produce no ADR.

## Associated skills

Declared in `skills.txt` and installed by `init.sh`:

- `domain-modeling`: settles terms into `GLOSSARY.md` and decides whether a decision earns an ADR.
- `openspec-git-discipline`: git checkpoints for propose, apply, and archive.
