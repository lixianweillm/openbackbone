# Build on the OpenSpec CLI instead of forking it

- Date: 2026-10-08
- Supersedes: —

We need more than OpenSpec offers, but its change, delta, and archive mechanics are exactly what we want and are maintained upstream. We express everything as a custom schema, skills, and a Git hook on top of the stock CLI. A fork or our own CLI would let us enforce more (for example, refusing to archive with open document tasks), at the cost of tracking upstream forever. Until a needed check cannot be done from a hook, we stay on the stock CLI.
