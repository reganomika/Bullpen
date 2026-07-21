<p align="center">
  <img src="assets/logo.svg" alt="Bullpen" width="460">
</p>

Cost-aware task routing for Claude Code. Four subagents pinned to four model tiers, a skill that picks the right one for each task, and hooks that enforce the routing and context rules mechanically instead of relying on the model to remember.

## What's in here

**Four subagents** (`agents/`), each pinned to one model tier:

- `cheap` — fully specified mechanics: renames, cleanups, boilerplate, doc edits, translations. Runs well as parallel fan-out over lists of small chunks
- `dev` — default executor for self-contained implementation: features, scoped refactors, build/run checks. Same model as your main session; the win is context isolation and parallelism, not a cheaper price
- `hard` — known-hard work: adversarial reviews, races, API/schema migrations, staged sync verification, changes across 10+ coupled files
- `super` — frontier tier for confirmed hard-tier failure, long unsplittable autonomous runs, or maximum cost of error. Spawning it raises a native confirmation dialog

**A routing skill** (`skills/model-routing/SKILL.md`) picks the tier for each task, lists what never gets delegated (destructive git, secrets, personal/legal/financial documents), and defines how context gets handed up when a task escalates to a pricier tier. It also covers the built-in `Explore` and `general-purpose` agents and the Agent tool's `model` parameter, which otherwise silently inherit your session's model.

**`route-gate.sh`**, a hook on every `Agent`/`Task` spawn. `Explore` with no model set runs on haiku automatically; `general-purpose` with no model set is blocked until one is named; spawning `super` asks for confirmation. Every decision is logged to `~/.claude/hooks/state/route-gate.log`. Off switch: `touch ~/.claude/hooks/route-gate.disabled`.

**`context-check.sh`**, a hook that watches context size and, once it crosses a threshold, has Claude offer to hand off to a new chat, clear the current one, or continue. Soft threshold at ~55% of the window, hard threshold at ~88%. Window defaults to 1M, override with `CONTEXT_CHECK_WINDOW`. Off switch: `touch ~/.claude/hooks/context-check.disabled`.

**`CLAUDE.md.example`**, a rule you add to your own `~/.claude/CLAUDE.md` that wires the context-boundary offer above into Claude's behavior.

**`/refresh-rules`** — re-reads CLAUDE.md and the routing skill inside an already-open chat, for when you've edited them mid-session.

**`/usage-report`** — shows a token/model report for the current session, computed from the transcript.

**`/routing-status`** — shows a table of what route-gate actually allowed, rewrote, or blocked this session, plus real per-model token totals.

## Using the commands

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

`deny-no-model` climbing means agents keep spawning with no model named. `rewrite-haiku` above zero means the Explore auto-route is firing.

```
/usage-report
```

Same idea, simpler: just the token/model totals for this session.

```
/refresh-rules
```

Run this in a chat that's been open since before you last edited CLAUDE.md or the routing skill, so it picks up the current rules without a restart.

## Good to know

- Model choice is the real lever here. Subagents don't get a separate "effort" dial; thinking depth per tier is simulated through the prompt, not enforced.
- `SKILL.md` names specific models and prices for reference — check current pricing before trusting the numbers, and treat the tier order (cheapest to priciest) as the part that matters.
- The hooks are real shell scripts that run on every response or agent spawn, in every project, once installed. Read them before installing.
- Tier descriptions in `skills/model-routing/SKILL.md` reflect a software-dev-heavy workflow. Adjust them to your own task mix.
- Token and routing stats are on-demand only, via the two commands above — nothing gets printed automatically at the end of a reply.

## Install

### As a plugin (recommended)

```
/plugin marketplace add reganomika/Bullpen
/plugin install bullpen@bullpen
```

A local clone path works the same way in place of `reganomika/Bullpen`. Registers all four agents, all four skills, and both hooks in one step. Restart Claude Code (or `/reload-plugins`) once after install; skill edits apply live from then on.

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
