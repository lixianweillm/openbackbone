## ADDED Requirements

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

## REMOVED Requirements

### Requirement: Skipped components are reported
**Reason**: A missing OpenSpec CLI is no longer skipped; it stops the installation. Skipping now applies to hooks only and is restated as "Hooks are skipped with a remedy".
**Migration**: Install the OpenSpec CLI before running the installer, accept the installer's offer, or pass `--yes`.
