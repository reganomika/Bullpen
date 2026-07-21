# FAQ

### I installed the plugin but my existing chat isn't using it. Is it broken?

No. Claude Code loads agent definitions and hook registrations once, when a session starts, and never reloads them mid-session. A chat that was already open when you installed (or reinstalled) Bullpen keeps running on whatever it had at its own start, forever, until you close it. Restart that chat — a brand-new session started after install gets everything automatically, no extra step needed.

`/refresh-rules` doesn't fix this either. It re-reads CLAUDE.md and the routing skill's text into an already-open chat, which works for behavioral rules, but it cannot add a new agent type or a new hook registration to a running session — that's not something any command can do from inside the chat, it's a harness-level limit.

### I appended CLAUDE.md.example but nothing changed.

`CLAUDE.md.example` never installs itself — not via the plugin, not on restart, not automatically under any circumstance. The plugin system deliberately doesn't load CLAUDE.md files. You have to open it and copy its contents into your own `~/.claude/CLAUDE.md` by hand, every time you want to pick up a change to it.

### Why doesn't a token report show up after every reply anymore?

It doesn't, on purpose. An earlier version forced one via a `Stop` hook. That was removed because it hit a habit-driven duplicate-line bug that a text-only fix in CLAUDE.md couldn't reliably prevent — the model kept writing a report line out of habit before the hook actually fired, then the hook fired for real and forced a second one. Ask for numbers instead: `/usage-report` for a quick token/model total, `/routing-status` for that plus the routing table.

### `route-gate.sh` blocked or denied my agent call. Is that a bug?

No, that's the hook working as designed. `general-purpose` with no `model` parameter gets denied until you name one; `Explore` with no `model` gets silently rewritten to run on haiku instead of being denied. Either pass an explicit `model`, or use the named `cheap`/`dev`/`hard`/`super` agents, which already have their model pinned in frontmatter and pass through untouched.

### Why does spawning `super` ask me to confirm every time?

That's the point of the tier. `super` is the most expensive model available, so the confirmation dialog is the budget approval, instead of relying on you to remember to ask for one in chat.

### Does any of this send my data anywhere?

No. Every hook here is a local shell script that reads your own session transcript file on disk and writes small state files under `~/.claude/hooks/state/`. Nothing here makes a network call. Don't take that on faith — the scripts are short, read them yourself before trusting the claim.

### The model names and prices in `SKILL.md` look wrong or outdated.

They will drift over time; this repo won't always get updated the same day pricing changes. What matters is the relative tier order (cheapest to priciest), not the specific dollar figures. Check current pricing separately before trusting any number written there.

### Can I use this with claude.ai or the API instead of Claude Code?

No. Agents, skills, and hooks are Claude Code–specific concepts (the CLI and desktop app). None of it applies to claude.ai or direct API usage.

### How do I turn a hook off without uninstalling anything?

`touch ~/.claude/hooks/route-gate.disabled` or `touch ~/.claude/hooks/context-check.disabled`. Instant, no restart needed — each hook checks for its own flag file fresh on every run. Delete the file to turn it back on.

### Can I swap in my own agents instead of cheap/dev/hard/super?

Yes. The routing skill and `route-gate.sh` don't care what `subagent_type` you use, only that every `Agent`/`Task` call names a model. Write your own agent definitions and keep the enforcement hook as-is.

### Can I control how deeply a subagent thinks, not just which model it uses?

No separate effort dial. Model choice is the real lever here; per-tier thinking depth (`cheap` answers fast, `super` deliberates at length) is simulated through each agent's prompt instructions, not an enforced parameter.

### The tier descriptions don't match my kind of work.

They reflect a software-development-heavy workflow with some writing and document tasks mixed in. Edit `skills/model-routing/SKILL.md` directly — the route table and worked examples are meant to be adjusted to your own task mix, not treated as fixed.
