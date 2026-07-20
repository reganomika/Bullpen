---
description: Show the token/model report for this session on demand, or really turn the forced per-exchange report on/off everywhere at once. Empty argument — show now; "off" — disable everywhere; "on" — re-enable everywhere.
disable-model-invocation: true
---

Argument: $ARGUMENTS

If the argument is empty: build the report right now. For each piece of work, name the model that handled it directly (no personas) and how many tokens it spent. For delegated agents, use the real numbers from their completion notification. For the main session, sum the transcript file's usage fields the same way `skills/model-routing/SKILL.md` describes. If a number isn't available, say so plainly, don't invent one.

If the argument is "off": run `touch ~/.claude/hooks/token-report.disabled` via Bash (a real action, not just a promise) and confirm the per-exchange report is disabled everywhere, in every chat and project, until turned back on.

If the argument is "on": run `rm -f ~/.claude/hooks/token-report.disabled` via Bash and confirm the per-exchange report is enabled again everywhere.
