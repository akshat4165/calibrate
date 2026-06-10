#!/usr/bin/env bash
# Phase-0 spike: observe what a router WOULD do, without acting on it.
#
# Logs a tier decision per prompt to .calibrate/route-log.ndjson so we can
# judge classifier quality against real usage before automating anything.
#
# Set CALIBRATE_SPIKE_SWITCH=1 to also rewrite the project's
# .claude/settings.json model field — this tests the open question from
# anthropics/claude-code#43326: does a settings rewrite from a hook take
# effect mid-session? Leave it unset for normal use.

set -u

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)
[ -z "$prompt" ] && exit 0

words=$(printf '%s' "$prompt" | wc -w | tr -d ' ')

# Deliberately crude heuristics — the point of the spike is to measure how
# often crude is wrong, logged against what the user actually needed.
tier="sonnet"
lower=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')
case "$lower" in
  *architect*|*design*|*plan\ *|*refactor*|*migrate*|*security*) tier="opus" ;;
esac
if [ "$words" -lt 12 ] && [ "$tier" = "sonnet" ]; then tier="haiku"; fi

applied=false
if [ "${CALIBRATE_SPIKE_SWITCH:-0}" = "1" ]; then
  mkdir -p .claude
  settings=".claude/settings.json"
  [ -s "$settings" ] || printf '{}' > "$settings"
  tmp=$(mktemp)
  if jq --arg m "$tier" '.model = $m' "$settings" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$settings"
    applied=true
  else
    rm -f "$tmp"
  fi
fi

mkdir -p .calibrate
printf '{"ts":"%s","words":%s,"tier":"%s","applied":%s}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$words" "$tier" "$applied" \
  >> .calibrate/route-log.ndjson

exit 0
