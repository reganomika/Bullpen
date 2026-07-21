---
description: Re-read the current ~/.claude/CLAUDE.md, this project's own CLAUDE.md (if any), and the model-routing skill right in this chat, no new chat needed. Use when the routing rules changed after this session started, and the chat is still running on the old version.
disable-model-invocation: true
---

Read right now, in full:
1. `~/.claude/CLAUDE.md`
2. `CLAUDE.md` at the root of the current project, if it exists
3. `~/.claude/skills/model-routing/SKILL.md`

Whatever they currently say applies for the rest of this session in place of what was in the system prompt at session start: the same rules, just re-read fresh, since these files can change after a session has already loaded and the system prompt doesn't hot-reload.

Apply this from now until the end of the session.

Don't try to judge whether anything changed compared to how you'd been behaving before: that's unreliable self-assessment, you have no accurate record of your own old system prompt to honestly compare against, and on a large accumulated context that guess easily comes out confident and wrong. Instead, always, regardless of any belief about what changed, produce a concrete checkable artifact right now, not a claim: the current iron rule for agent routing in one line (the required model parameter, route-gate if installed).

The user looks at what you produced and sees for themselves whether it matches what they expect right now, instead of trusting your claim.
