---
name: domain-modeling
description: Settle the project's domain language and durable decisions while designing. Use when a discussion, proposal, spec, or design introduces or blurs a domain term, when writing or editing GLOSSARY.md, or when deciding whether a decision deserves an ADR in docs/adr/.
license: MIT
---

# Domain Modeling

Sharpen the project's language and record its durable decisions at the moment they are settled, not in a summary afterwards. This is the active discipline: challenging words, probing with scenarios, writing things down. Reading `GLOSSARY.md` to pick up vocabulary is a habit every task should have and does not need this skill.

Two files are yours to maintain:

| File | Holds | Never holds |
| --- | --- | --- |
| `GLOSSARY.md` | What each domain term **is** | Behavior, implementation, decisions |
| `docs/adr/NNNN-slug.md` | **Why** a hard-to-reverse choice was made | Requirements, designs, task lists |

Behavior belongs in `openspec/specs/`. How a change is built belongs in its `design.md`. Keep each out of the other.

Create files lazily. Write `GLOSSARY.md` when the first term is settled and `docs/adr/` when the first ADR is earned. A repository with several bounded contexts has a root `GLOSSARY-MAP.md` pointing at each context's own `GLOSSARY.md`; see [GLOSSARY-FORMAT.md](./GLOSSARY-FORMAT.md).

## While talking with the user

**Challenge against the glossary.** When the user uses a term in a way that conflicts with `GLOSSARY.md`, say so immediately and ask which is right: "The glossary defines *cancellation* as voiding the whole Order. You're describing removing one line. Is that a cancellation, or something else?"

**Sharpen fuzzy words.** When a word is vague or carries two meanings, propose one canonical term for each meaning: "By *account*, do you mean the Customer or the User? They have different lifecycles."

**Probe with concrete scenarios.** When a relationship between concepts is being described, invent a specific edge case that forces the boundary: "A Customer places an Order, then merges with another Customer. Whose Order is it?"

**Check the code.** When the user states how something works, read the code. If it disagrees, surface the contradiction and ask which is right. Cross-check only against the code, `GLOSSARY.md`, existing ADRs, and `openspec/specs/`.

**Write the term down now.** As soon as a term is settled, update `GLOSSARY.md` in the format of [GLOSSARY-FORMAT.md](./GLOSSARY-FORMAT.md). Do not batch terms for the end of the session.

## In an OpenSpec change

- Before `proposal` and `specs`: any domain term the change needs that the glossary lacks, or uses differently, gets settled here first. Specs then use glossary terms only and never a word listed under `_Avoid_`.
- At `impact`: apply the ADR test below to each decision in `design.md`, write the ADRs that pass, and report both in `impact.md`.
- A renamed term is a change to every spec that uses it. Say so; do not rename silently.

## Offer an ADR sparingly

Offer an ADR only when all three hold:

1. **Hard to reverse.** Changing your mind later costs real work.
2. **Surprising without context.** Someone reading the code later would ask why it is done this way.
3. **A real trade-off.** A genuine alternative existed and lost for specific reasons.

If any one is missing, there is no ADR. An easy-to-reverse choice will simply be reversed; an unsurprising one needs no explanation; a choice with no alternative is not a decision.

## An ADR is a decision, not a document

The failure to guard against is the ADR that grows into a second spec. Hold every ADR to this:

- The **title states the choice**: "Use Postgres for the write model", never "Database" or "Storage design".
- The **body is the reason**: what forced a choice, what was chosen, why the alternative lost. One paragraph is normal.
- It contains **no** requirements, scenarios, API or schema listings, file layouts, diagrams of the whole system, or task lists. If you are writing any of those, you are in the wrong file.
- **One decision per ADR.** Two choices are two ADRs.
- If the choice cannot be stated in one sentence, it has not been made yet. Go back to the discussion.

Accepted ADRs are immutable. To overturn one, write a new ADR that names it in `Supersedes:` and leave the old file untouched. Format and numbering are in [ADR-FORMAT.md](./ADR-FORMAT.md).
