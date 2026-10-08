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

Requires Git 2.31 or newer, Bash, and the [OpenSpec CLI](https://github.com/Fission-AI/OpenSpec). Run in the root of your Git project:

```bash
curl -fsSL https://raw.githubusercontent.com/lixianweillm/openbackbone/main/init.sh | bash
```

If the OpenSpec CLI is missing, the installer offers to install it with `npm install -g @fission-ai/openspec@latest`. If you decline, or there is no terminal to ask on, it stops without changing anything. Pass `--yes` to accept in advance:

```bash
curl -fsSL https://raw.githubusercontent.com/lixianweillm/openbackbone/main/init.sh | bash -s -- --yes
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
| `--yes` | off | Install the OpenSpec CLI without asking when it is missing. `OPENBACKBONE_YES=1` does the same |

### What the installer touches

| Kind | Paths | On a rerun |
|---|---|---|
| Managed block | `AGENTS.md`, `CLAUDE.md` | Only the text between the `openbackbone` markers is replaced. The file is edited in place: a symlink stays a symlink |
| Managed files | The skills, the two schemas, `docs/adr/README.md` | Replaced, as long as the file still carries its `managed-by: openbackbone` line |
| Hook | `scripts/openbackbone-pre-commit.sh` and the shim in the hook directory | Replaced |
| Seeded once | `ROADMAP.md`, `GLOSSARY.md`, `docs/architecture.md` | Never touched again |
| Never written | `README.md`, your ADRs, your specs | |

Rerun the installer to upgrade. A file of yours that happens to share a managed file's name is kept, not overwritten, and the installer lists what it kept. To customize a managed file and keep your edits across upgrades, delete its `managed-by: openbackbone` line. `openspec/config.yaml` keeps your settings; the default schema is changed only if it is unset or still OpenSpec's stock `spec-driven`.

`.openbackbone.yaml` records what was installed and from which version. It changes only when an upgrade changes something, so commit it.

Only the `hooks` component can be skipped: when the directory is not a Git repository root, or `core.hooksPath` points outside the repository, the installer installs the rest and prints how to fix it. An existing pre-commit hook keeps running before the checks. A `CLAUDE.md` that is the same file as `AGENTS.md`, or already imports it, gets no import.

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

An ADR is written only when a decision is hard to reverse, surprising without context, and the result of a real trade-off. It is a title that states the choice and a paragraph that gives the reason. ADRs are immutable once merged; a new ADR supersedes an old one. See [docs/adr/README.md](./docs/adr/README.md).

### The pre-commit hook

The hook judges a commit on what the commit touches. It rejects a commit that:

- edits, renames, or deletes an ADR that is already on the main branch (a draft on your branch can be revised);
- adds an ADR containing `Requirement:` or `Scenario:` headings;
- stages an `impact.md` with an empty section;
- stages a spec that fails validation, or a change with delta specs that fails validation (a change with only a proposal can be committed);
- archives a change that still has open tasks.

Specs and archives that were in the repository before never block a commit. To check everything, for example in CI, run `openspec validate --specs --strict`.

`OPENBACKBONE_SKIP_HOOKS=1` bypasses it for maintenance.

## Repository layout

```text
init.sh                 installer
AGENTS.md               the rules installed into target projects
openspec/schemas/       spec-driven-with-impact (default), minimalist
skills/                 domain-modeling, openspec-git-discipline, tech-doc
templates/              starting roadmap, glossary, architecture overview
scripts/                the hook's checks, regression and end-to-end tests
docs/                   architecture overview and ADRs for openbackbone itself
```

See [docs/architecture.md](./docs/architecture.md) and [CONTRIBUTING.md](./CONTRIBUTING.md).

## Credits and license

[MIT](./LICENSE). Built on [OpenSpec](https://github.com/Fission-AI/OpenSpec). The `domain-modeling` skill follows the approach of [Matt Pocock's skill of the same name](https://www.aihero.dev/skills-domain-modeling).
