#!/usr/bin/env bash
# Append one machine-readable terminal-state record for a skill run.
set -euo pipefail

usage() {
  echo "usage: $0 --skill NAME --target VALUE --phase VALUE --outcome VALUE --stop-reason VALUE [--head-sha SHA] [--tests VALUE] [--manual-verification VALUE] [--posted-url URL]" >&2
  exit 2
}

skill=''
target=''
phase=''
outcome=''
stop_reason=''
head_sha=''
tests='not-run'
manual_verification='not-applicable'
posted_url=''

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skill) skill=${2-}; shift 2 ;;
    --target) target=${2-}; shift 2 ;;
    --phase) phase=${2-}; shift 2 ;;
    --outcome) outcome=${2-}; shift 2 ;;
    --stop-reason) stop_reason=${2-}; shift 2 ;;
    --head-sha) head_sha=${2-}; shift 2 ;;
    --tests) tests=${2-}; shift 2 ;;
    --manual-verification) manual_verification=${2-}; shift 2 ;;
    --posted-url) posted_url=${2-}; shift 2 ;;
    *) usage ;;
  esac
done

[ -n "$skill" ] && [ -n "$target" ] && [ -n "$phase" ] && [ -n "$outcome" ] && [ -n "$stop_reason" ] || usage

mkdir -p "$HOME/.codex"
jq -cn \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg skill "$skill" \
  --arg target "$target" \
  --arg head_sha "$head_sha" \
  --arg phase "$phase" \
  --arg tests "$tests" \
  --arg manual_verification "$manual_verification" \
  --arg posted_url "$posted_url" \
  --arg outcome "$outcome" \
  --arg stop_reason "$stop_reason" \
  '{timestamp: $timestamp, skill: $skill, target: $target, head_sha: $head_sha, phase: $phase, tests: $tests, manual_verification: $manual_verification, posted_url: $posted_url, outcome: $outcome, stop_reason: $stop_reason}' \
  >> "$HOME/.codex/skill-outcomes.jsonl"
