<p align="center">
  <img src="assets/logo.svg" alt="Bullpen" width="340">
</p>

Cost-aware task routing for Claude Code: four subagents pinned to four model tiers, a skill that decides which one to call, a hook that forces a real token-usage report after every exchange, and a second hook that forces a context-boundary checkpoint before your window quietly drains your budget.

## The problem this solves

Claude Code makes it easy to run every task on your most capable model, and just as easy to forget you're doing it. In long agentic sessions, the conversation history gets reprocessed on every turn: for typical multi-hour coding sessions, tokens spent re-reading accumulated context routinely dwarf the tokens spent on actual output, by an order of magnitude. Model choice matters. How much history you drag along usually matters more.

Bullpen is the routing system built to fix that. The honest version of the pitch: the savings come from sending search, recon, and mechanical work to the cheapest model (enforced by a gate on the agent-spawn path, not by advice), while same-model delegation buys context isolation, not discounts. A running receipt after every exchange shows what actually ran, so you see it working instead of taking it on faith.

## What's in here

**Four subagents** (`agents/`), each pinned to one model tier:

- `cheap` — fully specified mechanics: renames, cleanups, boilerplate, doc edits, glossary translations; strongest as parallel fan-out over lists of small chunks
- `dev` — the default executor for self-contained implementation: features, scoped refactors, build/run checks. Same model as your main session, so it buys context isolation and parallelism, not savings
- `hard` — known-hard work, entered proactively: adversarial reviews, races, API/schema migrations, staged sync verification, 10+ coupled files. Two failed attempts below also qualify, but are not required
- `super` — frontier tier for confirmed hard-tier failure, unsplittable multi-hour autonomous runs, or maximum cost of error; the route-gate hook raises a native confirmation dialog instead of a chat ceremony

**A routing skill** (`skills/model-routing/SKILL.md`) that decides which tier to call, what not to delegate at all (destructive git operations, secrets, personal/legal/financial documents, anything that needs a clarification an autonomous subagent can't ask for), and how to hand off accumulated context between escalating tiers so the expensive model doesn't re-pay for discovery the cheap one already did. It also governs the built-in `Explore` and `general-purpose` agents and the Agent tool's per-call `model` parameter, which otherwise silently inherit your session model.

**A forcing hook** (`hooks/token-report.sh`) on Claude Code's `Stop` event. It computes the real token delta for the exchange that just happened (from the session's own transcript) and blocks the response from ending until the model appends an honest usage report — this isn't a prompt Claude can quietly skip, it's a shell script the harness runs on every turn. Guarded against infinite loops via the `stop_hook_active` field. Report format: one line, every model that actually ran this reply (main session and any agents together) with its share of this reply's total output tokens as a percentage:

```
> 🖥️ **Sonnet 5** (70%) | **Opus 4.8** (30%)
```

A single tier called for the whole reply just shows (100%) for it alone.

**An enforcement hook** (`hooks/route-gate.sh`) on Claude Code's `PreToolUse` event for `Agent`/`Task` calls. Advisory prose about routing demonstrably did nothing in this system's own history; a gate on the spawn path did. What it does: tier agents pass untouched; `Explore` with no `model` is auto-rewritten to run on haiku (pass an explicit model to override); `general-purpose` with no `model` is denied with instructions until a model is named; `super` raises a native confirmation dialog. Calls from inside subagents, unknown agent types, and `bypassPermissions` sessions all pass untouched. Every decision is logged to `~/.claude/hooks/state/route-gate.log` (TSV), which is also your health check: **the hook fails open by design** (missing jq, changed payload shape, renamed tools), so if the log goes quiet while you are clearly spawning agents, the gate is dead and old behavior is back. Instant off switch: `touch ~/.claude/hooks/route-gate.disabled`; on again with `rm`. The script contains no dollar figures on purpose; prices go stale, tier order does not.

**A second forcing hook** (`hooks/context-check.sh`) on the same `Stop` event. Advisory prose asking Claude to notice context bloat demonstrably never fired during long absorbing sessions; a hook does. It reads the real context size from the transcript (summed usage of the last main-session assistant message, tracked per model so a `/model` switch does not skew it) and, past a percentage of the model's window, blocks the response until Claude raises the task-boundary checkpoint. Two tiers, both scaled to the window (`CONTEXT_CHECK_WINDOW` overrides it, default 1M): a soft mark (~55%) that is an advisory text nudge Claude may decline for focused continuous work, and a hard mark (~88%, before the harness auto-compacts near ~99%) that forces an `AskUserQuestion` and re-fires every turn until the checkpoint actually appears in the transcript. It shares the `Stop` event with `token-report.sh` but never its state (separate `<session_id>.context.json` file), and both honor `stop_hook_active`. Fails open (missing jq, no transcript, bad payload). Instant off switch: `touch ~/.claude/hooks/context-check.disabled`; on again with `rm`.

