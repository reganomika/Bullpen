# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning follows [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-07-21

### Added
- Configurable tier names in `route-gate.sh` via `ROUTE_GATE_TIER_AGENTS`, `ROUTE_GATE_ASK_AGENT`, `ROUTE_GATE_AUTOROUTE_AGENT`, `ROUTE_GATE_AUTOROUTE_MODEL`, `ROUTE_GATE_DENY_AGENT`, documented in FAQ.md. Renaming or adding a tier no longer silently drops the confirmation dialog or auto-route behavior.
- A bats test suite for `route-gate.sh`'s routing logic and its environment-variable overrides (`tests/route-gate.bats`).
- CI: shellcheck and the test suite run on every push and pull request.
- `CONTRIBUTING.md`.
- Issue templates for bug reports and feature requests.
- README badges (license, stars, CI status, Claude Code plugin).
- A non-dev (writing workflow) example in `skills/model-routing/SKILL.md`'s route table, showing the same cheap/dev/hard/super logic applied outside software development.
- `version` field in `plugin.json`.

### Changed
- `route-gate.sh`'s default behavior is unchanged, verified against the previous version across the full test suite (stdout and log entries both byte-identical with no environment variables set).

## [1.0.0] - 2026-07-21

Initial public release.

### Added
- Four subagents (`cheap`, `dev`, `hard`, `super`), each pinned to a model tier.
- `skills/model-routing`, the routing skill that decides which tier handles a task.
- `hooks/route-gate.sh`, a `PreToolUse` hook enforcing a real model choice on every agent spawn.
- `/usage-report`, `/routing-status`, `/refresh-rules` on-demand commands.
- Plugin manifest for `/plugin marketplace add` and `/plugin install`.
- README, COMMANDS.md, INSTALL.md, FAQ.md.
- Context-boundary hygiene (context size checkpoints, task-boundary offers) split out into a separate plugin, [HighWater](https://github.com/reganomika/HighWater), so it installs independently of model routing.
