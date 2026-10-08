# Minimalist OpenSpec Schema

`minimalist` is for getting to build quickly with a direct `specs -> tasks` flow.

- Good fit: exploratory spikes, landing pages, and simple apps without heavy
  technical design decisions.
- Not a good fit: complete apps with multiple layers, database work, and broader
  architecture concerns.

In this project it is the lightweight schema for spikes: pass
`--schema minimalist` when creating the change, or set it in
`openspec/config.yaml` to switch the default.

## Spec Format

When authoring `specs` artifacts in this schema:
- Write each requirement as a user story:
  `As a <role>, I want <capability>, so that <benefit>.`
- Write acceptance criteria using Gherkin structure:
  `Given ...`, `When ...`, `Then ...`

## Associated Skills

This schema declares its companion skills in `skills.txt`; `init.sh` reads that
list and installs them into the target project's `.agents/skills/`.

- `openspec-git-discipline` — git hygiene for OpenSpec propose/apply/archive
  workflows.
