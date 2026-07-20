---
name: model-routing
description: Select optimal cost-effective model and effort, dispatch work to subagents cheap/dev/hard/super. Use at the start of any task (code, content, docs, file processing, design ports, release and browser operations), before any delegation, and for questions about model choice, effort level, or token spend.
metadata:
  trigger: Start of any task; any delegation; model or effort choice; questions about token spend
---

# Model routing and effort

Explicit user instruction (specific model, specific agent, no-delegation rule) takes precedence over all rules below. These rules apply only where the user has not specified a choice.

Goal: same quality for fewer tokens. Take the cheapest tier that holds quality, escalate only when the task requires it. Task difficulty picks the tier, stakes pick strictness: high stakes or deadline (demo, release, rollback) do not raise model tier, but argue against delegation or dropping below dev with mandatory result verification, because an autonomous agent cannot ask for clarification.

## Tiers

Four tiers from cheapest to most expensive model: `cheap` (fastest and cheapest), `dev` (balanced), `hard` (powerful), `super` (most powerful and most expensive available). Keep current model names and pricing here for your Claude Code setup, they change over time; check Anthropic's current pricing. `cheap` has a smaller context window than other tiers: do not send it wide repository searches, multi-file read tasks, or large code chunks where exact file paths are not known in advance.

On effort for subagents: there is no actual effort parameter for named agents, only model control. Desired effort is simulated by prompts in the agent (cheap answers briefly, super deliberates exhaustively); this is approximation, not fine-grained model-session tuning. Multi-agent orchestration, if available in your Claude Code version, is disabled by default and is not the standard path; do not confuse "call super" with enabling full orchestration.

## Default main session

Single recommendation for all projects: balanced model (e.g. Sonnet class), high effort. Escalation goes through agent delegation, not through constant model switching.

## Delegation fitness (check before choosing tier)

Subagets are autonomous: they do not see the conversation and cannot ask clarifying questions. Delegate only a piece that is fully specified (paths, completion criterion, decisions made) and will not need clarification mid-task.

Never delegate to any tier:
- tasks whose meaning lives in conversation context;
- interactive work with mid-task confirmations (browser automation, form submission, publishing, purchases);
- secrets and release procedures (credentials, signing, notarization, app store submission, deployment): steps depend on external answers and account data, decisions needed mid-task;
- tasks with user iteration and high cost of misinterpretation;
- destructive git operations (rollbacks, reset, force push) and file-rewriting syncs: main session only; cheap works only for non-destructive (status, log, diff, commit formatting from ready diff);
- personal legal, tax, and medical documents: main session only.

Resolve remaining edge cases in main session or clarify with user before spawn.

## Defaults by work type (who to call)

- Mechanics (formatting, renaming, boilerplate, bulk identical edits to markdown and docs, file copying, text extraction from PDF, targeted search by pre-named paths): `cheap`. Before choosing cheap, estimate read volume; if it does not fit in its context window with headroom, cheap is not viable.
- Writing and editing where voice and quality matter: main session, or `dev` for self-contained piece with style samples in prompt. Engineering documentation with factual precision (protocols, specs): main session, max `dev`.
- Ordinary development (features, routine refactoring, debugging, tests): main session, or `dev` for self-contained piece. dev is not cheaper than main session if models match: call it for context isolation or parallel work, not token savings; when unsure, keep piece in main session.
- New project or app from scratch following known platform patterns (including non-trivial ecosystem frameworks you work with): `dev`. `hard` engages only when dev hits a concrete technical wall and names it. The word "architecture" alone does not raise tier.
- `hard`, if any one criterion holds: (a) two fix attempts in main session or on dev did not yield confirmed result; (b) bug involves races, concurrency, or reproduces unstably; (c) refactor changes public API or data schema and requires migration; (d) change touches roughly 10+ files with linked logic.
- `super`, only in two cases: (1) hard explicitly states it cannot take the task in one pass, or prior failure on this piece is confirmed by history; (2) clearly multi-hour continuous autonomous work that cannot be split into chunks for hard, or maximum cost-of-error tasks (critical data migrations, payment and subscription flows). Large context volume alone is not reason: dev and hard have the same window. Before spawning super, name expected spend to user and wait for explicit chat approval; without confirmation, do not spawn super.
- Design-tool mockup port to code: `dev`; spec, screenshots, and target files go in prompt; piece is self-contained. Do not use cheap: markup transfer requires judgment and visual precision. Visual result check and user iteration: main session. General principle: keep work with feedback loop (screenshot edits) in main session, delegate only pieces with clear done-criterion, closeable in one pass.

## How to route

1. First check delegation fitness (section above), then estimate task difficulty, not project scale. Delegation has three overhead items: prompt composition with context, re-reading files by agent at full cost (main session cache is unavailable), wait time. Thresholds: do not delegate edits under ~50 lines in one or two files, and any task where explanation length exceeds work length. Delegate to cheap when there is much mechanics (3+ files or long generated output). Batch one-off small pieces: send several small chunks to one agent in one spawn with a list, not separate calls. One overhead instead of N.
2. On unclear complexity, climb the ladder from bottom up: dev, then hard, then super, only if prior tier truly failed (exception: known non-splittable multi-hour autonomous work can go to super directly after user approval). At each escalation, include in next tier's prompt everything prior tier learned: diagnosis, repro steps, affected files, tested and rejected hypotheses. Otherwise expensive model re-pays for already-done reconnaissance.
3. Never trade correctness for cost on genuinely hard work: escalate without hesitation.
4. You cannot change main session model yourself. User sets default once via model switch; afterward escalation goes through agents, not constant model switching.

## Prompt on spawn

Pass everything agent needs to succeed: exact file paths, git branch, acceptance criterion, constraints, decisions already made, known pitfalls, and what to report back. If prompt prep takes half the task, do it in main session.

## Report on models and tokens

Two independent reports, different triggers.

**After each message inside chat.** At end of answer with real work (not clarification or small talk), show: which agents were delegated in exactly this exchange and actual tokens each spent (from their completion report, available immediately); and what this exchange cost main session in tokens, difference between current usage-field sum from session transcript file and sum from prior report, if such file is available in your environment. Unavoidable one-step lag: cannot count your own answer not yet sent, report always covers prior exchange. This is line-by-line report, not session total.

**Session wrap, at new-chat boundary.** Separately, at the same rare boundaries (task closed, context expanded, ceiling, explicit request), show full summary: task list for session, which model or agent owned each, total tokens per model.

Common to both: name models directly, not by persona. Numbers only real; if source is unavailable, say so, do not invent.

Enabled by default, toggled off/on by `/usage-report` command (see `skills/usage-report`) or plain request in chat, which works even if the command itself did not load.
