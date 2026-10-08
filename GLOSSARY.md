# openbackbone

An installable workflow that extends OpenSpec so that a project's specs, decisions, language, structure, plans, and entry point stay true together, for the humans and agents who maintain it.

## Language

**Living document**:
One of the six documents that together describe a project and are kept true as it changes: roadmap, glossary, specs, architecture overview, ADRs, README.
_Avoid_: Artifact (that is an OpenSpec change file), source of truth

**Change**:
One unit of significant work, held in `openspec/changes/<name>/` until it is archived.
_Avoid_: Feature, ticket, task

**Impact review**:
The step of a change that states what the change does to every living document other than the specs.
_Avoid_: ADR review, doc check

**ADR**:
A record of one decision and the reason for it. Not a specification and not a design.
_Avoid_: Design doc, RFC

**In force**:
Said of an ADR that no later ADR supersedes.
_Avoid_: Active, current, valid

**Managed block**:
The marker-delimited part of an instruction file that the installer owns and rewrites; everything outside it belongs to the project.

**Ownership marker**:
The line `managed-by: openbackbone` inside an installed file. The installer replaces only files that carry it; a project that removes it owns the file from then on.
_Avoid_: Tag, stamp, signature

**Component**:
One independently selectable part of an installation: `openspec`, `docs`, `skills`, or `hooks`.
_Avoid_: Module, plugin
