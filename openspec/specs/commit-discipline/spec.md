# commit-discipline Specification

## Purpose

Reject, at commit time, the mistakes that let living documents drift and that a script can detect without judgment.

## Requirements

### Requirement: ADRs are immutable
The pre-commit hook SHALL reject a commit that modifies, renames, or deletes an existing `docs/adr/NNNN-*.md` file.

#### Scenario: Editing an ADR
- **WHEN** a commit changes the text of an ADR that is already committed
- **THEN** the commit is rejected with advice to add a superseding ADR

#### Scenario: Adding an ADR
- **WHEN** a commit adds a new numbered ADR file
- **THEN** the immutability check passes

### Requirement: An ADR is not a spec
The pre-commit hook SHALL reject a new ADR that contains a Requirement or Scenario heading, and SHALL warn when a new ADR is longer than 40 lines.

#### Scenario: Requirements inside an ADR
- **WHEN** a commit adds an ADR with a `## Requirement:` heading
- **THEN** the commit is rejected

### Requirement: Impact reviews are complete
The pre-commit hook SHALL reject a staged `impact.md` of an unarchived change when any of its five sections has no `Updated`, `Planned`, or `Not affected` entry.

#### Scenario: Unfilled template
- **WHEN** a commit stages an `impact.md` that is still the empty template
- **THEN** the commit is rejected and all five sections are named

#### Scenario: One section missing
- **WHEN** a commit stages an `impact.md` with entries in four sections
- **THEN** the commit is rejected and the fifth section is named

### Requirement: Specs and changes validate
When the OpenSpec CLI is available, the pre-commit hook SHALL validate the specs strictly, SHALL validate strictly each change that has delta specs, and SHALL NOT validate a change that has none yet.

#### Scenario: Proposal only
- **WHEN** a commit contains a change that has a proposal and no delta specs
- **THEN** the commit is not rejected for that change

#### Scenario: Invalid delta spec
- **WHEN** a commit contains a change whose delta spec has a requirement without a scenario
- **THEN** the commit is rejected

#### Scenario: CLI missing
- **WHEN** the `openspec` command is not available
- **THEN** validation is skipped with a notice and the other checks still run

### Requirement: Archived changes are finished
The pre-commit hook SHALL reject a commit while an archived change has an unchecked task.

#### Scenario: Living documents task left open
- **WHEN** a change is archived with its `README.md` task unchecked
- **THEN** the commit is rejected

### Requirement: Maintenance bypass
The pre-commit hook SHALL skip all checks when `OPENBACKBONE_SKIP_HOOKS=1` is set, and SHALL say that it did.

#### Scenario: Bypass
- **WHEN** a commit is made with `OPENBACKBONE_SKIP_HOOKS=1`
- **THEN** no check runs and a notice is printed
