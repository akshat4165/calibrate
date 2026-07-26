#!/usr/bin/env bash
# Routes each prompt toward the right phase agent by injecting a directive
# into the conversation via UserPromptSubmit's additionalContext.
#
# The earlier version of this hook only logged what tier it WOULD pick
# ("applied": false, always) — a passive spike that measured classifier
# accuracy but never influenced anything. Measured against real usage,
# that meant the policy had zero effect on spend (confirmed: 249 logged
# decisions, zero subagent delegations, 100% single-tier usage). Rewriting
# settings.json mid-session doesn't work either — see
# anthropics/claude-code#43326. additionalContext is the one mechanism
# that IS reachable mid-session: Claude reads it before responding to the
# prompt it's attached to.
#
# This still isn't enforcement — Claude can ignore the directive. Compliance
# should be measured after the fact by /calibrate:savings, which checks
# whether the nudged phase agent was actually invoked.

set -u

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$prompt" ] && exit 0
[ -z "$cwd" ] && cwd="$PWD"

policy="$cwd/.claude/model-policy.json"
# No policy means nothing to route against — stay silent rather than guess.
[ -f "$policy" ] || exit 0
jq -e . "$policy" >/dev/null 2>&1 || exit 0

# Skip slash commands (explicit intent already) and short continuations
# ("yes", "go", "continue", "ok") — nudging those is just noise.
case "$prompt" in
  /*) exit 0 ;;
esac
words=$(printf '%s' "$prompt" | wc -w | tr -d ' ')
lower=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')
if [ "$words" -le 3 ]; then
  case "$lower" in
    *yes*|*yep*|*sure*|*go*|*ok*|*okay*|*continue*|*proceed*|*"do it"*|*"sounds good"*|*"looks good"*)
      exit 0 ;;
  esac
fi

# Classify into a phase. Order matters — review and explore are checked
# before plan/code since their trigger words are more specific.
phase=""
case "$lower" in
  *review*|*audit*|*"find bugs"*|*"check this"*|*"look at this diff"*|*"code review"*)
    phase="review" ;;
esac
if [ -z "$phase" ]; then
  case "$lower" in
    *explain*|*"how does"*|*"where is"*|*"what does"*|*understand*|*trace*|*"find the"*|*"show me"*)
      phase="explore" ;;
  esac
fi
if [ -z "$phase" ]; then
  case "$lower" in
    *architect*|*design*|*"plan "*|*refactor*|*migrate*|*"break down"*|*"how should i"*)
      phase="plan" ;;
  esac
fi
if [ -z "$phase" ]; then
  case "$lower" in
    *build*|*add*|*implement*|*fix*|*write*|*create*|*change*|*update*)
      phase="code" ;;
  esac
fi
# Nothing matched confidently — don't force a guess onto an ambiguous prompt.
[ -z "$phase" ] && exit 0

model=$(jq -r --arg p "$phase" '.phases[$p].model // empty' "$policy" 2>/dev/null)
rationale=$(jq -r --arg p "$phase" '.phases[$p].rationale // empty' "$policy" 2>/dev/null)
[ -z "$model" ] && exit 0

# Escalation check: only meaningful for review, only when the escalation
# rule is path-based and evidence (a changed file) actually exists.
escalated=false
if [ "$phase" = "review" ]; then
  changed=$( { git -C "$cwd" diff --name-only HEAD 2>/dev/null; git -C "$cwd" diff --name-only --cached 2>/dev/null; } | sort -u)
  if [ -n "$changed" ]; then
    n=$(jq -r '(.escalations // []) | length' "$policy" 2>/dev/null || echo 0)
    i=0
    while [ "$i" -lt "$n" ]; do
      when=$(jq -r ".escalations[$i].when // empty" "$policy" 2>/dev/null)
      action=$(jq -r ".escalations[$i].action // empty" "$policy" 2>/dev/null)
      case "$when" in
        paths:*)
          globs="${when#paths:}"
          IFS=',' read -ra glob_arr <<< "$globs"
          for f in $changed; do
            for g in "${glob_arr[@]}"; do
              g="$(printf '%s' "$g" | xargs)"
              [ -z "$g" ] && continue
              if [[ "$f" == $g ]]; then
                esc_model=$(printf '%s' "$action" | grep -oiE 'opus|sonnet|haiku|fable' | head -1 | tr '[:upper:]' '[:lower:]')
                if [ -n "$esc_model" ]; then
                  model="$esc_model"
                  rationale="$action (escalated: $f matched $g)"
                  escalated=true
                fi
              fi
            done
          done
          ;;
      esac
      i=$((i + 1))
    done
  fi
fi

case "$phase" in
  plan) agent="planner" ;;
  code) agent="coder" ;;
  review) agent="reviewer" ;;
  explore) agent="explorer" ;;
esac

context="[calibrate] This prompt reads as a **${phase}** task. Per .claude/model-policy.json, delegate it to the \`calibrate:${agent}\` subagent with model=\"${model}\" (${rationale}) via the Agent tool, instead of doing the work directly in this conversation. Skip delegation only if the task is trivial enough that a subagent call would cost more than it saves."

jq -n \
  --arg ctx "$context" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'

mkdir -p "$cwd/.calibrate"
printf '{"ts":"%s","phase":"%s","model":"%s","escalated":%s,"words":%s}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$phase" "$model" "$escalated" "$words" \
  >> "$cwd/.calibrate/route-log.ndjson"

exit 0
