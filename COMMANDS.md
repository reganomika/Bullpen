# Commands

Three slash commands, available once installed. Nothing here fires automatically, see [FAQ.md](FAQ.md) for why there's no automatic per-reply report anymore.

## `/routing-status`

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

Two tables for the current session, built straight from `~/.claude/hooks/state/route-gate.log` and the session transcript. `deny-no-model` climbing means agents keep spawning with no model named. `rewrite-haiku` above zero means the Explore auto-route is firing. Use this to confirm routing is actually working, not just take the chat's word for it.

## `/usage-report`

```
/usage-report
```

Same idea, simpler: just the token/model totals for the current session, computed from the transcript.

## `/refresh-rules`

```
/refresh-rules
```

Run this in a chat that's been open since before you last edited CLAUDE.md or the routing skill, so it picks up the current rules without a restart. It re-reads both files and returns one checkable artifact (the current routing iron rule) so you can confirm it took effect instead of trusting a claim.

This only refreshes text-based rules in files that were already installed when the chat started. It cannot add a brand-new agent or hook to an already-running session, see [FAQ.md](FAQ.md).
