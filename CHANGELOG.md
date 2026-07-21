# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning follows [Semantic Versioning](https://semver.org/).

## [1.3.0] - 2026-07-21

A second pass from the same reviewer on the 1.2.0 fixes, again verified against Claude Code's own docs (`model-config`) before acting.

### Added
- `route-gate.sh` warns once, loudly, when `jq` isn't installed, instead of failing open silently forever. A hand-written JSON block (jq itself is what's missing, so it can't build the message) blocks the first spawn attempt with install instructions, marks itself warned, and goes back to silent fail-open after that, so it never nags on every call.
- FAQ: an effort/model support table (which of the four tiers' pinned models actually support which `effort` levels, and that Claude Code clamps down silently rather than erroring on an unsupported one). Found in the process: Haiku isn't in Claude Code's effort-support table at all, so `cheap`'s `effort: low` is very likely a no-op, kept for consistency, not because it changes anything.
- FAQ: effort and extended thinking are related but distinct. Subagents inherit the session's thinking on/off toggle with no per-subagent override; `effort` only controls depth once thinking is on. Fable 5 (`super`) can't have thinking disabled at all regardless of the session setting, so this doesn't affect it. Sonnet 5 and Opus 4.8 (`dev`, `hard`) do inherit the toggle, so session-level thinking being off can suppress their reasoning depth even with `effort: high`/`xhigh` set.
- 2 new test cases for the jq-missing warning (21 total).

### Changed
- The `allow-tier-model-overridden` log entry and its FAQ explanation now say plainly that the logged override model is observed from the hook's own environment, not verified against what Claude Code actually resolved: an excluded value under an org's `availableModels` allowlist gets silently skipped by Claude Code, a case the hook has no way to detect.

## [1.2.0] - 2026-07-21

Fixes and corrections from an independent review, verified line by line against Claude Code's own docs before acting on any of it.

### Added
- `effort` frontmatter field on all four agents (cheap=low, dev=high, hard=xhigh, super=max). This is a real Claude Code subagent field that overrides the session effort level; the docs previously claimed no such field existed.
- `route-gate.sh` detects `CLAUDE_CODE_SUBAGENT_MODEL` (a Claude Code environment variable that outranks per-invocation model params and agent frontmatter alike) and logs `allow-tier-model-overridden` plus the real overriding model, instead of a plain `allow-tier` that would misrepresent what actually ran.
- FAQ entries: what route-gate.sh does and doesn't enforce (three mechanical checks, not the whole route table), the tier name collision risk from plugin agents' lowest scope priority, and the `CLAUDE_CODE_SUBAGENT_MODEL` sharp edge.
- 3 new test cases covering the `CLAUDE_CODE_SUBAGENT_MODEL` behavior (19 total).

### Fixed
- SKILL.md and FAQ.md no longer claim subagents have no effort parameter.
- INSTALL.md and FAQ.md no longer claim a blanket "nothing works without a restart." The hook always needs one; agents often don't, if `~/.claude/agents/` already existed before the session started, per Claude Code's own file-watching behavior. The plugin-install path's agent reload behavior is marked unverified rather than asserted either way.
- README, `plugin.json`, and the GitHub repo description no longer read as "the hook enforces the routing," which overstates what three specific checks (Explore auto-route, general-purpose deny, super confirm) actually cover. The route table itself, which tier fits which task, stays advice in SKILL.md, same as it always has.

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
