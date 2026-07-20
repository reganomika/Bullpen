# Bullpen

Cost-aware task routing for Claude Code: four subagents pinned to four model tiers, a skill that decides which one to call, a hook that forces a real token-usage report after every exchange, and an optional rule that stops your context window from quietly draining your budget.

## The problem this solves

Claude Code makes it easy to run every task on your most capable model, and just as easy to forget you're doing it. In long agentic sessions, the conversation history gets reprocessed on every turn: for typical multi-hour coding sessions, tokens spent re-reading accumulated context routinely dwarf the tokens spent on actual output, by an order of magnitude. Model choice matters. How much history you drag along usually matters more.

Bullpen is the routing system built to fix that: same output quality, meaningfully fewer tokens, without babysitting a model picker on every message, and with a running receipt so you can see it actually working instead of taking it on faith.

## What's in here

**Four subagents** (`agents/`), each pinned to one model tier:

- `cheap` — mechanical work: formatting, renames, boilerplate, doc edits, simple file operations
- `dev` — regular development: features, routine refactors, debugging, tests. Same model as your main session by default, so delegating here is about isolating context, not saving money
- `hard` — genuinely hard problems: flaky or racy bugs, API/schema migrations, cross-file refactors
- `super` — last resort, only after `hard` explicitly reports it can't solve the task in one pass, or for tasks with unusually high cost of error

**A routing skill** (`skills/model-routing/SKILL.md`) that decides which tier to call, what not to delegate at all (destructive git operations, secrets, personal/legal/financial documents, anything that needs a clarification an autonomous subagent can't ask for), and how to hand off accumulated context between escalating tiers so the expensive model doesn't re-pay for discovery the cheap one already did.

**A forcing hook** (`hooks/token-report.sh`) on Claude Code's `Stop` event. It computes the real token delta for the exchange that just happened (from the session's own transcript) and blocks the response from ending until the model appends an honest usage report — this isn't a prompt Claude can quietly skip, it's a shell script the harness runs on every turn. Guarded against infinite loops via the `stop_hook_active` field. Report format:

```
> 🖥️ Main session — **Sonnet 5**, spent 13,481 tokens
> 🤖 Agents:
> — **Opus 4.8**, spent 45,200 tokens
```

The agents block is only shown when a subagent actually ran that turn.

**An optional CLAUDE.md rule** (`CLAUDE.md.example`) that has Claude proactively flag context bloat and offer a structured choice instead of silently dragging a bloated conversation forward: generate a handoff prompt for a new chat, suggest clearing the current one, or keep going.

## Honest limitations

- **Subagents don't get a real per-task "effort" dial.** Model choice is a real lever; per-tier thinking depth is simulated through prompt instructions, not an enforced parameter. Don't expect literal control over reasoning depth per agent, only over which model runs it.
- **Model names and prices will go stale.** Treat the relative ordering (cheapest to priciest) as the load-bearing logic in `SKILL.md`. Check current pricing before trusting any specific numbers written there.
- **The hook is a real shell script that runs on every response, in every project, once installed.** Read it before installing it — that's true of any hook from anyone, not just this one.
- **This reflects one workflow, not a universal one.** It grew out of software development work with some content and document tasks mixed in. Adjust the tier descriptions in `skills/model-routing/SKILL.md` to match your own task mix before relying on it.

## Install

### Copy into your own config (simplest)

```bash
git clone <this-repo-url>
cp <repo>/agents/*.md ~/.claude/agents/
cp -r <repo>/skills/model-routing ~/.claude/skills/
cp -r <repo>/skills/usage-report ~/.claude/skills/
mkdir -p ~/.claude/hooks
cp <repo>/hooks/token-report.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/token-report.sh
```

Then add the hook to `~/.claude/settings.json` (merge into your existing file, don't overwrite it):

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command", "command": "~/.claude/hooks/token-report.sh" } ] }
    ]
  }
}
```

Start a new Claude Code session (or restart the current one) to pick up the new agents, skills, and hook. Optionally, append the contents of `CLAUDE.md.example` to your own `~/.claude/CLAUDE.md`.

To turn the forced report off (globally, instantly, no restart needed): `touch ~/.claude/hooks/token-report.disabled`. Back on: `rm ~/.claude/hooks/token-report.disabled`.

### Try without installing

```bash
claude --plugin-dir <path-to-this-repo>
```

## License

MIT, see `LICENSE`.
