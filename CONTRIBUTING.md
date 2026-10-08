# Contributing

Read [AGENTS.md](./AGENTS.md) and [docs/architecture.md](./docs/architecture.md) before changing behavior. This repository follows its own workflow.

## Set up

You need Git, Bash, and the OpenSpec CLI.

```bash
npm install -g @fission-ai/openspec@latest
```

## Verify

```bash
./scripts/regression-test.sh
openspec schema validate spec-driven-with-impact
```

The regression tests install into temporary repositories with a stub `openspec` and an isolated Git configuration; they do not touch your global hooks.

## Keep the documents true

`AGENTS.md` is copied into every target project: keep it generic. A change to installer behavior, the schema, or the hook updates `docs/architecture.md` and both README languages in the same change. Existing ADRs are never edited; supersede them.
