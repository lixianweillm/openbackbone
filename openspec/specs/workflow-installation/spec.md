# workflow-installation Specification

## Purpose

Install the openbackbone workflow into a project with one command, and upgrade it by running the same command again, without ever overwriting what the project owns.

## Requirements

### Requirement: Component selection
The installer SHALL install the components `openspec`, `docs`, `skills`, and `hooks` by default, and SHALL install only the named components when `--with` is given.

#### Scenario: Default installation
- **WHEN** the installer runs in a Git project root with no options
- **THEN** all four components are installed and listed in `.openbackbone.yaml`

#### Scenario: Unknown component
- **WHEN** `--with` names a component that does not exist
- **THEN** the installer exits with an error and changes no file

### Requirement: Stable manifest
The installer SHALL record the source version, tools, components, and managed paths in `.openbackbone.yaml`, and SHALL NOT record anything that differs between two runs of the same version.

#### Scenario: Rerun of the same version
- **WHEN** the installer runs twice from the same source version with the same options
- **THEN** `.openbackbone.yaml` is byte-for-byte unchanged by the second run

### Requirement: Agent targets
The installer SHALL write instructions and skills for every agent target named by `--tools`, which defaults to `agents,claude`.

#### Scenario: Both default targets
- **WHEN** the installer runs with the default tools
- **THEN** skills exist under both `.agents/skills/` and `.claude/skills/`, and `CLAUDE.md` imports `AGENTS.md`

#### Scenario: Agents target only
- **WHEN** the installer runs with `--tools agents`
- **THEN** no `CLAUDE.md` and no `.claude/` directory is created

#### Scenario: CLAUDE.md already reaches the rules
- **WHEN** `CLAUDE.md` is a symlink or already imports `AGENTS.md`
- **THEN** the installer leaves `CLAUDE.md` unchanged

### Requirement: Managed block
The installer SHALL confine its instructions to one managed block per instruction file and SHALL leave everything outside that block unchanged.

#### Scenario: Existing instructions
- **WHEN** `AGENTS.md` already has project content and no managed block
- **THEN** the managed block is appended and the existing content is unchanged

#### Scenario: Rerun
- **WHEN** the installer runs again on a file that has a managed block
- **THEN** only the content of the managed block is replaced

#### Scenario: Malformed markers
- **WHEN** an instruction file has unpaired, duplicated, or reversed markers
- **THEN** the installer exits with an error before writing any file

### Requirement: Living documents are seeded once
The installer SHALL create `ROADMAP.md`, `GLOSSARY.md`, and `docs/architecture.md` only when they do not exist, and SHALL never create or modify `README.md` or any ADR.

#### Scenario: Existing roadmap
- **WHEN** the project already has a `ROADMAP.md`
- **THEN** the installer leaves it unchanged

#### Scenario: Edited glossary on rerun
- **WHEN** the project has edited its seeded `GLOSSARY.md` and the installer runs again
- **THEN** the edits are preserved

### Requirement: Upgrade from the published source
The installer SHALL take its content from the directory of its own script file when that directory is the template repository, and otherwise SHALL fetch the published repository.

#### Scenario: Piped rerun in an installed project
- **WHEN** the installer is piped into a shell inside a project that is already installed
- **THEN** it fetches the published repository and replaces the managed content

### Requirement: Repository-local hooks only
The installer SHALL write the pre-commit shim only into a hook directory that belongs to the repository, and SHALL chain any pre-commit hook that was already there.

#### Scenario: Shared hook directory
- **WHEN** `core.hooksPath` points outside the repository
- **THEN** nothing is written there, and the `hooks` component is reported as skipped with a remedy

#### Scenario: Existing user hook
- **WHEN** the repository already has a pre-commit hook
- **THEN** that hook still runs, once, before the discipline checks

### Requirement: OpenSpec CLI is required
When the `openspec` component is selected, the installer SHALL require the OpenSpec CLI before it writes any file. When the CLI is missing, the installer SHALL offer to install it, and SHALL exit with an error, having changed nothing, unless the CLI is installed.

#### Scenario: User accepts
- **WHEN** the CLI is missing and the user confirms the offer
- **THEN** the installer installs the CLI with npm and continues

#### Scenario: User declines
- **WHEN** the CLI is missing and the user declines the offer
- **THEN** the installer exits with an error, prints the install command, and has changed no file

#### Scenario: No terminal to ask on
- **WHEN** the CLI is missing, no terminal is available, and `--yes` was not given
- **THEN** the installer exits with an error, prints the install command, and has changed no file

#### Scenario: Accepted in advance
- **WHEN** the CLI is missing and the installer runs with `--yes`
- **THEN** the installer installs the CLI with npm without asking and continues

#### Scenario: npm missing
- **WHEN** the CLI and npm are both missing
- **THEN** the installer exits with an error and has changed no file

#### Scenario: Component not selected
- **WHEN** `--with` does not include `openspec`
- **THEN** the installer does not require the CLI

### Requirement: OpenSpec initialization must succeed
The installer SHALL exit with an error when `openspec init` fails, and a later run SHALL complete the installation.

#### Scenario: Initialization fails
- **WHEN** `openspec init` exits with an error
- **THEN** the installer exits with an error and writes no manifest

#### Scenario: Rerun after a failure
- **WHEN** the installer runs again and `openspec init` succeeds
- **THEN** the schemas are installed and the manifest lists the `openspec` component

### Requirement: Hooks are skipped with a remedy
The installer SHALL skip the `hooks` component when the repository cannot take a hook, continue with the other components, and print how to make the hook installable.

#### Scenario: Not a Git repository
- **WHEN** the installer runs in a directory that is not a Git repository
- **THEN** the `hooks` component is skipped with a remedy, and the other components are installed
