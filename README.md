# openbackbone

English | [简体中文](./README.zh-CN.md)

The backbone of a maintainable project: specs, decisions, glossary, architecture, and roadmap that stay true as the code changes.

OpenSpec keeps a project's specs true. openbackbone extends the same discipline to the other documents a project needs to stay maintainable by humans and agents: its roadmap, glossary, architecture overview, decisions, and README.

| Document | Answers |
|---|---|
| `ROADMAP.md` | What will we build next? |
| `GLOSSARY.md` | What do we call things? |
| `openspec/specs/` | What does the system do? |
| `docs/architecture.md` | How is it put together today? |
| `docs/adr/` | Why is it this way? |
| `README.md` | How does a newcomer use it? |

## Install

Requires Git, Bash, and the OpenSpec CLI. Run in the root of your Git project:

```bash
npm install -g @fission-ai/openspec@latest
curl -fsSL https://raw.githubusercontent.com/lixianweillm/openbackbone/main/init.sh | bash
```

Or from a local clone:

```bash
git clone https://github.com/lixianweillm/openbackbone.git
cd /path/to/your-project
/path/to/openbackbone/init.sh
```

| Option | Default | Meaning |
|---|---|---|
| `--with` | `openspec,docs,skills,hooks` | Components to install |
| `--tools` | `agents,claude` | Agent targets: `agents` writes `AGENTS.md` and `.agents/skills/`; `claude` adds `CLAUDE.md` and `.claude/skills/`. Other OpenSpec tool ids are passed to `openspec init` |
| `--language` | `English` | Language for new OpenSpec artifacts (new projects only) |

Rerun the installer to upgrade. It rewrites only what it manages: the marked block in `AGENTS.md` and `CLAUDE.md`, the schemas, the skills, `docs/adr/README.md`, and `scripts/pre-commit.sh`. Your roadmap, glossary, architecture overview, ADRs, and README are never overwritten. `.openbackbone.yaml` records what was installed.

If the OpenSpec CLI is missing, or `core.hooksPath` points outside the repository, that component is skipped and the installer prints how to fix it.

## Work with it

Describe what you want to your coding agent. Small fixes go straight in. Significant changes run through five artifacts:

```text
proposal → specs → design → impact → tasks → implement → archive
```

- **proposal** names the roadmap item it delivers.
- **specs** use glossary terms only.
- **design** starts from the architecture overview and the in-force ADRs.
- **impact** states what the change does to ADRs, glossary, architecture, roadmap, and README. Each gets `Updated`, `Planned`, or `Not affected: <reason>`.
- **tasks** ends with a "Living documents" group: one task per `Planned` entry.

Use `openspec new change <name> --schema minimalist` for a spike.

### Decisions stay small

An ADR is written only when a decision is hard to reverse, surprising without context, and the result of a real trade-off. It is a title that states the choice and a paragraph that gives the reason. Accepted ADRs are immutable; a new ADR supersedes an old one. See [docs/adr/README.md](./docs/adr/README.md).

### The pre-commit hook

It rejects a commit that edits an existing ADR, adds an ADR containing Requirement or Scenario sections, stages an `impact.md` with an empty section, or fails `openspec validate --all --strict`. `OPENBACKBONE_SKIP_HOOKS=1` bypasses it for maintenance.

## Repository layout

```text
init.sh                 installer
AGENTS.md               the rules installed into target projects
openspec/schemas/       spec-driven-with-impact (default), minimalist
skills/                 domain-modeling, openspec-git-discipline, tech-doc
templates/              starting roadmap, glossary, architecture overview
scripts/                pre-commit checks, regression tests
docs/                   architecture overview and ADRs for openbackbone itself
```

See [docs/architecture.md](./docs/architecture.md) and [CONTRIBUTING.md](./CONTRIBUTING.md).

## Credits and license

[MIT](./LICENSE). Built on [OpenSpec](https://github.com/Fission-AI/OpenSpec). The `domain-modeling` skill follows the approach of [Matt Pocock's skill of the same name](https://www.aihero.dev/skills-domain-modeling). Bundled schemas keep their own license files.
