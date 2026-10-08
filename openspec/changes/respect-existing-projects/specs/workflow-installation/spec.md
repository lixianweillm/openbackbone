## ADDED Requirements

### Requirement: Same-named files are kept
The installer SHALL replace a managed skill, schema, or ADR rules file only when it is missing or carries the ownership marker, and SHALL report every file it kept.

#### Scenario: Project already has a skill of the same name
- **WHEN** the project has its own `.claude/skills/domain-modeling/` without the ownership marker
- **THEN** the installer leaves it unchanged, reports it as kept, and does not list it in `.openbackbone.yaml`

#### Scenario: Managed file on rerun
- **WHEN** the installer runs again and an installed skill still carries the ownership marker
- **THEN** the skill is replaced with the current version

#### Scenario: Project takes over a managed file
- **WHEN** the project removes the ownership marker from an installed schema, edits the schema, and runs the installer again
- **THEN** the edits are preserved and the schema is reported as kept

### Requirement: Default schema is set once
The installer SHALL make `spec-driven-with-impact` the default schema when `openspec/config.yaml` names no schema or names OpenSpec's stock `spec-driven`, and SHALL leave any other value unchanged.

#### Scenario: Fresh OpenSpec configuration
- **WHEN** `openspec init` has just created the configuration
- **THEN** the default schema is `spec-driven-with-impact`

#### Scenario: Project chose another default
- **WHEN** the configuration names `minimalist` and the installer runs again
- **THEN** the default schema is still `minimalist`

## MODIFIED Requirements

### Requirement: Agent targets
The installer SHALL write instructions and skills for the agent targets named by `--tools`, which defaults to `agents,claude`, and for no other target.

#### Scenario: Both default targets
- **WHEN** the installer runs with the default tools
- **THEN** skills exist under both `.agents/skills/` and `.claude/skills/`, and `CLAUDE.md` imports `AGENTS.md`

#### Scenario: Agents target only
- **WHEN** the installer runs with `--tools agents`
- **THEN** no `CLAUDE.md` and no `.claude/` directory is created

#### Scenario: Claude target only
- **WHEN** the installer runs with `--tools claude`
- **THEN** skills exist under `.claude/skills/` and no `.agents/` directory is created

#### Scenario: CLAUDE.md already reaches the rules
- **WHEN** `CLAUDE.md` is the same file as `AGENTS.md`, or already imports `AGENTS.md`
- **THEN** the installer adds no import to `CLAUDE.md`

### Requirement: Managed block
The installer SHALL confine its instructions to one managed block per instruction file, SHALL leave everything outside that block unchanged, and SHALL write the file in place so that a symlink and the file's permissions survive.

#### Scenario: Existing instructions
- **WHEN** `AGENTS.md` already has project content and no managed block
- **THEN** the managed block is appended and the existing content is unchanged

#### Scenario: Rerun
- **WHEN** the installer runs again on a file that has a managed block
- **THEN** only the content of the managed block is replaced

#### Scenario: Malformed markers
- **WHEN** an instruction file has unpaired, duplicated, or reversed markers
- **THEN** the installer exits with an error before writing any file

#### Scenario: Symlinked instruction file
- **WHEN** `AGENTS.md` is a symlink to another file
- **THEN** the managed block is written into that file and `AGENTS.md` is still a symlink

#### Scenario: File permissions
- **WHEN** an instruction file is readable by other users before the installer runs
- **THEN** it is still readable by other users afterwards

### Requirement: Repository-local hooks only
The installer SHALL write the pre-commit shim only into a hook directory that belongs to the repository, SHALL keep the hook's checks in `scripts/openbackbone-pre-commit.sh`, and SHALL chain any pre-commit hook that was already there without changing whether it is executable.

#### Scenario: Shared hook directory
- **WHEN** `core.hooksPath` points outside the repository
- **THEN** nothing is written there, and the `hooks` component is reported as skipped with a remedy

#### Scenario: Existing user hook
- **WHEN** the repository already has a pre-commit hook
- **THEN** that hook still runs, once, before the discipline checks

#### Scenario: Disabled user hook
- **WHEN** the repository has a pre-commit hook that is not executable
- **THEN** the hook is kept, is still not executable, and does not run

#### Scenario: Project has its own scripts/pre-commit.sh
- **WHEN** the project already has a file named `scripts/pre-commit.sh`
- **THEN** the installer leaves it unchanged
