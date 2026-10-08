## Context

`install_openspec` currently warns, records a remedy, and returns when the CLI is missing or `openspec init` fails. `main` only fails when no component at all was installed. Under `curl | bash` the script itself arrives on stdin, so stdin cannot be used to ask a question.

## Goals / Non-Goals

**Goals:**
- No file is written when the prerequisite is not met.
- The common case (a developer at a terminal) is one keypress away from a working install.
- CI and other unattended runs fail fast and can opt in to installing.

**Non-Goals:**
- Installing Node.js or npm.
- Pinning an OpenSpec version.
- Requiring the CLI for subset installs that leave out the `openspec` component.

## Decisions

- **Check before the first write.** `require_openspec` runs after argument parsing and marker validation and before `merge_instructions`. Checking inside `install_openspec`, as today, would leave `AGENTS.md` already modified.
- **Ask on the terminal, not on stdin.** Read the answer from stdin when it is a terminal, otherwise from `/dev/tty`. This is the only way to prompt under `curl | bash`. Alternative: never prompt and always fail with the command; rejected because it makes the first-run experience two steps for no benefit.
- **`CI` set, or no terminal, means do not ask.** Fail with the command and mention `--yes`. Silently installing a global npm package in an unattended run was rejected: a global install is a side effect the caller must opt in to.
- **`--yes` and `OPENBACKBONE_YES=1`.** The environment variable exists because flags are awkward under `curl | bash`.
- **`openspec init` failure is fatal.** The partial `openspec/` directory it may leave is repaired by the next run, which already reruns `openspec init` unconditionally.

## Risks / Trade-offs

- [A global npm install may need elevated permissions and fail] → the npm error is shown and the installer exits; nothing in the project has been written yet.
- [Subset installs can still produce a project without OpenSpec] → accepted; `--with` is an explicit choice and is how skills are refreshed.

## Open Questions

None.
