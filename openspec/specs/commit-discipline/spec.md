# commit-discipline Specification

## Purpose

Reject, at commit time, the mistakes that let living documents drift and that a script can detect without judgment.

## Requirements

### Requirement: ADRs are immutable
The pre-commit hook SHALL reject a commit that modifies, renames, or deletes a `docs/adr/NNNN-*.md` file that is on the default branch, whatever characters its name contains, and SHALL allow an ADR that exists only on the current branch to be revised.

#### Scenario: Editing an ADR
- **WHEN** a commit changes the text of an ADR that is on the default branch
- **THEN** the commit is rejected with advice to add a superseding ADR

#### Scenario: Revising a draft
- **WHEN** a commit changes an ADR that was added on the current feature branch and is not on the default branch
- **THEN** the commit is not rejected for that ADR

#### Scenario: Adding an ADR
- **WHEN** a commit adds a new numbered ADR file
- **THEN** the immutability check passes

#### Scenario: File name that is not ASCII
- **WHEN** a commit changes an ADR on the default branch whose file name contains Chinese characters
- **THEN** the commit is rejected

### Requirement: An ADR is not a spec
The pre-commit hook SHALL reject a new or revised ADR that contains a `Requirement:` or `Scenario:` heading, and SHALL warn when it is longer than 40 lines.

#### Scenario: Requirements inside an ADR
- **WHEN** a commit adds an ADR with a `## Requirement:` heading
- **THEN** the commit is rejected

#### Scenario: Heading that only mentions requirements
- **WHEN** a commit adds an ADR with a `## Requirements we weighed` heading
- **THEN** the commit is not rejected

### Requirement: Impact reviews are complete
The pre-commit hook SHALL reject a staged `impact.md` of an unarchived change when any of its five sections has no `Updated`, `Planned`, or `Not affected` entry. An entry MAY be a list item, MAY write its marker in bold, and MAY use a full-width colon.

#### Scenario: Unfilled template
- **WHEN** a commit stages an `impact.md` that is still the empty template
- **THEN** the commit is rejected and all five sections are named

#### Scenario: One section missing
- **WHEN** a commit stages an `impact.md` with entries in four sections
- **THEN** the commit is rejected and the fifth section is named

#### Scenario: Formatted markers
- **WHEN** a commit stages an `impact.md` whose entries are written as `- **Not affected:** <reason>` or with a full-width colon
- **THEN** the entries are accepted

### Requirement: Specs and changes validate
When the OpenSpec CLI is available, the pre-commit hook SHALL validate strictly each spec and each change with delta specs that the commit touches, and SHALL NOT validate a change that has no delta specs yet or anything the commit does not touch.

#### Scenario: Proposal only
- **WHEN** a commit contains a change that has a proposal and no delta specs
- **THEN** the commit is not rejected for that change

#### Scenario: Invalid delta spec
- **WHEN** a commit contains a change whose delta spec has a requirement without a scenario
- **THEN** the commit is rejected

#### Scenario: CLI missing
- **WHEN** the `openspec` command is not available
- **THEN** validation is skipped with a notice and the other checks still run

#### Scenario: Unrelated commit
- **WHEN** the repository holds a spec that fails validation and a commit touches no file under `openspec/`
- **THEN** the commit is not rejected and the OpenSpec CLI is not run

### Requirement: Archived changes are finished
The pre-commit hook SHALL reject a commit that archives a change with an unchecked task, and SHALL NOT reject a commit because of a change that was archived earlier.

#### Scenario: Living documents task left open
- **WHEN** a change is archived with its `README.md` task unchecked
- **THEN** the commit is rejected

#### Scenario: Archive from before the installation
- **WHEN** the repository already holds an archived change with unchecked tasks and a commit does not touch it
- **THEN** the commit is not rejected

### Requirement: Maintenance bypass
The pre-commit hook SHALL skip all checks when `OPENBACKBONE_SKIP_HOOKS=1` is set, and SHALL say that it did.

#### Scenario: Bypass
- **WHEN** a commit is made with `OPENBACKBONE_SKIP_HOOKS=1`
- **THEN** no check runs and a notice is printed
