#!/bin/bash
# PreToolUse gate on Agent/Task calls: makes the expensive default unrepresentable.
#   - tier agents (default cheap/dev/hard): pass, their frontmatter already pins the model
#   - the ask agent (default super): native "ask" confirmation dialog (this IS the budget approval)
#   - the autoroute agent (default Explore) without model: input rewritten to the autoroute model (default haiku); explicit model passes as-is
#   - the deny agent (default general-purpose) without model: denied until a model is named
#   - everything else, and anything uncertain: pass (fail open)
# Every decision is appended to ~/.claude/hooks/state/route-gate.log (TSV).
# Instant global off-switch: touch ~/.claude/hooks/route-gate.disabled
# Deliberately no dollar figures in this file: prices go stale, tier order does not.
#
# Renaming or adding tiers: the agent names above are not hardcoded, they come
# from environment variables (set in the `env` block of ~/.claude/settings.json,
# or your shell profile), documented in FAQ.md:
#   ROUTE_GATE_TIER_AGENTS     comma-separated, default "cheap,dev,hard"
#   ROUTE_GATE_ASK_AGENT       default "super"
#   ROUTE_GATE_AUTOROUTE_AGENT default "Explore"
#   ROUTE_GATE_AUTOROUTE_MODEL default "haiku"
#   ROUTE_GATE_DENY_AGENT      default "general-purpose"
# Rename a tier without setting the matching variable and its special handling
# (the ask dialog, in particular) silently stops firing for it, the gate has
# no way to infer that a renamed agent was meant to inherit the old behavior.
#
# CLAUDE_CODE_SUBAGENT_MODEL, if set in the environment, outranks everything
# this hook can see: it wins over the per-invocation model parameter AND the
# tier agent's own frontmatter. A tier agent's "the frontmatter already pins
# the model" assumption breaks silently when this is set, so the hook logs a
# distinct decision (allow-tier-model-overridden) instead of pretending the
# frontmatter model is what actually ran.
#
# That log entry is observed, not verified: the hook only sees its own copy
# of the environment, not Claude Code's actual resolution. If the override
# value is excluded by an org's availableModels allowlist, Claude Code skips
# it and falls back to the inherited model, silently, and the hook has no
# way to know that happened, so the logged value can be wrong in that case.

# Kill switch, checked fresh on every run (each run is its own process).
if [ -f "$HOME/.claude/hooks/route-gate.disabled" ]; then
  exit 0
fi

# No jq: fail open rather than break every Agent call, same as any other
# fail-open branch below. But this one is different in kind, not degree: it
# disables the entire hook, silently, for every future spawn, not just this
# one. Warn once so it surfaces instead of vanishing, then go back to silent
# fail-open so this never nags on every single spawn. jq missing today does
# not mean jq missing forever (PATH changes, a broken install gets fixed),
# so the marker resets the moment jq is found again, not just the first time.
JQ_WARNED="$HOME/.claude/hooks/state/route-gate.jq-missing-warned"
if command -v jq >/dev/null 2>&1; then
  rm -f "$JQ_WARNED" 2>/dev/null
else
  if [ ! -f "$JQ_WARNED" ]; then
    mkdir -p "$HOME/.claude/hooks/state" 2>/dev/null
    # Can't record that we warned: fail open rather than block every future
    # spawn forever on a read-only $HOME or a full disk. A missed warning
    # this once beats an unkillable block loop, that would be the opposite
    # of this whole script's fail-open philosophy.
    touch "$JQ_WARNED" 2>/dev/null || exit 0
    # PreToolUse hooks don't use the top-level decision field, that's for
    # UserPromptSubmit/PostToolUse/Stop/SubagentStop/PreCompact; PreToolUse
    # uses hookSpecificOutput.permissionDecision instead, and jq (unavailable
    # right now) is what builds that JSON in every other branch of this
    # script. On exit 2, Claude Code ignores stdout entirely regardless of
    # what's in it, valid JSON or not, so there is nothing useful to print
    # there anyway: stderr text is what actually reaches the model.
    printf 'Route gate: jq was not found on this hook process'\''s PATH, so route-gate.sh cannot read this Agent/Task call, and every routing decision has been failing open silently, no enforcement at all, since PATH stopped including it. If jq is genuinely not installed: macOS, brew install jq. If it is installed, this is more likely a PATH problem: GUI-launched apps often do not source your shell profile and miss things like /opt/homebrew/bin, check where jq actually lives (which jq in a terminal) against what this hook process can see. This warning fires once per gap; it goes silent again after this until jq goes missing again.\n' >&2
    exit 2
  fi
  exit 0
fi

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

