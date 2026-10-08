## Context

The installer has two kinds of output. Living documents are seeded once and then belong to the project. Everything else (skills, schemas, the ADR rules file, the hook script, the managed block) is replaced on every run so that upgrades arrive. For the second kind the installer never asked whether the path it was about to replace was its own. The hook, for its part, validated the whole `openspec/` tree on every commit, so its verdict depended on history rather than on the commit.

## Goals / Non-Goals

**Goals:**
- Nothing a project already has is overwritten, renamed, or re-permissioned by an installation.
- A project can take over any managed file and keep it across upgrades.
- A commit is judged on what it changes.

**Non-Goals:**
- Migrating installations made before this change. The project was published the same day.
- Making the ADR directory or the hook's file names configurable.
- Chaining hooks in a tracked hook directory without renaming them (stays on the roadmap).

## Decisions

- **Ownership lives in the file, as a `managed-by: openbackbone` line.** The installer replaces a managed path only when it is missing or carries the line. Alternative: treat `.openbackbone.yaml` as the list of owned paths. Rejected because a clone that lacks the manifest, or a project that ignores it, would silently stop receiving upgrades, and because there would be no way to adopt a single file. Passes the ADR bar; recorded as ADR-0005.
- **The hook script gets a distinctive name instead of a marker check.** `scripts/pre-commit.sh` is a name projects use. With `scripts/openbackbone-pre-commit.sh` there is nothing to collide with, so no "kept" branch is needed for the one file the hook cannot work without.
- **Instruction files are rewritten through the existing path** (`cat tmp > file`) rather than replaced by `mv`. This keeps symlinks and modes. It gives up atomic replacement, which matters little for a file the installer validated a moment earlier.
- **"Same file" is tested with `-ef`**, which covers a symlink in either direction and hard links, instead of testing whether `CLAUDE.md` is a symlink.
- **The hook derives its work list from the staged diff.** Specs and changes are validated one at a time by name; archived tasks are read from the staged `tasks.md`, which also removes that check's dependence on the CLI. Alternative: keep validating everything and add an opt-out. Rejected: a rule that blocks unrelated commits teaches people to bypass the hook.
- **Paths are read with `core.quotePath=false`.** Git otherwise prints non-ASCII paths as quoted octal escapes, which never match the ADR pattern.
- **The shim finds its directory from `$0`** instead of asking Git, so chaining does not depend on the Git version.

## Risks / Trade-offs

- [A project that copies a managed skill to customize it keeps the marker and loses its edits on upgrade] → the marker line says what it does; the README states the rule; the installer names every path it replaces only in the manifest, and every path it keeps on the terminal.
- [Whole-repository validation no longer happens at commit time] → documented, with the command to run in CI.
- [Non-atomic write of instruction files] → the content is assembled in a temporary file first; only the final copy is in place.

## Open Questions

None.
