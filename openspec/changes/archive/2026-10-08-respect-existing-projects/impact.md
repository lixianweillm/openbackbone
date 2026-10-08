## Decisions (docs/adr/)

- Checked against the in-force ADRs 0001 to 0004. Nothing here departs from them.
- Updated: docs/adr/0005-record-ownership-inside-each-managed-file.md - ownership of a managed file is a marker line in the file, not an entry in the manifest.
- Not affected (other decisions in design.md): renaming the hook script, scoping the hook to the staged diff, and writing files in place are each easy to reverse.

## Glossary (GLOSSARY.md)

- Updated: GLOSSARY.md - added "Ownership marker".

## Architecture (docs/architecture.md)

- Planned: the "Ownership in the target" column now has three kinds (managed block, managed by marker, seeded once); the hook script is renamed; "What the hook enforces" describes checks scoped to the commit.

## Roadmap (ROADMAP.md)

- Not affected: the work was unplanned. The tracked-hook-directory item stays as it is.

## README (README.md)

- Planned: the ownership rule and how to take over a file; the new hook script name; that the hook checks only what a commit touches, with the command for a full check; Git 2.31 as the minimum. Same in README.zh-CN.md.