TIER_AGENTS="${ROUTE_GATE_TIER_AGENTS:-cheap,dev,hard}"
ASK_AGENT="${ROUTE_GATE_ASK_AGENT:-super}"
AUTOROUTE_AGENT="${ROUTE_GATE_AUTOROUTE_AGENT:-Explore}"
AUTOROUTE_MODEL="${ROUTE_GATE_AUTOROUTE_MODEL:-haiku}"
DENY_AGENT="${ROUTE_GATE_DENY_AGENT:-general-purpose}"

# "inherit" is a no-op as of Claude Code v2.1.196+: resolution just continues
# to the next source, same as leaving the variable unset entirely.
SUBAGENT_MODEL_OVERRIDE="${CLAUDE_CODE_SUBAGENT_MODEL:-}"
[ "$SUBAGENT_MODEL_OVERRIDE" = "inherit" ] && SUBAGENT_MODEL_OVERRIDE=""

# True if $1 appears as a whole entry in the comma-separated list $2.
in_list() {
  case ",$2," in
    *",$1,"*) return 0 ;;
    *) return 1 ;;
  esac
}

STATE_DIR="$HOME/.claude/hooks/state"
LOG="$STATE_DIR/route-gate.log"
mkdir -p "$STATE_DIR" 2>/dev/null

log_line() { # $1 = decision
  if [ -f "$LOG" ] && [ "$(wc -l < "$LOG" 2>/dev/null || echo 0)" -gt 5000 ]; then
    mv "$LOG" "$LOG.old" 2>/dev/null
  fi
  # The override wins in reality regardless of what MODEL (the per-invocation
  # parameter) says, so it takes priority in the log too: showing MODEL here
  # when an override is active would log a model that didn't actually run.
  local LOGGED_MODEL="${MODEL:-none}"
  if [ -n "$SUBAGENT_MODEL_OVERRIDE" ]; then
    LOGGED_MODEL="${SUBAGENT_MODEL_OVERRIDE} (env override)"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" \
    "${SESSION_ID:-unknown}" "$AGENT_TYPE" "$LOGGED_MODEL" "$1" >> "$LOG" 2>/dev/null
}

# Headless/automation escape: in bypassPermissions mode "ask" has nobody to
# answer it and "deny" can stall an orchestrator, so the gate only observes.
if [ "$PERM_MODE" = "bypassPermissions" ]; then
  log_line "allow-bypass"
  exit 0
fi

if in_list "$AGENT_TYPE" "$TIER_AGENTS"; then
  # Choosing a tier agent IS the conscious model choice, frontmatter pins it,
  # UNLESS an env override is silently substituting a different model.
  if [ -n "$SUBAGENT_MODEL_OVERRIDE" ]; then
    log_line "allow-tier-model-overridden"
  else
    log_line "allow-tier"
  fi
  exit 0
fi

if [ "$AGENT_TYPE" = "$ASK_AGENT" ]; then
  log_line "ask-super"
  jq -n --arg agent "$AGENT_TYPE" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:"Route gate: \($agent) runs the most expensive frontier tier; a long autonomous run can reach millions of output tokens. Confirm this spawn. (Off switch: touch ~/.claude/hooks/route-gate.disabled)"}}'
  exit 0
fi

if [ "$AGENT_TYPE" = "$AUTOROUTE_AGENT" ]; then
  if [ -n "$MODEL" ]; then
    log_line "allow-explicit"
    exit 0
  fi
  UPDATED="$(printf '%s' "$INPUT" | jq -c --arg m "$AUTOROUTE_MODEL" '.tool_input + {model:$m}' 2>/dev/null)"
  if [ -z "$UPDATED" ]; then
    log_line "allow-rewrite-failed"
    exit 0
  fi
  log_line "rewrite-${AUTOROUTE_MODEL}"
  jq -n --argjson upd "$UPDATED" --arg agent "$AGENT_TYPE" --arg m "$AUTOROUTE_MODEL" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",updatedInput:$upd,permissionDecisionReason:"Route gate: \($agent) had no model and was auto-routed to \($m). Pass an explicit model (e.g. sonnet) when recon needs deeper code semantics."}}'
  exit 0
fi

if [ "$AGENT_TYPE" = "$DENY_AGENT" ]; then
  if [ -n "$MODEL" ]; then
    log_line "allow-explicit"
    exit 0
  fi
  log_line "deny-no-model"
  jq -n --arg agent "$AGENT_TYPE" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"Route gate (a routing checkpoint, not an error): a \($agent) spawn with no model silently inherits the expensive session model. Re-issue this same call with an explicit model: haiku for search/recon/mechanical/fan-out work, sonnet for ordinary dev judgment, or inherit if the session model is deliberately needed (then state why in one line of your reply)."}}'
  exit 0
fi

# Plan, custom agents, future built-ins: fail open, logged for review.
log_line "allow-other"
exit 0
