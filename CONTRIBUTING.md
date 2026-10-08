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
./scripts/e2e-test.sh
openspec validate --specs --strict
```

`regression-test.sh` stubs the OpenSpec CLI and covers the installer and the hook. `e2e-test.sh` uses the real CLI and takes a change through each schema; run it after touching a schema or a template.

CI runs the same checks, plus `shellcheck`, on every pull request.

Both scripts work in temporary repositories with an isolated Git configuration; they do not touch your global hooks, and the regression tests cannot reach your real npm.

## Keep the documents true

`AGENTS.md` is copied into every target project: keep it generic. `.agents/skills/` and `.claude/skills/` are this repository's own installation: after editing anything under `skills/`, run `./init.sh --with skills` and commit the result. Behavior changes update the matching spec in `openspec/specs/` through a change. A change to installer behavior, the schema, or the hook updates `docs/architecture.md` and both README languages in the same change. Existing ADRs are never edited; supersede them.
