---
name: model-routing
description: Route every Agent/Task call, including the built-in Explore and general-purpose agents, choose the per-call model parameter (haiku/sonnet/opus/fable), and dispatch work to the cheap/dev/hard/super subagents. Use before the first agent spawn in a task, when choosing between inline work and delegation, and for questions about model choice, effort level, or token spend.
metadata:
  trigger: First agent spawn in a task; any Agent/Task call; inline-vs-delegate choice; questions about model, effort, token spend
---

# Model routing and effort

## Precedence

Explicit user instruction (a specific model, a specific agent, a no-delegation rule) beats every rule below. The kernel in CLAUDE.md is the compressed copy of this skill for turns where the skill is not loaded. On divergence, the more detailed wording here wins, and the divergence gets fixed by editing both files.

## Tiers and the session default

Four tiers from cheapest to most expensive model: `cheap` (cheapest), `dev` (balanced, same class as the main session), `hard` (powerful), `super` (frontier, the most expensive available). Keep the relative ordering as the load-bearing logic; check Anthropic's current pricing before trusting any specific numbers. `cheap` and haiku spawns have a smaller context window (200K vs 1M for the rest). The main-session default is the balanced tier at high effort, set once via `/model`; escalation goes through agents, not through switching the session model.

Subagents have no real effort parameter; the desired depth is simulated by prompt instructions (cheap answers briefly, super deliberates exhaustively).

## Ultracode is not a fifth tier

Ultracode (Workflow, multi-agent orchestration) is the most expensive mode in the system: it runs several agents in parallel on one task. Turning it on everywhere multiplies spend without picking a better tier for anything, it sits outside the four-tier model above. Keep it off by default. Enable it only on an explicit user request for that specific task in chat, never automatically because a task looks hard.

## The iron rule: a model on every spawn

Every Agent/Task call has a model parameter: haiku, sonnet, opus, fable, inherit. The built-in Explore and general-purpose agents silently inherit the main session's model without it, which means they cost as much as dev. That is a routing miss, not a neutral default. Write inherit only deliberately, and name the reason in one line. The named agents cheap/dev/hard/super pin their model in frontmatter; call them by name with no parameter.

If the route-gate hook is installed (PreToolUse on Agent/Task, see README): Explore without a model is auto-routed to haiku; general-purpose without a model is denied until a model is named; a super spawn raises a native confirmation dialog. The hook's messages are routing checkpoints, not errors. Do what they ask and re-issue the call. Every decision is logged to ~/.claude/hooks/state/route-gate.log; off switch: `touch ~/.claude/hooks/route-gate.disabled`.

## Route table (obligations, not permissions)

- Search and recon: "where is X defined", grep sweeps, hash-diffs, file-list gathering, single-field lookups: Explore or general-purpose with model: haiku. Sonnet for recon only when synthesis across several subsystems is needed, and that need is named in the spawn prompt.
- Fully specified mechanics: bulk renames and word-form replacements, repository and .gitignore cleanups, deleting files strictly by explicitly named paths, boilerplate, uniform markdown and doc edits, translations against a ready glossary, long templated output, commit formatting from a ready diff: cheap. Batch same-shaped small items into one spawn as a list.
- Self-contained implementation: features, scoped refactors, localizations, UI edits from an approved decision, build and run checks, debugging and tests, code questions that need conclusions rather than raw findings: dev. This is the default executor for code. The gain is not price (same model), it is context isolation and parallelism: the main session stays light and lives longer without a handoff. Delegate too when a task needs many back-and-forth steps, not just large output: an investigation, comparison, or diagnosis with dozens of small round trips bloats the history that gets reread every turn, even if no single step is big.
- Known-hard work: straight to hard, no prior failures required, on any of: adversarial reviews of correctness or security; races, concurrency, unstable reproduction; a public-API or data-schema migration; staged sync verification with hash-diff and pre-sync checks (the overwrite act itself stays in the main session); a coupled change across ~10+ files. The reactive entry also applies: two attempts in the main session or on dev without a confirmed result.
- super: confirmed hard-tier failure; known multi-hour unsplittable autonomous work; maximum cost of error (critical data migrations, payment and subscription flows). No separate chat-approval ceremony: the hook raises the confirmation dialog, and that is the budget approval. High stakes raise the strictness of result verification, not the tier.
- On any escalation, pass everything the lower tier learned upward: diagnosis, repro steps, affected files, tested and rejected hypotheses. Otherwise the expensive model re-pays for finished reconnaissance.

