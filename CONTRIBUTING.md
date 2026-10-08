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
openspec validate --specs --strict
```

CI runs the same checks, plus `shellcheck`, on every pull request.

The regression tests install into temporary repositories with a stub `openspec` and an isolated Git configuration; they do not touch your global hooks.

## Keep the documents true

`AGENTS.md` is copied into every target project: keep it generic. `.agents/skills/` and `.claude/skills/` are this repository's own installation: after editing anything under `skills/`, run `./init.sh --with skills` and commit the result. Behavior changes update the matching spec in `openspec/specs/` through a change. A change to installer behavior, the schema, or the hook updates `docs/architecture.md` and both README languages in the same change. Existing ADRs are never edited; supersede them.
