# GLOSSARY.md Format

## Structure

```md
# {Context name}

{One or two sentences: what this context is and why it exists.}

## Language

**Order**:
A customer's request to buy one or more items at an agreed price.
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request
```

## Rules

- **Pick one word.** When several words name the same concept, choose the best and list the rest under `_Avoid_`. The `_Avoid_` line is what stops the synonyms coming back.
- **Say what it is.** One or two sentences defining the thing, not what the system does with it. Behavior belongs in a spec.
- **Domain terms only.** A term belongs here if it is specific to this project's domain. General programming vocabulary (timeout, cache, retry) does not, however often the code uses it.
- **No implementation.** No class names, table names, file paths, or decisions. The glossary is a glossary and nothing else.
- **Group when clusters appear.** Use `###` subheadings under `## Language` once terms fall into natural groups. A flat list is fine before that.

## More than one context

Most repositories have one context and one `GLOSSARY.md` at the root.

When the same word legitimately means different things in different parts of the system, split into contexts. A root `GLOSSARY-MAP.md` lists them:

```md
# Glossary Map

## Contexts

- [Ordering](./src/ordering/GLOSSARY.md): receives and tracks customer orders
- [Billing](./src/billing/GLOSSARY.md): issues invoices and takes payment

## Relationships

- **Ordering → Billing**: Billing invoices an Order once Ordering marks it delivered
```

How to tell which applies:

- `GLOSSARY-MAP.md` exists: read it to find the contexts, and work out which one the current topic belongs to. Ask if unclear.
- Only a root `GLOSSARY.md` exists: single context.
- Neither exists: create a root `GLOSSARY.md` when the first term is settled.