**An optional CLAUDE.md rule** (`CLAUDE.md.example`) that has Claude proactively flag context bloat and offer a structured choice instead of silently dragging a bloated conversation forward: generate a handoff prompt for a new chat, suggest clearing the current one, or keep going. The rule is hook-backed now, not advisory-only: `context-check.sh` supplies the numeric half (is context actually large), Claude still judges the semantic half (is the task closed, is the old history still needed).

**A refresh command** (`skills/refresh-rules/SKILL.md`, invoked as `/refresh-rules`) for when you edit CLAUDE.md or the routing skill while a chat is already open. Claude Code loads CLAUDE.md into the system prompt once at session start and doesn't hot-reload it, so an already-running chat keeps following whatever was true when it started, not what the file says now. `/refresh-rules` re-reads the current files and applies them for the rest of that session, no restart needed. It only helps with rule and format changes in files that were already installed: brand-new agents or newly registered hooks still need a fresh session, that's a harness-level thing this command can't reach into.

## Honest limitations

- **Subagents don't get a real per-task "effort" dial.** Model choice is a real lever; per-tier thinking depth is simulated through prompt instructions, not an enforced parameter. Don't expect literal control over reasoning depth per agent, only over which model runs it.
- **Model names and prices will go stale.** Treat the relative ordering (cheapest to priciest) as the load-bearing logic in `SKILL.md`. Check current pricing before trusting any specific numbers written there.
- **The hook is a real shell script that runs on every response, in every project, once installed.** Read it before installing it — that's true of any hook from anyone, not just this one.
- **This reflects one workflow, not a universal one.** It grew out of software development work with some content and document tasks mixed in. Adjust the tier descriptions in `skills/model-routing/SKILL.md` to match your own task mix before relying on it.
- **The context hook forces a real tool call only at the hard (~88%) tier; the soft tier is a text nudge Claude can decline.** And it only samples at turn boundaries, so a single turn that jumps from below the hard mark past the auto-compact point can still be compacted by the harness before it fires.

## Install

### Copy into your own config (simplest)

```bash
git clone <this-repo-url>
cp <repo>/agents/*.md ~/.claude/agents/
cp -r <repo>/skills/model-routing ~/.claude/skills/
cp -r <repo>/skills/usage-report ~/.claude/skills/
cp -r <repo>/skills/refresh-rules ~/.claude/skills/
mkdir -p ~/.claude/hooks
cp <repo>/hooks/token-report.sh ~/.claude/hooks/
cp <repo>/hooks/route-gate.sh ~/.claude/hooks/
cp <repo>/hooks/context-check.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/token-report.sh ~/.claude/hooks/route-gate.sh ~/.claude/hooks/context-check.sh
```

Then add the hooks to `~/.claude/settings.json` (merge into your existing file, don't overwrite it):

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [
        { "type": "command", "command": "~/.claude/hooks/token-report.sh" },
        { "type": "command", "command": "~/.claude/hooks/context-check.sh" }
      ] }
    ],
    "PreToolUse": [
      {
        "matcher": "Agent|Task",
        "hooks": [ { "type": "command", "command": "~/.claude/hooks/route-gate.sh" } ]
      }
    ]
  }
}
```

Start a new Claude Code session (or restart the current one) to pick up the new agents, skills, and hooks. Optionally, append the contents of `CLAUDE.md.example` to your own `~/.claude/CLAUDE.md`. Later on, once this is installed, editing CLAUDE.md or the routing skill again doesn't require a restart for chats you want to keep open: run `/refresh-rules` in them instead.

To turn the forced report off (globally, instantly, no restart needed): `touch ~/.claude/hooks/token-report.disabled`. Back on: `rm ~/.claude/hooks/token-report.disabled`. Context checkpoint off: `touch ~/.claude/hooks/context-check.disabled`, back on with `rm`.

### Try without installing

```bash
claude --plugin-dir <path-to-this-repo>
```

## License

MIT, see `LICENSE`.
