## Why

Installing openbackbone into a project that already has files, history, and conventions of its own can damage it. The installer overwrites a same-named skill, schema, ADR rules file, or `scripts/pre-commit.sh`; it replaces symlinked instruction files and tightens their permissions; it resets a default schema the project chose. The hook then rejects unrelated commits because of specs and archives that predate the installation, and it does not see ADRs whose file names are not ASCII. The promise in the installation spec, "without ever overwriting what the project owns", does not hold yet.

## Roadmap

Unplanned: found by reviewing what the installer and hook do to a project that is not empty.

## What Changes

- The installer replaces a managed skill, schema, or ADR rules file only when it is missing or carries an ownership marker. Anything else is kept and reported.
- **BREAKING** The hook's checks move from `scripts/pre-commit.sh` to `scripts/openbackbone-pre-commit.sh`, a name a project will not already use.
- Instruction files are written in place, so symlinks and permissions survive. A `CLAUDE.md` that is the same file as `AGENTS.md` gets no import.
- The default schema is set only when the configuration has none or has OpenSpec's stock `spec-driven`.
- `--tools claude` no longer creates `.agents/skills/`.
- Chaining an existing pre-commit hook no longer makes a disabled hook executable.
- The hook checks only what the commit touches: staged specs, staged changes, and changes archived by this commit. Specs and archives that were already there never block a commit.
- ADR checks work for file names that are not ASCII. Only `Requirement:` and `Scenario:` headings mark an ADR as a spec. Impact markers may be bold or use a full-width colon.

## Capabilities

### New Capabilities

### Modified Capabilities
- `workflow-installation`: ownership of same-named files, in-place instruction writes, default schema set once, agent targets, hook file name.
- `commit-discipline`: every check is scoped to what the commit touches; ADR and impact checks accept more ways of writing.

## Impact

`init.sh`; the hook script (renamed); an ownership marker line in the three skills, the two schemas, and `docs/adr/README.md`; both test scripts; CI gains a macOS job running under the stock Bash 3.2; both READMEs and the architecture overview.
