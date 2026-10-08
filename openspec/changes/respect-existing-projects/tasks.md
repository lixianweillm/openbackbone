## 1. Installer

- [x] 1.1 Add the ownership marker to the three skills, both schemas, and docs/adr/README.md
- [x] 1.2 Replace skills, schemas, and the ADR rules file only when missing or marked; report what was kept; list only written paths in the manifest
- [x] 1.3 Rename the hook script to scripts/openbackbone-pre-commit.sh; locate backups from the shim's own directory; keep the mode of a chained hook
- [x] 1.4 Write instruction files and the OpenSpec configuration in place; use a same-file test for CLAUDE.md
- [x] 1.5 Set the default schema only when unset or `spec-driven`
- [x] 1.6 Install `.agents/skills/` only when a target other than Claude Code is selected; normalize `--tools`
- [x] 1.7 Run `openspec init` with standard input closed; report an old Git clearly

## 2. Hook

- [x] 2.1 Read staged paths unquoted; treat a type change like a modification
- [x] 2.2 Reject only `Requirement:` and `Scenario:` headings in an ADR
- [x] 2.3 Accept bold markers and a full-width colon in impact.md; tell authors to keep headings and markers in English
- [x] 2.4 Validate only staged specs and staged changes; check open tasks only in changes archived by the commit

## 3. Verification

- [x] 3.1 Regression tests for every scenario added or modified by this change
- [x] 3.2 End-to-end test: an archive from before the installation does not block a commit
- [ ] 3.3 CI: a macOS job that runs both test scripts under the stock Bash 3.2

## 4. Living documents

- [x] 4.1 docs/architecture.md: ownership kinds, hook script name, checks scoped to the commit
- [x] 4.2 README.md and README.zh-CN.md: ownership rule, hook script name, scoped checks and the full-check command, minimum Git version
