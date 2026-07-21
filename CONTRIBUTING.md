# Contributing

Issues and pull requests are welcome.

## Reporting a problem

Open an issue with: what you expected, what actually happened, and the exact output of `/routing-status` if it's a routing question, that already shows real decisions from `route-gate.log` instead of a guess. For a hook bug, include the relevant lines from `~/.claude/hooks/state/route-gate.log` and, if you can, the `Agent`/`Task` call that triggered it.

## Changing the routing rules

`skills/model-routing/SKILL.md` and `CLAUDE.md.example` mirror each other on purpose: the skill is the detailed version, the CLAUDE.md kernel is the compressed always-loaded copy. A PR that changes routing behavior should update both, or explain why one is enough.

## Changing `route-gate.sh`

It's a short, dependency-light shell script (only `jq`) by design, since it runs on every agent spawn in every project once installed. Keep new logic inside the existing fail-open pattern: on any unexpected input, exit 0 rather than block a real workflow. Run `shellcheck hooks/route-gate.sh` before opening a PR, CI runs it too.

## Adding a tier or renaming one

`route-gate.sh` reads which agent names get which treatment from environment variables (`ROUTE_GATE_TIER_AGENTS`, `ROUTE_GATE_ASK_AGENT`, `ROUTE_GATE_AUTOROUTE_AGENT`, `ROUTE_GATE_AUTOROUTE_MODEL`, `ROUTE_GATE_DENY_AGENT`), documented in [FAQ.md](FAQ.md). A PR proposing a fifth default tier should explain the cost tradeoff it adds versus the existing four, not just add another agent file.

## Style

No long dashes (— or –) in prose, active voice, no filler words. Short, direct sentences over long qualified ones. This applies to docs and to comments in the shell scripts.

## What won't get merged

Anything that adds a network call to a hook, or removes the fail-open behavior on missing `jq` or unexpected payloads. Both are deliberate: hooks here run on every response or agent spawn without your explicit action each time, and staying silent on a genuinely unexpected input beats blocking a real workflow.
