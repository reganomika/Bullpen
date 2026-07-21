#!/usr/bin/env bats
# Logic tests for hooks/route-gate.sh: shellcheck (in CI) catches syntax and
# style, this catches routing regressions. Run: bats tests/
#
# Each test gets its own $HOME so route-gate.log and the .disabled flag never
# leak between tests or touch the real ~/.claude.

HOOK="$BATS_TEST_DIRNAME/../hooks/route-gate.sh"

setup() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.claude/hooks/state"
}

run_hook() {
  printf '%s' "$1" | "$HOOK"
}

last_decision() {
  tail -n 1 "$HOME/.claude/hooks/state/route-gate.log" | cut -f5
}

@test "cheap tier passes silently" {
  run run_hook '{"tool_input":{"subagent_type":"cheap"},"session_id":"s1"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(last_decision)" = "allow-tier" ]
}

@test "dev and hard tiers also pass silently" {
  run run_hook '{"tool_input":{"subagent_type":"dev"},"session_id":"s1"}'
  [ "$(last_decision)" = "allow-tier" ]
  run run_hook '{"tool_input":{"subagent_type":"hard"},"session_id":"s1"}'
  [ "$(last_decision)" = "allow-tier" ]
}

@test "super raises an ask decision naming itself" {
  run run_hook '{"tool_input":{"subagent_type":"super"},"session_id":"s1"}'
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null
  echo "$output" | jq -e '.hookSpecificOutput.permissionDecisionReason | test("super")' >/dev/null
  [ "$(last_decision)" = "ask-super" ]
}

@test "Explore with no model is rewritten to haiku" {
  run run_hook '{"tool_input":{"subagent_type":"Explore"},"session_id":"s1"}'
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "allow"' >/dev/null
  echo "$output" | jq -e '.hookSpecificOutput.updatedInput.model == "haiku"' >/dev/null
  [ "$(last_decision)" = "rewrite-haiku" ]
}

@test "Explore with an explicit model passes through untouched" {
  run run_hook '{"tool_input":{"subagent_type":"Explore","model":"sonnet"},"session_id":"s1"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(last_decision)" = "allow-explicit" ]
}

@test "general-purpose with no model is denied" {
  run run_hook '{"tool_input":{"subagent_type":"general-purpose"},"session_id":"s1"}'
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null
  [ "$(last_decision)" = "deny-no-model" ]
}

@test "general-purpose with an explicit model passes through untouched" {
  run run_hook '{"tool_input":{"subagent_type":"general-purpose","model":"opus"},"session_id":"s1"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(last_decision)" = "allow-explicit" ]
}

@test "unknown agent type fails open" {
  run run_hook '{"tool_input":{"subagent_type":"Plan"},"session_id":"s1"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(last_decision)" = "allow-other" ]
}

@test "bypassPermissions mode only observes, never blocks" {
  run run_hook '{"tool_input":{"subagent_type":"general-purpose"},"session_id":"s1","permission_mode":"bypassPermissions"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(last_decision)" = "allow-bypass" ]
}

@test "calls from inside a subagent are never re-gated" {
  run run_hook '{"tool_input":{"subagent_type":"general-purpose"},"session_id":"s1","agent_id":"sub1"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "$HOME/.claude/hooks/state/route-gate.log" ]
}

@test "missing agent type fails open" {
  run run_hook '{"tool_input":{},"session_id":"s1"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "$HOME/.claude/hooks/state/route-gate.log" ]
}

@test "disabled flag file suppresses the hook entirely" {
  touch "$HOME/.claude/hooks/route-gate.disabled"
  run run_hook '{"tool_input":{"subagent_type":"super"},"session_id":"s1"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "$HOME/.claude/hooks/state/route-gate.log" ]
}

