#!/bin/bash
# PreToolUse gate on Agent/Task calls: makes the expensive default unrepresentable.
#   - tier agents (cheap/dev/hard): pass, their frontmatter already pins the model
#   - super: native "ask" confirmation dialog (this IS the budget approval)
#   - Explore without model: input rewritten to model=haiku (explicit model passes as-is)
#   - general-purpose without model: denied until a model is named
#   - everything else, and anything uncertain: pass (fail open)
# Every decision is appended to ~/.claude/hooks/state/route-gate.log (TSV).
# Instant global off-switch: touch ~/.claude/hooks/route-gate.disabled
# Deliberately no dollar figures in this file: prices go stale, tier order does not.

# Kill switch, checked fresh on every run (each run is its own process).
if [ -f "$HOME/.claude/hooks/route-gate.disabled" ]; then
  exit 0
fi

# No jq: fail open rather than break every Agent call.
command -v jq >/dev/null 2>&1 || exit 0

INPUT="$(cat)"

# Field extraction; every miss degrades to empty and, below, to fail-open.
AGENT_TYPE="$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // .tool_input.agent_type // empty' 2>/dev/null)"
MODEL="$(printf '%s' "$INPUT" | jq -r '.tool_input.model // empty' 2>/dev/null)"
SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
SUB_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null)"
PERM_MODE="$(printf '%s' "$INPUT" | jq -r '.permission_mode // empty' 2>/dev/null)"

# Unknown payload shape (no recognizable agent type): fail open.
[ -z "$AGENT_TYPE" ] && exit 0

# Calls from inside a subagent are never re-gated (recursion/nag guard):
# the gate regulates only the main session's routing decision.
[ -n "$SUB_ID" ] && exit 0

STATE_DIR="$HOME/.claude/hooks/state"
LOG="$STATE_DIR/route-gate.log"
mkdir -p "$STATE_DIR" 2>/dev/null

log_line() { # $1 = decision
  if [ -f "$LOG" ] && [ "$(wc -l < "$LOG" 2>/dev/null || echo 0)" -gt 5000 ]; then
    mv "$LOG" "$LOG.old" 2>/dev/null
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" \
    "${SESSION_ID:-unknown}" "$AGENT_TYPE" "${MODEL:-none}" "$1" >> "$LOG" 2>/dev/null
}

# Headless/automation escape: in bypassPermissions mode "ask" has nobody to
# answer it and "deny" can stall an orchestrator, so the gate only observes.
if [ "$PERM_MODE" = "bypassPermissions" ]; then
  log_line "allow-bypass"
  exit 0
fi

case "$AGENT_TYPE" in
  cheap|dev|hard)
    # Choosing a tier agent IS the conscious model choice; frontmatter pins it.
    log_line "allow-tier"
    exit 0
    ;;
  super)
    log_line "ask-super"
    jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:"Route gate: super runs the most expensive frontier tier; a long autonomous run can reach millions of output tokens. Confirm this spawn. (Off switch: touch ~/.claude/hooks/route-gate.disabled)"}}'
    exit 0
    ;;
  Explore)
    if [ -n "$MODEL" ]; then
      log_line "allow-explicit"
      exit 0
    fi
    UPDATED="$(printf '%s' "$INPUT" | jq -c '.tool_input + {model:"haiku"}' 2>/dev/null)"
    if [ -z "$UPDATED" ]; then
      log_line "allow-rewrite-failed"
      exit 0
    fi
    log_line "rewrite-haiku"
    jq -n --argjson upd "$UPDATED" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",updatedInput:$upd,permissionDecisionReason:"Route gate: Explore had no model and was auto-routed to haiku. Pass an explicit model (e.g. sonnet) when recon needs deeper code semantics."}}'
    exit 0
    ;;
  general-purpose)
    if [ -n "$MODEL" ]; then
      log_line "allow-explicit"
      exit 0
    fi
    log_line "deny-no-model"
    jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"Route gate (a routing checkpoint, not an error): a general-purpose spawn with no model silently inherits the expensive session model. Re-issue this same call with an explicit model: haiku for search/recon/mechanical/fan-out work, sonnet for ordinary dev judgment, or inherit if the session model is deliberately needed (then state why in one line of your reply)."}}'
    exit 0
    ;;
  *)
    # Plan, custom agents, future built-ins: fail open, logged for review.
    log_line "allow-other"
    exit 0
    ;;
esac
