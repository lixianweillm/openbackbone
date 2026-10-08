## Decisions (docs/adr/)

- Checked against the in-force ADRs 0001 (build on the OpenSpec CLI), 0002, 0003, 0004. This change follows 0001.
- Not affected: making the CLI a hard prerequisite is easy to reverse and is what a reader would expect, so it fails the ADR bar.

## Glossary (GLOSSARY.md)

- Not affected: no domain term is introduced or changed; the delta spec uses Component as defined.

## Architecture (docs/architecture.md)

- Not affected: no component, boundary, or flow changes; the overview does not describe prerequisite handling.

## Roadmap (ROADMAP.md)

- Not affected: the work was unplanned and reveals no follow-up.

## README (README.md)

- Planned: state that the OpenSpec CLI is required and that the installer offers to install it; document `--yes`; remove the claim that a missing CLI is skipped. Same in README.zh-CN.md.