@test "ROUTE_GATE_ASK_AGENT renames which agent gets the confirmation dialog" {
  export ROUTE_GATE_ASK_AGENT="premium"
  run run_hook '{"tool_input":{"subagent_type":"premium"},"session_id":"s1"}'
  echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null
  [ "$(last_decision)" = "ask-super" ]
  unset ROUTE_GATE_ASK_AGENT
}

@test "renaming the ask agent stops the old default from asking" {
  export ROUTE_GATE_ASK_AGENT="premium"
  run run_hook '{"tool_input":{"subagent_type":"super"},"session_id":"s1"}'
  [ -z "$output" ]
  [ "$(last_decision)" = "allow-other" ]
  unset ROUTE_GATE_ASK_AGENT
}

@test "ROUTE_GATE_TIER_AGENTS accepts a custom comma-separated list" {
  export ROUTE_GATE_TIER_AGENTS="cheap,dev,hard,research"
  run run_hook '{"tool_input":{"subagent_type":"research"},"session_id":"s1"}'
  [ -z "$output" ]
  [ "$(last_decision)" = "allow-tier" ]
  unset ROUTE_GATE_TIER_AGENTS
}

@test "ROUTE_GATE_AUTOROUTE_MODEL changes the rewrite target" {
  export ROUTE_GATE_AUTOROUTE_MODEL="haiku-fast"
  run run_hook '{"tool_input":{"subagent_type":"Explore"},"session_id":"s1"}'
  echo "$output" | jq -e '.hookSpecificOutput.updatedInput.model == "haiku-fast"' >/dev/null
  [ "$(last_decision)" = "rewrite-haiku-fast" ]
  unset ROUTE_GATE_AUTOROUTE_MODEL
}

@test "CLAUDE_CODE_SUBAGENT_MODEL flags tier agents as overridden, not a plain allow" {
  export CLAUDE_CODE_SUBAGENT_MODEL="opus"
  run run_hook '{"tool_input":{"subagent_type":"cheap"},"session_id":"s1"}'
  [ -z "$output" ]
  [ "$(last_decision)" = "allow-tier-model-overridden" ]
  unset CLAUDE_CODE_SUBAGENT_MODEL
}

@test "CLAUDE_CODE_SUBAGENT_MODEL is logged in the model column instead of the silent tier model" {
  export CLAUDE_CODE_SUBAGENT_MODEL="opus"
  run run_hook '{"tool_input":{"subagent_type":"cheap"},"session_id":"s1"}'
  logged_model="$(tail -n 1 "$HOME/.claude/hooks/state/route-gate.log" | cut -f4)"
  [ "$logged_model" = "opus (env override)" ]
  unset CLAUDE_CODE_SUBAGENT_MODEL
}

@test "CLAUDE_CODE_EFFORT_LEVEL flags tier agents as overridden, not a plain allow" {
  export CLAUDE_CODE_EFFORT_LEVEL="low"
  run run_hook '{"tool_input":{"subagent_type":"hard"},"session_id":"s1"}'
  [ -z "$output" ]
  [ "$(last_decision)" = "allow-tier-effort-overridden" ]
  unset CLAUDE_CODE_EFFORT_LEVEL
}

@test "CLAUDE_CODE_EFFORT_LEVEL is logged in the model column" {
  export CLAUDE_CODE_EFFORT_LEVEL="low"
  run run_hook '{"tool_input":{"subagent_type":"hard"},"session_id":"s1"}'
  logged_model="$(tail -n 1 "$HOME/.claude/hooks/state/route-gate.log" | cut -f4)"
  [ "$logged_model" = "none, effort=low (env override)" ]
  unset CLAUDE_CODE_EFFORT_LEVEL
}

@test "CLAUDE_CODE_EFFORT_LEVEL set to auto is treated as unset" {
  export CLAUDE_CODE_EFFORT_LEVEL="auto"
  run run_hook '{"tool_input":{"subagent_type":"cheap"},"session_id":"s1"}'
  [ "$(last_decision)" = "allow-tier" ]
  unset CLAUDE_CODE_EFFORT_LEVEL
}

