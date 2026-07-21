---
description: Show the token/model report for this session on demand. No autoplay, no forced report after every reply, this is a manual command only.
disable-model-invocation: true
---

Build the report right now. For each piece of work, name the model that handled it directly (no personas) and how many tokens it spent.

For the main session, sum output tokens by model straight from the transcript file:

```bash
PROJDIR=~/.claude/projects/$(pwd | tr '/' '-')
SESSION_ID="$(basename "$(ls -t "$PROJDIR"/*.jsonl 2>/dev/null | head -1)" .jsonl)"
jq -n '
reduce (inputs | select(.type=="assistant") | .message // empty) as $m
  ({}; .[$m.model // "unknown"] += ($m.usage.output_tokens // 0))
' "$PROJDIR/${SESSION_ID}.jsonl"
```

For delegated agents, use the real numbers from `subagent_tokens` in their completion notification, resolving the model from an explicit parameter or from the tier (`cheap`→Haiku 4.5, `dev`→Sonnet 5, `hard`→Opus 4.8, `super`→Fable 5), as described in `skills/routing-status/SKILL.md`. If a number isn't available for some piece, say so plainly, don't invent one.
