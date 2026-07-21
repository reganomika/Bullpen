---
description: Show a table of real routing decisions and per-model token spend for the current session, straight from route-gate.log and the transcript, not relying on any per-reply report. Use this to check that the routing skill is actually working.
disable-model-invocation: true
---

Gather and show two sections for the current session.

## 1. Find the session_id and transcript

```bash
PROJDIR=~/.claude/projects/$(pwd | tr '/' '-')
SESSION_ID="$(basename "$(ls -t "$PROJDIR"/*.jsonl 2>/dev/null | head -1)" .jsonl)"
TRANSCRIPT="$PROJDIR/${SESSION_ID}.jsonl"
```

## 2. Routing (route-gate.log, this session only)

```bash
awk -F'\t' -v sid="$SESSION_ID" '$2==sid' ~/.claude/hooks/state/route-gate.log
```

Show as a table: tier/agent_type, count, decision (`allow-tier`, `rewrite-haiku`, `deny-no-model`, `ask-super`, `allow-explicit`, `allow-other`, `allow-bypass`). This is a routing health check on its own: `deny-no-model` should trend to zero, `rewrite-haiku` above zero means the haiku auto-route is actually firing.

## 3. Tokens by model (this session, real numbers)

Main session, by model, straight from the transcript (no intermediate state file anymore):

```bash
jq -n '
reduce (inputs | select(.type=="assistant") | .message // empty) as $m
  ({}; .[$m.model // "unknown"] += ($m.usage.output_tokens // 0))
' "$TRANSCRIPT"
```

Every real agent completion in this session, with its model:

```bash
jq -n '
[inputs] as $all
| [
    $all[]
    | select(.type=="assistant")
    | .message.content[]?
    | select(type=="object" and .type=="tool_use" and (.name=="Agent" or .name=="Task"))
    | {id: .id, agent_type: (.input.subagent_type // .input.agent_type // "unknown"), model: (.input.model // "")}
  ] as $agents
| [
    $all[]
    | select(.type=="user")
    | .message.content as $c
    | (if ($c|type)=="array" then $c[] else {type:"text", text:$c} end)
    | (
        if (type=="object" and .type=="tool_result") then
          ( . as $tr
            | ($tr.content | if type=="string" then . else (.. | strings) end) as $txt
            | { tuid: $tr.tool_use_id, txt: $txt } )
        elif (type=="object" and .type=="text" and (.text|type)=="string" and (.text | test("^\\s*<task-notification"))) then
          ( .text as $txt
            | ($txt | scan("<tool-use-id>([^<]+)</tool-use-id>") | .[0]) as $tuid
            | { tuid: $tuid, txt: $txt } )
        else empty
        end
      )
    | select(.txt | test("subagent_tokens"; "i"))
    | . as $entry
    | ($agents[] | select(.id == $entry.tuid)) as $a
    | ($entry.txt | scan("subagent_tokens[^0-9]{0,20}([0-9]+)"; "i") | .[0]) as $tok
    | {agent_type: $a.agent_type, model: $a.model, tokens: ($tok | tonumber)}
  ]
' "$TRANSCRIPT"
```

Add the main session and the agents into one table by final model and compute each one's share of the total. When an agent completion's `model` is empty, resolve it by tier: `cheap` → Haiku 4.5, `dev` → Sonnet 5, `hard` → Opus 4.8, `super` → Fable 5. An explicit `model` in the record wins over the tier. Name models directly: Sonnet 5, Opus 4.8, Haiku 4.5, Fable 5.

## Honest about the limits

`route-gate.log` doesn't store completion tokens, only the decision at spawn time: it's the source for section 2 (how many times each thing was called), not for section 3. Section 3 comes straight from the transcript, through a tool_use/tool_result pair or a `<task-notification>`. If an agent completion has neither an explicit model nor a known tier (for example a custom agent like `claude-code-guide` with no explicit `model`), don't invent a model: label it "unknown" and give the agent type as-is.