@test "model and effort overrides together get their own combined decision" {
  export CLAUDE_CODE_SUBAGENT_MODEL="opus"
  export CLAUDE_CODE_EFFORT_LEVEL="low"
  run run_hook '{"tool_input":{"subagent_type":"cheap"},"session_id":"s1"}'
  [ "$(last_decision)" = "allow-tier-model-and-effort-overridden" ]
  unset CLAUDE_CODE_SUBAGENT_MODEL
  unset CLAUDE_CODE_EFFORT_LEVEL
}

@test "CLAUDE_CODE_SUBAGENT_MODEL set to inherit is treated as unset" {
  export CLAUDE_CODE_SUBAGENT_MODEL="inherit"
  run run_hook '{"tool_input":{"subagent_type":"cheap"},"session_id":"s1"}'
  [ "$(last_decision)" = "allow-tier" ]
  unset CLAUDE_CODE_SUBAGENT_MODEL
}

run_hook_no_jq() {
  local emptybin="$BATS_TEST_TMPDIR/emptybin"
  mkdir -p "$emptybin"
  for c in bash cat mkdir touch printf date wc mv; do
    ln -sf "$(command -v "$c")" "$emptybin/$c"
  done
  printf '%s' "$1" | PATH="$emptybin" "$HOOK"
}

@test "missing jq blocks once with a warning on stderr, nothing meaningful on stdout" {
  run run_hook_no_jq '{"tool_input":{"subagent_type":"cheap"},"session_id":"s1"}'
  [ "$status" -eq 2 ]
  # Exit 2 means Claude Code ignores stdout entirely; nothing should be
  # printed there, the reason has to live on stderr, which bats merges into
  # $output by default, this just confirms no stray JSON got left on stdout.
  ! echo "$output" | grep -q '"decision"'
  echo "$output" | grep -qi "not found on this hook process's PATH"
  [ -f "$HOME/.claude/hooks/state/route-gate.jq-missing-warned" ]
}

@test "missing jq fails open silently after the first warning" {
  run run_hook_no_jq '{"tool_input":{"subagent_type":"cheap"},"session_id":"s1"}'
  run run_hook_no_jq '{"tool_input":{"subagent_type":"cheap"},"session_id":"s1"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "the warned marker clears once jq is found again, so a later gap re-warns" {
  run run_hook_no_jq '{"tool_input":{"subagent_type":"cheap"},"session_id":"s1"}'
  [ -f "$HOME/.claude/hooks/state/route-gate.jq-missing-warned" ]

  run run_hook '{"tool_input":{"subagent_type":"cheap"},"session_id":"s1"}'
  [ ! -f "$HOME/.claude/hooks/state/route-gate.jq-missing-warned" ]

  run run_hook_no_jq '{"tool_input":{"subagent_type":"cheap"},"session_id":"s1"}'
  [ "$status" -eq 2 ]
}

@test "a marker path that can't become a real file fails open instead of blocking forever" {
  # A directory at the marker path is the cleanest reproduction: touch on it
  # succeeds (updates the directory's mtime, exit 0) while checking touch's
  # exit code alone would miss that [ -f "$JQ_WARNED" ] is still false,
  # which would silently reproduce the infinite-block loop this test guards
  # against. Also root-independent, unlike chmod: root bypasses permission
  # bits entirely, so a read-only-directory version of this test passes
  # under a normal user and silently no-ops when run as root (containers,
  # some CI images), which is not a real pass.
  mkdir -p "$HOME/.claude/hooks/state/route-gate.jq-missing-warned"
  run run_hook_no_jq '{"tool_input":{"subagent_type":"cheap"},"session_id":"s1"}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run run_hook_no_jq '{"tool_input":{"subagent_type":"cheap"},"session_id":"s1"}'
  [ "$status" -eq 0 ]
}
