# Omakase roadmap

Omakase is a DRF API for a planning and focus app spanning work and study.
Its web client was removed in #62. The next client is a native macOS app,
followed by native iOS and Android as a later epic.

Milestones are vertical slices. Each one produces something usable on its
own, and each is labelled `M<n>` on its issues. `docs/IDEA.md` holds the full
product vision and feature specification; this page holds the order and the
reasons for it.

## Where things stand

| | Milestone | Status |
|---|---|---|
| M0 | Groundwork | **In progress.** #63-#66. |

## M0 - Groundwork

**Delivers:** the conventions and the quality gate the macOS client's API
work will be held to, before that work starts.

**Contents:**

- #63 `AGENTS.md` as the one agent instruction file, from a prompt audit.
- #64 dependencies past eight known vulnerabilities.
- #65 `/tasks/today/` stops answering for the server's UTC day.
- #66 the quality gate: measured, pinned, and checked against itself.

**Why first:** a gate added after the API grows new endpoints for a new client
has to be set around whatever those endpoints turned out to be. Set now, it is
measured against a backend whose behaviour is known and covered.

**Done when:** all four are merged to `develop` with the gate green in CI.

## Next

The milestones after M0 come from the macOS client's design. They start with
what the API must provide for a native client that works in the user's
timezone and may be offline.
