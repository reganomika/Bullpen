#!/bin/bash
# Stop hook: считает реальные токены этого обмена (дельта с предыдущего вызова
# для этой же сессии) и ПРИНУДИТЕЛЬНО требует от модели показать их через
# decision:block (exit 2). Защита от зацикливания: если stop_hook_active
# уже true, значит один принудительный проход в этом обмене уже случился —
# не форсируем снова, отпускаем.

INPUT="$(cat)"

# Мгновенное глобальное вкл/выкл: если файл-флаг существует — не вмешиваемся.
if [ -f "$HOME/.claude/hooks/token-report.disabled" ]; then
  exit 0
fi

# Защита от бесконечного цикла: второй Stop в рамках одного и того же
# принудительного продолжения — больше не блокируем. Но состояние ниже
# всё равно пересохраняем: иначе токены самой дописанной строки отчёта
# не попадают в baseline и утекают в дельту следующего обмена.
STOP_HOOK_ACTIVE="$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)"

TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] || [ -z "$SESSION_ID" ]; then
  exit 0
fi

STATE_DIR="$HOME/.claude/hooks/state"
mkdir -p "$STATE_DIR" 2>/dev/null
STATE_FILE="$STATE_DIR/${SESSION_ID}.json"
EMPTY='{"output":0,"cache_creation":0,"cache_read":0,"input":0,"models":{}}'

# Первый вызов в этой сессии: если это и правда самый первый обмен (в
# транскрипте ровно одна пользовательская реплика), базой честно считаем
# ноль и показываем отчёт сразу. Если пользовательских реплик уже
# несколько, а файла состояния нет (хук включили посреди сессии либо файл
# состояния потерялся), честно посчитать "этот один обмен" нельзя. Молча
# запоминаем базу и показываем со следующего вызова.
IS_FIRST_RUN=0
if [ ! -f "$STATE_FILE" ]; then
  IS_FIRST_RUN=1
fi

CURRENT="$(jq -n '
  reduce (inputs | select(.type=="assistant") | .message // empty) as $m
    ({output:0, cache_creation:0, cache_read:0, input:0, models:{}};
     .output += ($m.usage.output_tokens // 0)
     | .cache_creation += ($m.usage.cache_creation_input_tokens // 0)
     | .cache_read += ($m.usage.cache_read_input_tokens // 0)
     | .input += ($m.usage.input_tokens // 0)
     | .models[$m.model // "unknown"] += ($m.usage.output_tokens // 0)
    )
' "$TRANSCRIPT" 2>/dev/null)"

if [ -z "$CURRENT" ]; then
  exit 0
fi

# Второй проход того же обмена (после принудительного дописывания отчёта):
# не блокируем повторно, но baseline обновляем, чтобы токены строки отчёта
# не утекли в следующий обмен.
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  printf '%s' "$CURRENT" > "$STATE_FILE" 2>/dev/null
  exit 0
fi

# Сколько настоящих пользовательских реплик уже в транскрипте (tool_result
# не в счёт, это не человек, а результат инструмента, вернувшийся с ролью user).
HUMAN_TURNS="$(jq -n '
  reduce (inputs | select(.type=="user")) as $u
    (0;
      if (($u.message.content | type) == "string")
         or ((($u.message.content | type) == "array")
             and (($u.message.content | map(.type=="tool_result") | any) | not))
      then . + 1
      else .
      end)
' "$TRANSCRIPT" 2>/dev/null)"
[ -z "$HUMAN_TURNS" ] && HUMAN_TURNS=2

if [ -f "$STATE_FILE" ]; then
  PREV="$(cat "$STATE_FILE" 2>/dev/null)"
  [ -z "$PREV" ] && PREV="$EMPTY"
else
  PREV="$EMPTY"
fi

printf '%s' "$CURRENT" > "$STATE_FILE" 2>/dev/null

if [ "$IS_FIRST_RUN" = "1" ] && [ "$HUMAN_TURNS" -gt 1 ] 2>/dev/null; then
  exit 0
fi

DELTA_OUTPUT="$(jq -n --argjson cur "$CURRENT" --argjson prev "$PREV" '($cur.output - $prev.output)' 2>/dev/null)"

# Ничего существенного не потрачено (короткая разговорная реплика без
# реальной работы) — не форсируем отчёт.
if [ -z "$DELTA_OUTPUT" ] || [ "$DELTA_OUTPUT" -le 0 ] 2>/dev/null; then
  exit 0
fi

SUMMARY="$(jq -n --argjson cur "$CURRENT" --argjson prev "$PREV" -r '
  ($cur.models as $c | $prev.models as $p
     | [$c | to_entries[] | . as $e | ($e.value - ($p[$e.key] // 0)) as $d | select($d > 0) | "\($e.key)=\($d)"]
     | join(", "))
' 2>/dev/null)"

if [ -z "$SUMMARY" ]; then
  exit 0
fi

# Данные и число нейтральны, а формулировка на английском специально:
# скрипт не может определить язык разговора, это решает модель при выполнении.
REASON="You must append a real token-usage report for this exchange to the end of your reply, written in the language the user has been writing in this conversation (English if unclear). Data — main session, output tokens per model this exchange: ${SUMMARY}. Use only what the model-routing skill's chosen display format specifies; no cache/read/write figures."

# Документация неоднозначна про канал для decision:block — пишем JSON в
# stdout и ту же причину в stderr, чтобы сработало при любой трактовке.
# stop_hook_active выше гарантирует, что второй проход этого же обмена
# не форснёт снова, зацикливания не будет.
jq -n --arg reason "$REASON" '{decision:"block", reason:$reason}'
printf '%s\n' "$REASON" >&2
exit 2
