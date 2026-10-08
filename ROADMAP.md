# Roadmap

What we intend to build, most certain first. An item is removed when the change that delivers it is archived.

## Now

- Baseline specs for this repository's own capabilities (installer, schema, hook), so openbackbone is maintained with openbackbone.
- Publish under the final repository name and verify the `curl | bash` path against it.

## Next

- Publish to npm so `npx openbackbone` works. The package manifest is ready; the name is unclaimed.
- Block archiving while a "Living documents" task is still open. Today only the instructions say so.
- A freshness report: which living documents have not changed since the last N archived changes.

## Later

- Check spec text against `_Avoid_` words in `GLOSSARY.md`.
- An opt-in way to install the hook into a shared `core.hooksPath` directory.
