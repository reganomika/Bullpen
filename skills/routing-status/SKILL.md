---
description: Показать таблицу реальной маршрутизации и расхода токенов по моделям за текущую сессию, из route-gate.log и транскрипта напрямую, не полагаясь на построчный отчёт после каждого ответа. Использовать, чтобы проверить, что скилл маршрутизации реально работает.
disable-model-invocation: true
---

Собери и покажи два раздела для текущей сессии.

## 1. Найти session_id и транскрипт

```bash
PROJDIR=~/.claude/projects/$(pwd | tr '/' '-')
SESSION_ID="$(basename "$(ls -t "$PROJDIR"/*.jsonl 2>/dev/null | head -1)" .jsonl)"
TRANSCRIPT="$PROJDIR/${SESSION_ID}.jsonl"
```

## 2. Маршрутизация (route-gate.log, только эта сессия)

```bash
awk -F'\t' -v sid="$SESSION_ID" '$2==sid' ~/.claude/hooks/state/route-gate.log
```

Покажи таблицей: тир/agent_type, сколько раз, решение (`allow-tier`, `rewrite-haiku`, `deny-no-model`, `ask-super`, `allow-explicit`, `allow-other`, `allow-bypass`). Это здоровье маршрутизации само по себе: `deny-no-model` должно стремиться к нулю, `rewrite-haiku` больше нуля значит автопереход на haiku реально срабатывает.

## 3. Токены по моделям (эта сессия, реальные числа)

Основная сессия, по моделям:

```bash
cat ~/.claude/hooks/state/"${SESSION_ID}".json | jq '.models'
```

Каждое реальное завершение агента в этой сессии, с моделью:

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

Сложи основную сессию и агентов в одну таблицу по итоговой модели и посчитай процент каждой от общей суммы токенов. Когда у завершения агента `model` пустой, резолвь по тиру: `cheap` → Haiku 4.5, `dev` → Sonnet 5, `hard` → Opus 4.8, `super` → Fable 5. Явный `model` в записи побеждает тир. Называй модели прямо: Sonnet 5, Opus 4.8, Haiku 4.5, Fable 5.

## Честно о пределах

`route-gate.log` не хранит токены завершения, только решение на спавне: он источник для раздела 2 (сколько раз что вызывалось), не для раздела 3. Раздел 3 берётся из транскрипта напрямую, через пару tool_use/tool_result или `<task-notification>`. Если у завершения агента нет ни явной модели, ни известного тира (например, кастомный агент вроде `claude-code-guide` без явного `model`), не выдумывай модель: подпиши «неизвестно» и укажи тип агента как есть.
