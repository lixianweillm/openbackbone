# Minimalist OpenSpec Schema

`minimalist` gets you building quickly with a direct `specs -> tasks` flow.

- Good fit: exploratory spikes and small, well-scoped changes with no real
  design decision in them.
- Not a good fit: anything that changes structure, adds a dependency, or
  makes a decision worth remembering. Use `spec-driven-with-impact`.

Pass `--schema minimalist` when creating the change:

```bash
openspec new change <name> --schema minimalist
```

Specs use the same delta format as the default schema (`## ADDED Requirements`,
`### Requirement:`, `#### Scenario:`), so a spike validates, passes the
pre-commit hook, and can be archived like any other change.

There is no impact step. A spike that graduates into real work goes back
through the default schema; until then, fix by hand any living document the
spike makes untrue.

## Associated skills

Declared in `skills.txt` and installed by `init.sh` for every selected agent target:

- `openspec-git-discipline`: one change, one branch, one pull request; when to split, and what goes wrong.
