# Domain docs

This is a single-context repository.

## Before exploring

Read the following when they exist:

- Root `CONTEXT.md` for the project's ubiquitous language.
- Relevant records under root `docs/adr/` for established design decisions.

Proceed silently when a document does not exist. Domain documentation is
created lazily when terminology or a meaningful trade-off is resolved.

## Use the glossary vocabulary

Use terms as defined in `CONTEXT.md` in specifications, issues, test names, and
implementation discussion. Do not silently substitute synonyms that the
glossary avoids.

If a required domain concept is absent, reconsider whether it belongs to the
project vocabulary or note the gap for a future domain-modeling session.

## Respect architectural decisions

Read ADRs relevant to the area being changed. If proposed work contradicts an
ADR, identify the conflict explicitly rather than silently overriding the
decision.

## Layout

```text
/
├── CONTEXT.md
└── docs/
    └── adr/
```