## Inline is the exception, with a named reason

A subagent is autonomous: it cannot see the conversation or ask questions. That is solved by prompt completeness, not by refusing to delegate. Work in the main session only when one of these applies:
- (a) the task is on the never-delegate list below;
- (b) the next step depends on the owner's reply within this same exchange: screenshot-approval iterations, design-tool prompts, questions about the dialog itself. The mere fact that a task grew out of the conversation does not count;
- (c) an edit up to ~20 lines in an exactly known place, where a spawn prompt carrying the context would be longer than the edit itself;
- (d) the user explicitly asked for it to be done in the main session.

Nothing applies: route by the table. An unresolved fork in the task: ask the owner in chat, then spawn the agent with the decision baked into the prompt, instead of keeping the task yourself.

## Never delegate (main session only)

- Secrets and release procedures: credentials, signing, notarization, store submissions, deployment.
- git push and destructive git: reset, force push, history rewrites, rollbacks. Clarification: deleting files and directories strictly by an explicitly named list from the request counts as mechanics for cheap; destructive means anything that rewrites git history or goes beyond what was explicitly named.
- The overwrite act of canon-file syncs: hard does the staging verification and hash-diff, the main session confirms and performs the overwrite.
- Personal legal, tax, and medical matters.
- Interactive work with mid-task confirmations: forms, purchases, publishing, browser flows.

## Wide search: fan-out

Haiku's 200K context is not a ban on wide search, it is an instruction to split. N parallel haiku spawns by directory or subsystem, each returning a compact report, the main session merges. A single full-walk spawn only when the exact paths are known in advance.

## Fan-out for independent chunks

A task that splits into several independent chunks (the same operation across N files, screens, or questions, no chunk depends on another's result): spawn every Agent call in one message, in parallel, not one at a time and not through a single sequential agent doing everything. Pick the tier per chunk, not one tier for the whole batch: a simple chunk to cheap, a harder one to dev, a known-hard one straight to hard. This is an ordinary parallel Agent call, not Workflow/ultracode: no orchestration, no separate user approval, the same mode as a single spawn, just several at once.

Chunks are not independent if the next one depends on the previous result or needs a check between stages. That's a pipeline, not a fan-out: do it sequentially yourself. If the whole task is made of dependent multi-stage steps like that and is genuinely large, that's a scenario for Workflow (ultracode), but it only turns on by explicit user request in chat, never automatically from the shape of the task alone.

## Overhead: the single rule

Delegation fails to pay off in exactly one case: the spawn prompt is longer than the edit itself at an exactly known place. That is exception (c) above. The old thresholds ("don't delegate under 50 lines", "explanation longer than the work", "prompt prep is half the task") are gone: they forbade precisely the tasks cheap exists for.

## Prompt on spawn

Pass everything the agent cannot succeed without: exact file paths, git branch, acceptance criterion, constraints, decisions already made, known pitfalls, and what to report back.

## Worked examples, resolved to a tier

1. "An untracked build/ directory of several GB: check git check-ignore, extend .gitignore, remove the directory, commit": cheap, one spawn. Commands and criterion are named, no judgment needed.
2. "Replace every word form of term A with term B across the repository": cheap; fan out into parallel spawns when the volume is large.
3. "Add an English locale to the app": dev. Self-contained, clear done criterion.
4. "Adversarial review of a rollback engine (inverses, supersession guards, races on a POST endpoint)": straight to hard, not after two failures.
5. "Sync canonical files from an archive": hard builds a staging copy, hash-diff, and pre-sync verification; the main session confirms and performs the overwrite over canon.
6. "Notarization with a Developer ID": main session only, no agents.
7. "Where is X handled in a large monorepo": three parallel Explore spawns with model: haiku, split by subsystem.

## Tokens and models: on demand only

No forced per-reply report anymore, removed 2026-07-21 (details in CLAUDE.md). Show token and model numbers only when asked, with `/usage-report` (what ran this session, model by model) or `/routing-status` (the same, plus the routing table from `route-gate.log`). Name models directly (Sonnet 5, Opus 4.8, Fable 5, Haiku 4.5), not by persona. Numbers only real; if a source is unavailable, say so, don't invent.

If a chat has been open since before CLAUDE.md or this skill last changed, it's running on stale rules: `/refresh-rules` re-reads the current files right in that chat, no new chat needed (see `skills/refresh-rules`).
