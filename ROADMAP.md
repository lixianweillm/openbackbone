# Roadmap

What we intend to build, most certain first. An item is removed when the change that delivers it is archived.

## Now

- Nothing in progress.

## Next

- Publish to npm so `npx openbackbone` works. The package manifest is ready; the name is unclaimed.
- A freshness report: which living documents have not changed since the last N archived changes.

## Later

- When `core.hooksPath` is a tracked directory inside the repository (husky and similar), chain the existing pre-commit hook without renaming it.
- Check spec text against `_Avoid_` words in `GLOSSARY.md`.
- An opt-in way to install the hook into a shared `core.hooksPath` directory.
