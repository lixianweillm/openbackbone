---
name: openspec-git-discipline
description: Use when an OpenSpec change meets git - deciding what goes on which branch, when to commit artifacts, and when to archive relative to a merge.
license: MIT
---

# OpenSpec and Git

Keep it light. The default is **one change, one branch, one pull request**: the proposal artifacts, the implementation, and the archive can all travel together.

## Defaults

- **One branch per change.** Start the change on a feature branch and keep its artifacts and its code there.
- **Commit artifacts as they settle.** A change with only a proposal can be committed; the pre-commit hook validates a change once it has delta specs.
- **Archive in the same pull request**, once every task is checked, including the "Living documents" group. The merged result then carries the updated specs and the archived change together.
- **Never create commits, branches, or merges unless the user asks.**

## When to split

Split the proposal into its own pull request only when someone needs to agree on the plan before work starts: a contested design, a breaking change, work several people will build on. Otherwise a separate round trip through the main branch is cost without benefit.

## Things that actually go wrong

- **Archiving with open tasks.** The hook rejects the commit. Finish the tasks or remove the ones that no longer apply; do not tick boxes for work that was not done.
- **Two changes touching the same capability.** Whichever merges second must rebase and re-check its delta against the updated spec before archiving, or its MODIFIED blocks will overwrite the other change's requirements.
- **Archiving, then continuing to change behavior on the same branch.** The archived specs no longer match the code. Either reopen the work as a new change or update the spec in the same pull request.
