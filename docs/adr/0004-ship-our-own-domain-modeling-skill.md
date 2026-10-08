# Ship our own domain-modeling skill

- Date: 2026-10-08
- Supersedes: —

The glossary and ADR discipline comes from Matt Pocock's `domain-modeling` skill (MIT). Installing his at setup time would track his improvements, but it knows nothing of OpenSpec changes, immutable ADRs, or the impact step, and a silent upstream change could contradict our schema. We ship our own skill written against this workflow and accept that upstream improvements must be ported by hand.
