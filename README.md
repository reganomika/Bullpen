<p align="center">
  <img src="assets/logo.svg" alt="Bullpen" width="340">
</p>

<p align="center">
  <strong>English</strong> · <a href="README.ru.md">Русский</a>
</p>

Cost-aware task routing for Claude Code: four subagents pinned to four model tiers, a skill that decides which one to call, and two hooks that enforce the routing and context rules mechanically instead of leaving them to prose. Token and routing stats are on demand, via two slash commands, not forced into every reply.

## The problem this solves

Claude Code makes it easy to run every task on your most capable model, and just as easy to forget you're doing it. In long agentic sessions, tokens spent re-reading accumulated context routinely dwarf tokens spent on actual output, by an order of magnitude. Model choice matters. How much history you drag along usually matters more.

Bullpen routes work to the cheapest model that can do it: search, recon, and mechanical tasks go to the cheapest tier (enforced by a gate on the agent-spawn path, not by advice), while same-model delegation buys context isolation, not discounts. Two on-demand commands show what actually ran, model by model, whenever you want to check.

## What's in here

**Four subagents** (`agents/`), each pinned to one model tier:

- `cheap` — fully specified mechanics: renames, cleanups, boilerplate, doc edits, translations; strongest as parallel fan-out over lists of small chunks
- `dev` — default executor for self-contained implementation: features, scoped refactors, build/run checks. Same model as your main session, so it buys context isolation and parallelism, not savings
- `hard` — known-hard work, entered proactively: adversarial reviews, races, API/schema migrations, staged sync verification, 10+ coupled files
- `super` — frontier tier for confirmed hard-tier failure, unsplittable multi-hour autonomous runs, or maximum cost of error; spawning it raises a native confirmation dialog

**A routing skill** (`skills/model-routing/SKILL.md`) that decides which tier to call, what never to delegate (destructive git, secrets, personal/legal/financial documents), and how to hand context up between escalating tiers. It also covers the built-in `Explore` and `general-purpose` agents and the Agent tool's `model` parameter, which otherwise silently inherit your session model.

**`route-gate.sh`**, a `PreToolUse` hook on `Agent`/`Task` calls. `Explore` with no model is rewritten to haiku; `general-purpose` with no model is denied until one is named; `super` raises a confirmation dialog. Every decision logs to `~/.claude/hooks/state/route-gate.log`; a quiet log while you're clearly spawning agents means the gate died (it fails open by design). Off switch: `touch ~/.claude/hooks/route-gate.disabled`.

**`context-check.sh`**, a `Stop` hook that reads context size from the transcript and, past a threshold, blocks the response until Claude raises a task-boundary checkpoint. Soft mark (~55% of the window) is a text nudge Claude can decline for focused work; hard mark (~88%, before harness auto-compact) forces an actual `AskUserQuestion` call and keeps re-firing until one shows up in the transcript. Window defaults to 1M, override with `CONTEXT_CHECK_WINDOW`. Off switch: `touch ~/.claude/hooks/context-check.disabled`.

**`CLAUDE.md.example`**, an optional rule that has Claude offer a structured choice at context-boundary time (new-chat handoff, clear and stay, or continue) instead of silently dragging a bloated conversation forward. `context-check.sh` supplies the numeric trigger; Claude still judges whether the task is actually closed.

**`/refresh-rules`** re-reads CLAUDE.md and the routing skill inside an already-open chat, for when you've edited them mid-session and don't want to restart.

**`/usage-report`** shows a token/model report for the current session, computed from the transcript, on request.

**`/routing-status`** cross-checks that routing is actually working: reads `route-gate.log` for what was gated this session and the transcript for real per-model token totals, independent of anything Claude says about itself.

## Commands

`/refresh-rules`, `/usage-report`, and `/routing-status` are slash commands you run yourself; nothing here fires automatically. An earlier version of this project forced a token report at the end of every reply via a `Stop` hook — removed 2026-07-21 after a habit-driven duplicate-line bug that a text-only fix couldn't reliably prevent. Stats now show up only when asked.

```
/routing-status
```

```
Routing:
  dev              x4   allow-tier
  cheap            x6   allow-tier
  Explore          x2   rewrite-haiku
  general-purpose  x1   deny-no-model

Tokens:
  Sonnet 5    142,300  (61%)
  Haiku 4.5    58,900  (25%)
  Opus 4.8     32,100  (14%)
```

`deny-no-model` climbing means agents keep spawning with no model named. `rewrite-haiku` above zero means the Explore auto-route is actually firing.

## Honest limitations

- **No real per-task "effort" dial.** Model choice is the real lever; per-tier thinking depth is simulated through prompt instructions, not enforced.
- **Model names and prices will go stale.** The relative ordering in `SKILL.md` is the load-bearing logic; check current pricing before trusting numbers.
- **These are real shell scripts that run on every response or agent spawn, in every project, once installed.** Read them before installing.
- **This reflects one workflow, not a universal one.** Adjust the tier descriptions in `SKILL.md` to your own task mix.
- **`context-check.sh` forces a tool call only at the hard mark; the soft mark is a nudge Claude can decline,** and it only samples at turn boundaries, so a single turn can jump past auto-compact before it fires.
- **A forced per-reply report was tried and abandoned** over a duplicate-line bug a text-only fix couldn't hold. On-demand commands don't have that failure mode, but you have to remember to ask.

## Install

### As a plugin (recommended)

```
/plugin marketplace add reganomika/Bullpen
/plugin install bullpen@bullpen
```

A local clone path works the same way in place of `reganomika/Bullpen`. Registers all four agents, all four skills, and both hooks (`context-check.sh` on `Stop`, `route-gate.sh` on `PreToolUse`) in one step. Restart Claude Code (or `/reload-plugins`) once after install; skill edits apply live from then on.

`CLAUDE.md.example` never auto-installs — the plugin system doesn't load CLAUDE.md files. Append it to your own `~/.claude/CLAUDE.md` by hand.

### Copy into your own config (no plugin system)

```bash
git clone <this-repo-url>
cp <repo>/agents/*.md ~/.claude/agents/
cp -r <repo>/skills/model-routing <repo>/skills/usage-report <repo>/skills/refresh-rules <repo>/skills/routing-status ~/.claude/skills/
mkdir -p ~/.claude/hooks
cp <repo>/hooks/route-gate.sh <repo>/hooks/context-check.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/route-gate.sh ~/.claude/hooks/context-check.sh
```

Add to `~/.claude/settings.json` (merge into your existing file):

```json
{
  "hooks": {
    "Stop": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/context-check.sh" }] }],
    "PreToolUse": [{ "matcher": "Agent|Task", "hooks": [{ "type": "command", "command": "~/.claude/hooks/route-gate.sh" }] }]
  }
}
```

Start a new session to pick up the agents, skills, and hooks. Append `CLAUDE.md.example` to your own CLAUDE.md if you want it. Off switch for either hook: `touch ~/.claude/hooks/<name>.disabled`, back on with `rm`.

### Try without installing

```bash
claude --plugin-dir <path-to-this-repo>
```

## License

MIT, see `LICENSE`.
