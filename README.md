<p align="center">
  <img src="assets/logo.svg" alt="Bullpen" width="460">
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <a href="https://github.com/reganomika/Bullpen/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/reganomika/Bullpen?style=flat"></a>
  <a href="https://github.com/reganomika/Bullpen/actions/workflows/shellcheck.yml"><img alt="CI" src="https://github.com/reganomika/Bullpen/actions/workflows/shellcheck.yml/badge.svg"></a>
  <img alt="Claude Code plugin" src="https://img.shields.io/badge/Claude%20Code-plugin-8A63D2">
</p>

Cost-aware task routing for Claude Code. Four subagents pinned to four model tiers, a skill that decides which tier fits each task, and a hook that closes the most expensive silent default (an agent spawned with no model named) mechanically, instead of leaving it to advice the model has to remember.

## What's in here

- **`agents/`**: four subagents (`cheap`, `dev`, `hard`, `super`), one per model tier, from fully-specified mechanics up to the frontier model
- **`skills/model-routing`**: the skill that decides which tier handles each task, and what never gets delegated at all
- **`hooks/route-gate.sh`**: enforces a real model choice on every agent spawn, instead of leaving it to advice. Tier names are configurable, see [FAQ.md](FAQ.md)
- **`CLAUDE.md.example`**: the routing rules kernel, an always-loaded compressed copy for turns where the skill itself isn't loaded
- **`tests/`**: a bats suite covering `route-gate.sh`'s routing logic and its environment-variable overrides (`bats tests/`)
- **`/usage-report`, `/routing-status`, `/refresh-rules`**: on-demand commands, see [COMMANDS.md](COMMANDS.md)

Looking for context-window hygiene (a checkpoint before a long chat quietly burns your budget) instead of model routing? That's a separate tool, [HighWater](https://github.com/reganomika/HighWater), safe to install alongside this one.

## Install

```
/plugin marketplace add reganomika/Bullpen
/plugin install bullpen@bullpen
```

Full instructions, including the no-plugin-system path and what happens to chats you already have open: [INSTALL.md](INSTALL.md).

## Docs

- [COMMANDS.md](COMMANDS.md): the three slash commands, with real output examples
- [INSTALL.md](INSTALL.md): both install paths, restart caveats
- [FAQ.md](FAQ.md): common questions and corner cases

## License

MIT, see `LICENSE`.
