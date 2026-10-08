# change-workflow Specification

## Purpose

Define the artifacts a significant change passes through, so that the change keeps every living document true and not only the specs.

## Requirements

### Requirement: Five artifacts in order
The default schema SHALL define the artifacts proposal, specs, design, impact, and tasks, where specs and design require the proposal, impact requires the design, and tasks require specs and impact.

#### Scenario: New change
- **WHEN** a change is created with the default schema
- **THEN** only the proposal is ready, and the other four artifacts are blocked

### Requirement: Proposal names its roadmap item
The proposal SHALL state which `ROADMAP.md` item the change delivers, or state that the change is unplanned and why.

#### Scenario: Planned work
- **WHEN** a change delivers an item listed in `ROADMAP.md`
- **THEN** the proposal quotes that item

### Requirement: Specs use the glossary
Delta specs SHALL use terms as `GLOSSARY.md` defines them and SHALL NOT use a word the glossary lists as avoided.

#### Scenario: Missing term
- **WHEN** a requirement needs a domain term the glossary does not define
- **THEN** the term is settled and written to `GLOSSARY.md` before the requirement is written

### Requirement: Impact review covers every other living document
The impact review SHALL have one section each for decisions, glossary, architecture, roadmap, and README, and every section SHALL hold at least one entry marked `Updated`, `Planned`, or `Not affected` with a reason.

#### Scenario: Nothing to record
- **WHEN** a change makes no durable decision
- **THEN** the decisions section says `Not affected` and gives the reason

### Requirement: ADRs are written sparingly
The impact review SHALL create an ADR only for a decision that is hard to reverse, surprising without context, and the result of a real trade-off.

#### Scenario: Tactical decision
- **WHEN** a decision in the design is easy to reverse
- **THEN** it stays in the design and no ADR is created

### Requirement: Planned updates become tasks
The tasks artifact SHALL end with a "Living documents" group that holds one task for every `Planned` entry of the impact review.

#### Scenario: Architecture change planned
- **WHEN** the impact review plans an update to `docs/architecture.md`
- **THEN** the last task group contains a task naming `docs/architecture.md`

### Requirement: Light path for spikes
The workflow SHALL provide a `minimalist` schema with only specs and tasks for exploratory work.

#### Scenario: Spike
- **WHEN** a change is created with `--schema minimalist`
- **THEN** it has two artifacts, specs and tasks
