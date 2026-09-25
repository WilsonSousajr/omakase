# Changelog

Notable changes to Omakase. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[semantic versioning](https://semver.org/spec/v2.0.0.html). Below 1.0 the API
is not frozen, and a breaking API change is a minor bump.

Each entry names the issues behind it. `docs/ROADMAP.md` carries the reasoning
for each milestone.

## [Unreleased]

### Security

- **Dependencies past eight known vulnerabilities.** Django 5.2 → 5.2.17,
  Django REST Framework 3.16.0 → 3.17.2, simplejwt 5.4.0 → 5.5.1 - the first
  fixed release of each, found by `pip-audit`. (#64)

### Fixed

- **`/tasks/today/` requires `?date=`.** Without it the endpoint answered for
  the server's UTC day, which for a client west of UTC is tomorrow from
  evening on. It now returns 400 `date param required.`, like
  `/tasks/carried-over/`. **Breaking** for any client that omitted the date.
  (#65)

### Removed

- **The Next.js web client.** The repository is the API alone until the
  native macOS client. The compose service, CI jobs, pre-commit hook and env
  vars went with it. (#62)

### Changed

- **One agent instruction file.** `AGENTS.md` is canonical and `CLAUDE.md`
  imports it. Descriptions moved to `docs/ARCHITECTURE.md`, and commits,
  issues and PRs follow the `type(#N): message` convention. From a prompt
  audit recorded in `docs/audits/2026-09-24-prompt-audit.md`. (#63)
