<p align="center">
  <img src="assets/logo.svg" alt="Bullpen" width="460">
</p>

Cost-aware task routing for Claude Code. Four subagents pinned to four model tiers, a skill that picks the right one for each task, and hooks that enforce the routing and context rules mechanically instead of relying on the model to remember.

## What's in here

- **`agents/`** — four subagents (`cheap`, `dev`, `hard`, `super`), one per model tier, from fully-specified mechanics up to the frontier model
- **`skills/model-routing`** — the skill that decides which tier handles each task, and what never gets delegated at all
- **`hooks/route-gate.sh`** — enforces a real model choice on every agent spawn, instead of leaving it to advice
- **`hooks/context-check.sh`** — flags context bloat before it quietly burns your budget
- **`CLAUDE.md.example`** — an optional rule that wires the context-boundary offer into Claude's behavior
- **`/usage-report`, `/routing-status`, `/refresh-rules`** — on-demand commands, see [COMMANDS.md](COMMANDS.md)

## Install

```
/plugin marketplace add reganomika/Bullpen
/plugin install bullpen@bullpen
```

Full instructions, including the no-plugin-system path and what happens to chats you already have open: [INSTALL.md](INSTALL.md).

## Docs

- [COMMANDS.md](COMMANDS.md) — the three slash commands, with real output examples
- [INSTALL.md](INSTALL.md) — both install paths, restart caveats
- [FAQ.md](FAQ.md) — common questions and corner cases

## License

MIT, see `LICENSE`.
