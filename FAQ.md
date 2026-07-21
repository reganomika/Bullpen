# FAQ

### I installed the plugin but my existing chat isn't using it. Is it broken?

Depends which piece. The hook (`route-gate.sh`), yes: Claude Code registers `PreToolUse`/`Stop` hooks from `settings.json` once when a session starts and never reloads them mid-session, so a chat that was already open when you installed keeps running without it until you close it.

Agents are less absolute. Claude Code watches `~/.claude/agents/` and `.claude/agents/` directly and, per its own docs, picks up a new or edited file there within seconds, no restart, as long as that directory already existed before the session started. If you installed by copying files into `~/.claude/agents/` and that directory already had something in it, an already-open chat may well see `cheap`/`dev`/`hard`/`super` without a restart. If the directory was empty or didn't exist (a fresh setup), or if you installed via the plugin (a different, unverified-by-us mechanism), don't count on it, restart to be sure.

`/refresh-rules` doesn't fix either case. It re-reads CLAUDE.md and the routing skill's text into an already-open chat, which works for behavioral rules, but it cannot add a new agent type or a new hook registration to a running session, that's not something any command can do from inside the chat, it's a harness-level limit.

### I appended CLAUDE.md.example but nothing changed.

`CLAUDE.md.example` never installs itself: not via the plugin, not on restart, not automatically under any circumstance. The plugin system deliberately doesn't load CLAUDE.md files. You have to open it and copy its contents into your own `~/.claude/CLAUDE.md` by hand, every time you want to pick up a change to it.

### Why doesn't a token report show up after every reply anymore?

It doesn't, on purpose. An earlier version forced one via a `Stop` hook. That was removed because it hit a habit-driven duplicate-line bug that a text-only fix in CLAUDE.md couldn't reliably prevent: the model kept writing a report line out of habit before the hook actually fired, then the hook fired for real and forced a second one. Ask for numbers instead: `/usage-report` for a quick token/model total, `/routing-status` for that plus the routing table.

### `route-gate.sh` blocked or denied my agent call. Is that a bug?

No, that's the hook working as designed. `general-purpose` with no `model` parameter gets denied until you name one; `Explore` with no `model` gets silently rewritten to run on haiku instead of being denied (both configurable, see the environment-variable question below). Either pass an explicit `model`, or use the named `cheap`/`dev`/`hard`/`super` agents, which already have their model pinned in frontmatter and pass through untouched.

### What does route-gate.sh actually enforce, and what's still just advice?

Three mechanical checks, no more: `Explore` or `general-purpose` must have a model named (one auto-routes to haiku, the other gets denied until you name one), and spawning the ask-tier (`super` by default) raises a confirmation dialog. That's the whole enforcement surface. Whether a task should go to `cheap`, `dev`, or `hard` in the first place, the route table in `skills/model-routing/SKILL.md`, is prose the model has to read and follow, the hook has no way to judge task-to-tier fit and doesn't try. `Plan` mode isn't gated at all (see the code comment in `route-gate.sh`, it falls into the same catch-all as any custom or future built-in agent type). If a tier agent's own pinned model gets silently swapped by `CLAUDE_CODE_SUBAGENT_MODEL`, the hook still logs it (see that question above), but it can't stop it, that resolution happens above the hook.

### Why does spawning `super` ask me to confirm every time?

That's the point of the tier. `super` is the most expensive model available, so the confirmation dialog is the budget approval, instead of relying on you to remember to ask for one in chat.

### Does any of this send my data anywhere?

No. Every hook here is a local shell script that reads your own session transcript file on disk and writes small state files under `~/.claude/hooks/state/`. Nothing here makes a network call. Don't take that on faith: the scripts are short, read them yourself before trusting the claim.

### The model names and prices in `SKILL.md` look wrong or outdated.

They will drift over time; this repo won't always get updated the same day pricing changes. What matters is the relative tier order (cheapest to priciest), not the specific dollar figures. Check current pricing separately before trusting any number written there.

### Can I use this with claude.ai or the API instead of Claude Code?

No. Agents, skills, and hooks are Claude Code–specific concepts (the CLI and desktop app). None of it applies to claude.ai or direct API usage.

### Should I turn on Ultracode/Workflow orchestration everywhere for better quality?

No, it's the most expensive mode available, not a quality dial. It runs several agents in parallel on one task, which multiplies token spend without making the model doing the actual work any better; model choice and the routing skill already cover quality. Leave it off by default and turn it on per task, only when you specifically want multi-agent orchestration for that piece of work.

### How do I turn the hook off without uninstalling anything?

`touch ~/.claude/hooks/route-gate.disabled`. Instant, no restart needed: the hook checks for this flag file fresh on every run. Delete the file to turn it back on.

### How do I uninstall this completely?

Plugin install: `/plugin uninstall bullpen@bullpen`. Copy-into-config install: there's no tracking of what got copied, so remove the agent, skill, and hook files by hand, plus the CLAUDE.md sections if you appended `CLAUDE.md.example`. Exact commands: [INSTALL.md](INSTALL.md#uninstall). Either way, chats already open when you uninstall keep running with everything still loaded until you close them, same one-way restart rule as install.

### Can I swap in my own agents instead of cheap/dev/hard/super?

Yes. The routing skill and `route-gate.sh` don't care what `subagent_type` you use, only that every `Agent`/`Task` call names a model. Write your own agent definitions and keep the enforcement hook as-is, then tell the hook about the new names, see the next question.

### Can a name collision silently break a tier?

Yes, if you installed via the plugin. Claude Code resolves same-named agents by scope priority: managed settings, then the `--agents` CLI flag, then your project's `.claude/agents/`, then your user-level `~/.claude/agents/`, and plugin agents last, lowest priority of all. If you (or another plugin) ever define your own agent named `dev`, `cheap`, `hard`, or `super` at the project or user level, it silently wins over Bullpen's, with no warning from anything, `route-gate.sh` included, since the hook only sees the winning `subagent_type` string, not which definition backed it. Renaming your own agent, or renaming Bullpen's tiers via the `ROUTE_GATE_*` variables from the previous question, are the two ways out.

### I renamed or added a tier. Do I need to change anything else?

Yes, `route-gate.sh`. It doesn't infer tier names from your agent files, it reads them from environment variables (set in the `env` block of `~/.claude/settings.json`, or your shell profile):

```bash
ROUTE_GATE_TIER_AGENTS="cheap,dev,hard"    # pass through untouched, comma-separated
ROUTE_GATE_ASK_AGENT="super"               # gets the native confirmation dialog
ROUTE_GATE_AUTOROUTE_AGENT="Explore"       # auto-routed to a cheap model when no model is set
ROUTE_GATE_AUTOROUTE_MODEL="haiku"         # the model it's routed to
ROUTE_GATE_DENY_AGENT="general-purpose"    # denied until a model is named
```

Rename `super` to your own top tier's name without setting `ROUTE_GATE_ASK_AGENT` to match, and the confirmation dialog silently stops firing for it, the gate has no way to know a renamed agent was meant to inherit the old behavior. Adding a fourth tier agent (say a `research` tier) just means adding it to `ROUTE_GATE_TIER_AGENTS`, no script edit needed. Only set the variables that differ from the defaults above.

### Does anything override a tier's pinned model even when route-gate.sh allows it?

Yes: `CLAUDE_CODE_SUBAGENT_MODEL`, a Claude Code environment variable, not one of ours. If it's set, Claude Code resolves it before the per-invocation `model` parameter and before the subagent's own frontmatter, so it silently overrides even a tier agent's pinned model. `route-gate.sh` can't stop this, it isn't a decision the hook gets consulted on, but it does detect the variable and log `allow-tier-model-overridden` instead of a plain `allow-tier`, recording the overriding model instead of pretending the frontmatter model ran. Treat that log entry as observed, not verified: the hook only sees its own copy of the environment. If the override value is excluded by an organization's `availableModels` allowlist, Claude Code silently skips it and falls back to the inherited model instead, and the hook has no way to know that happened, so the logged value can be wrong in that specific case. Check `/routing-status` if a tier's token cost looks wrong regardless, this variable is the first thing to rule out. Setting it to `inherit` is a no-op as of Claude Code v2.1.196+, same as leaving it unset.

### Can I control how deeply a subagent thinks, not just which model it uses?

Yes, real and enforced, not simulated through prompt instructions the way earlier versions of these docs claimed. Claude Code subagents support an `effort` frontmatter field that overrides the session's effort level, and each of the four tiers pins one: cheap=low, dev=high, hard=xhigh, super=max.

Which levels a model actually supports varies, and using an unsupported one isn't an error, Claude Code silently clamps down to the highest level the model does support (`xhigh` runs as `high` on a model that tops out there, for instance):

| Model (tier that uses it)     | Supported levels                        |
| :----------------------------- | :--------------------------------------- |
| Fable 5 (`super`)              | `low`, `medium`, `high`, `xhigh`, `max`  |
| Sonnet 5 (`dev`), Opus 4.8 (`hard`) | `low`, `medium`, `high`, `xhigh`, `max`  |
| Haiku (`cheap`)                | Not listed as supporting effort at all   |

`hard`'s `xhigh` and `super`'s `max` are both genuinely supported by the models those tiers currently pin. `cheap`'s `effort: low` is very likely a no-op on Haiku, present for documentation and consistency, not because it changes anything, cheap gets its speed and cost from the model choice alone. If a tier's `model:` ever changes to something with a smaller effort range, its `effort:` value degrades gracefully to that model's ceiling rather than erroring.

### Does `effort` control extended thinking too?

Partially, and it depends which tier. Subagents inherit the main session's extended-thinking on/off setting as a plain toggle, there's no per-subagent override for that toggle specifically, only for how deep the thinking goes once it's on, which is what `effort` actually controls. For `super` (Fable 5), this doesn't matter: thinking cannot be disabled on Fable 5 at all, the session toggle has no effect there, so `effort: max` always gets real reasoning depth regardless of your session's thinking setting. For `dev` and `hard` (Sonnet 5, Opus 4.8), it does matter: if the session has extended thinking fully off, that setting carries into the subagent and their `effort: high`/`xhigh` won't produce actual extended thinking output, even though the effort level itself is still what's set. Check your session's thinking toggle if `hard` or `dev` seem to be reasoning less carefully than `effort` alone would suggest.

### The tier descriptions don't match my kind of work.

They reflect a software-development-heavy workflow with some writing and document tasks mixed in. Edit `skills/model-routing/SKILL.md` directly: the route table and worked examples are meant to be adjusted to your own task mix, not treated as fixed.
