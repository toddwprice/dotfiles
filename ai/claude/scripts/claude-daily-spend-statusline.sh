#!/bin/bash
#
# claude-daily-spend-statusline.sh
#
# A standalone Claude Code status line showing what you've spent TODAY
# against today's budget, plus an absolute month bar:
#
#   Opus 5 high 23%ctx $142/$167 today [····◇·●·] 12h | $267/$611 | mo [◇···●···] $5000
#
#   Opus 5 the model, from Claude Code's stdin payload — NOT the spend API
#   high   reasoning effort (low|medium|high|xhigh|max). Absent when the
#          model has no effort parameter; Ultracode reports as "xhigh".
#   23%ctx context window used. Amber at 80%, red at 90%, matching
#          claude-rig's own context plugin. Omitted when unknown: the field
#          is null before a session's first API response and after /compact.
#   $142   actual spend today (month-to-date now, minus month-to-date at the
#          last UTC midnight — see "The baseline" below)
#   $167   today's budget: the headroom the ratchet added today
#   ●      where today's spend actually is against that budget
#   ◇      where the clock says it should be, if spent evenly through the day
#   ◉      both markers land on the same slot
#   12h    time until the daily reset at UTC midnight
#   $267   month-to-date, straight from the API
#   $611   the HARD limit — spend.limit, the ratcheted cap the API actually
#          reports. Nothing derived. When the rest of the line looks wrong,
#          these are the two numbers to believe.
#   mo     the whole month on an ABSOLUTE scale: 0 -> the ceiling, fixed all
#          month, so the same spend always renders in the same place. Its ◇
#          is day-of-month, not time-of-day.
#   $5000  your monthly ceiling, trailing the bar it scales — DERIVED by
#          inverting the ratchet, not reported by the API, so treat it as
#          approximate. A manually bumped limit inverts to an effective
#          ceiling above your real tier, and that shows through here.
#
# The three segments run in decreasing order of trustworthiness: `today`
# depends on both the local baseline file and the derived grant, the middle
# pair is pure API, and `mo` rests on the derived ceiling. It is not compact
# on purpose — the absolutes are here so the relative figures can be checked
# against them. Mid-month the divergence is the useful part: "$2450/$2500"
# (98%, near today's hard limit) can sit right next to a green under-pace
# daily bar, and both are true.
#
# ● left of ◇ means under pace; right means over. Color: green under pace,
# yellow at/over pace, red at or above 90% of today's budget. All of that is
# judged on TODAY's numbers — an earlier version compared a MONTH-scoped
# percentage against time-of-day, which pinned red every afternoon by
# mid-month regardless of how the day was actually going.
#
# Why "daily" at all: the Anthropic API has no native daily limit — usage
# credits are metered against a single monthly limit. The daily framing is
# specific to dscout, which ratchets each user's monthly limit upward every
# UTC midnight to simulate a daily cap Anthropic Enterprise doesn't support
# (DEVOPS-2345):
#
#   allowance  = ceiling / days_in_month
#   slack(day) = 2*allowance * (ramp_days - day) / (ramp_days - 1)  # 0 past ramp
#   cap(day)   = min(day * allowance + slack(day), ceiling)
#
# The API reports cap(day) as spend.limit but never the ceiling, so this
# script recovers the ceiling by inverting that formula, then derives today's
# budget as cap(day) - cap(day-1). Note the per-day budget is NOT the
# allowance during the ramp: day 1 grants 3x, days 2-7 grant only 2/3 of
# allowance (tighter than steady state, because the decaying slack is clawed
# back faster than the linear term accrues), and day 8+ grants the true
# allowance.
#
# If your org doesn't ratchet, spend.limit is a flat monthly limit, the
# inversion is meaningless, and this display will be wrong. It is written
# for dscout's setup specifically.
#
# ── The session prefix ───────────────────────────────────────────────────
# Claude Code pipes a session JSON to the statusLine command on stdin, which
# is where the model name, effort level and context percentage come from —
# a completely separate source from the spend API. Fields read:
#
#   .model.display_name
#   .effort.level                  optional; absent if unsupported
#   .context_window.used_percentage  may be null
#
# Each is optional and omitted from the line when missing, so an older
# Claude Code, an effort-less model, or a direct shell run all degrade to
# just the spend segments. Only the context percentage is colored; tinting
# the model name with the spend colors would imply a meaning they do not
# have. Claude Code also exports COLUMNS, unused for now but the hook for
# width-aware compacting later.
#
# ── The baseline ─────────────────────────────────────────────────────────
# The API returns month-to-date spend and never today's, so today's spend is
# mtd_now minus mtd at the last UTC midnight — and that second term has to
# be stored locally. Without it, "spent evenly all month" and "burned the
# month today" return an identical response, so no state-free formula can
# tell them apart. On the first render of a new day there is no baseline
# yet, so the line shows "?" and seeds one; every render after that is
# exact. The file is separate from the response cache, which turns over
# every 60s and so cannot hold a day-old value.
#
# ── Requirements ─────────────────────────────────────────────────────────
#   - macOS (uses the Keychain — this script is not written for Linux)
#   - jq        (brew install jq)
#   - curl      (already on macOS)
#   - macOS Keychain entry "Claude Code-credentials" (created automatically
#     the first time you log in to Claude Code) — this is where your OAuth
#     token lives.
#   - A Claude Enterprise/Team account with usage credits enabled. Individual
#     Pro/Max plans don't have a dollar credit limit and this segment will
#     print nothing for you (silently, on purpose).
#
# ── Install: you have NO status line configured yet ────────────────────────
#   1. Save this file somewhere permanent, e.g.:
#        mkdir -p ~/.claude/scripts
#        cp claude-daily-spend-statusline.sh ~/.claude/scripts/
#        chmod +x ~/.claude/scripts/claude-daily-spend-statusline.sh
#
#   2. Add this to ~/.claude/settings.json (create the file if it doesn't
#      exist yet):
#        {
#          "statusLine": {
#            "type": "command",
#            "command": "bash ~/.claude/scripts/claude-daily-spend-statusline.sh"
#          }
#        }
#
#   3. Restart Claude Code (or start a new session). You should see the bar
#      at the bottom of the terminal.
#
# ── Adapt: you ALREADY have a status line script ───────────────────────────
#   Don't replace your command — call this script from within yours and
#   concatenate its output (one line, one string — there's no notion of
#   separate "widgets" in here) onto your existing line, e.g.:
#
#      spend_line=$(bash ~/.claude/scripts/claude-daily-spend-statusline.sh)
#      echo "${your_existing_line} | ${spend_line}"
#
#   Everything below is a single self-contained function pipeline; skim
#   main() if you'd rather copy the logic inline instead of shelling out to
#   this file.
#
# ── Never blocks on the network ───────────────────────────────────────────
# Stale-while-revalidate: whenever there is a cached response at all, it is
# served IMMEDIATELY and any refresh happens in a detached background
# process. Only a completely absent cache forces a blocking fetch, because
# then there is nothing to show. Previously a stale cache triggered a
# synchronous fetch behind `--max-time 20`, so a slow or hanging endpoint
# left the line blank for up to twenty seconds — the "doesn't render right
# away" symptom. A mkdir-based lock keeps at most one refresh in flight no
# matter how many renders fire during a slow fetch.
#
# ── When it fails ─────────────────────────────────────────────────────────
# Failures render one dim `·` — enough to tell "tried and failed" from "not
# rendered yet", without putting an error on your prompt. The reason goes to
# a log instead:
#
#   tail ~/.claude/cache/claude-daily-spend.log
#
#   2026-09-02T20:37:37Z fetch_failed curl_exit=22
#   2026-09-02T20:37:37Z no_credentials
#   2026-09-02T20:37:37Z parse_failed
#
# Reasons: no_credentials, fetch_failed, parse_failed, cache_write_failed,
# missing_dependency, bad_calendar, inversion_failed, grant_failed,
# stale_refresh_lock. An account with usage credits DISABLED is an expected
# state, not a failure — it renders nothing and logs nothing, so real
# failures do not get buried. The log is byte-capped and self-trimming.
#
# ── Configuration (env vars, all optional) ────────────────────────────────
#   CLAUDE_DAILY_SPEND_CACHE     response cache path
#                                (default ~/.claude/cache/claude-daily-spend.json)
#   CLAUDE_DAILY_SPEND_BASELINE  midnight-baseline path
#                                (default ~/.claude/cache/claude-daily-spend-baseline.json)
#   CLAUDE_DAILY_SPEND_LOG       failure log path
#                                (default ~/.claude/cache/claude-daily-spend.log)
#   CLAUDE_DAILY_SPEND_TTL       cache lifetime in seconds (default 60)
#
# These four exist so the test suite can redirect its writes away from your
# real ~/.claude/cache files. The endpoint URL and the log size cap are
# deliberately NOT overridable — see the note next to them below.
#
# Silent on any failure by design: a status line that errors out or hangs is
# worse than one that's occasionally just missing a segment.

set -uo pipefail

CACHE="${CLAUDE_DAILY_SPEND_CACHE:-$HOME/.claude/cache/claude-daily-spend.json}"
BASELINE="${CLAUDE_DAILY_SPEND_BASELINE:-$HOME/.claude/cache/claude-daily-spend-baseline.json}"
LOGFILE="${CLAUDE_DAILY_SPEND_LOG:-$HOME/.claude/cache/claude-daily-spend.log}"
TTL="${CLAUDE_DAILY_SPEND_TTL:-60}"           # seconds

# Not env-overridable. The endpoint is the one thing here that should NOT be
# redirectable: an env var could silently point a credentialed request at
# another host. Nothing overrides it — not even the tests, which stub `curl`
# on PATH instead. Same for the log cap, which the two tests that care set
# as a shell variable directly.
ENDPOINT="https://api.anthropic.com/api/oauth/usage"
LOG_MAX_BYTES=65536

# TTL lands in `(( age < TTL ))`. A non-numeric value there aborts the script
# under `set -u` ("x: unbound variable"), which for a statusline means a blank
# line instead of a segment — so normalize it to the default. Note `set -u`
# already blocks the `x[$(...)]` arithmetic-injection form on its own (checked
# on bash 3.2); this guard is for graceful degradation, and to keep that true
# if this code is ever reused somewhere without `set -u`.
[[ "$TTL" =~ ^[0-9]+$ ]] || TTL=60
SLOTS=8
DAY_SECONDS=86400

MUTED_GREEN=$'\033[2;32m'
MUTED_YELLOW=$'\033[2;33m'
MUTED_RED=$'\033[2;31m'
COLOR_RESET=$'\033[2;37m'

# Every failure path below renders (near-)nothing, which is right for a
# statusline but leaves no way to tell "no credentials" from "rate limited"
# from "malformed JSON". So each one records a reason here instead. Local and
# per-machine — check your own file when the line looks wrong:
#
#   tail ~/.claude/cache/claude-daily-spend.log
#
# Size-capped rather than logrotate-managed, since nothing else owns this
# file's lifecycle and a statusline can render many times a minute.
log_failure() {
  local reason="$1" detail="${2:-}" kept
  mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null

  # Trim BEFORE appending, so the newest line always survives. Keeping the
  # tail (not the head) means a long-running failure doesn't push out the
  # evidence of what is happening right now.
  #
  # Bounded by BYTES, not by line count: `tail -n` cannot shrink a file whose
  # content is one enormous line, so a line-based trim would let the cap be
  # exceeded indefinitely. `tail -c` always bounds it. The leading partial
  # line that byte-slicing can leave behind is dropped via sed.
  if [[ -f "$LOGFILE" ]] && (( $(wc -c < "$LOGFILE" 2>/dev/null || echo 0) > LOG_MAX_BYTES )); then
    kept="$(tail -c $(( LOG_MAX_BYTES / 2 )) "$LOGFILE" 2>/dev/null | sed '1d')"
    if printf '%s\n' "$kept" > "$LOGFILE.$$" 2>/dev/null; then
      mv -f "$LOGFILE.$$" "$LOGFILE" 2>/dev/null || rm -f "$LOGFILE.$$" 2>/dev/null
    else
      rm -f "$LOGFILE.$$" 2>/dev/null
    fi
  fi

  if [[ -n "$detail" ]]; then
    printf '%s %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$reason" "$detail" \
      >> "$LOGFILE" 2>/dev/null
  else
    printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$reason" \
      >> "$LOGFILE" 2>/dev/null
  fi
}

command -v jq >/dev/null 2>&1 || exit 0
# jq is required to log, so a missing-jq exit above cannot be recorded. curl
# can be.
command -v curl >/dev/null 2>&1 || { log_failure missing_dependency "curl"; exit 0; }

# Pull the OAuth access token Claude Code already logged in with, from the
# macOS Keychain entry Claude Code itself created.
read_access_token() {
  local blob
  blob="$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)" || return 1
  [[ -n "$blob" ]] || return 1
  printf '%s' "$blob" | jq -r '.claudeAiOauth.accessToken // empty'
}

# Extracts percent/used/limit from the usage endpoint's JSON. Prints nothing
# (empty pct) when usage credits aren't enabled for this account, the limit
# is missing, or the input isn't valid JSON at all — all expected, non-error
# states from this function's caller's point of view, so it always exits 0
# and lets an empty result speak for itself (jq exits nonzero on a parse
# error, which `|| true` absorbs here). used/limit are formatted to whole
# dollars (rounded, not truncated) so callers can just interpolate strings.
#
# Fields are pipe-delimited, NOT space-delimited: a non-USD currency renders
# as "5 EUR", so splitting the three fields on whitespace put "EUR 100 EUR"
# into limit and rendered "10% 5/EUR 100 EUR". Callers must read this with
# IFS='|'.
parse_usage_json() {
  local json="$1"
  printf '%s' "$json" | jq -r '
    def money(m; e; c):
      (if c == "USD" then "$" else "" end)
      + (((m + (pow(10;e) / 2)) / pow(10;e)) | floor | tostring)
      + (if c == "USD" then "" else " " + c end);

    if (.spend.enabled == true) and (.spend.limit.amount_minor >= 0) then
      "\(.spend.percent)|"
      + money(.spend.used.amount_minor; .spend.used.exponent; .spend.used.currency)
      + "|"
      + money(.spend.limit.amount_minor; .spend.limit.exponent; .spend.limit.currency)
    else
      ""
    end
  ' 2>/dev/null || true
}

# ── Session fields (Claude Code's stdin payload) ─────────────────────────
#
# Claude Code pipes a session JSON to the statusLine command on stdin — a
# different source from the spend API. Fields used here:
#
#   .model.display_name          e.g. "Opus 5"
#   .context_window.used_percentage
#   .effort.level                low|medium|high|xhigh|max
#
# Every one is treated as optional, because:
#   - used_percentage is NULL before the first API response of a session and
#     again after /compact, which is distinct from the field being absent;
#   - .effort is absent entirely when the model has no effort parameter
#     (Ultracode reports as "xhigh", not a level of its own);
#   - an older Claude Code may omit whole objects, and running the script
#     straight from a shell supplies no stdin at all.
#
# Emits "model|context_pct|effort", pipe-delimited for the same reason
# parse_usage_json is: a display name can contain spaces.
parse_session() {
  local json="$1"
  [[ -n "$json" ]] || { printf '||\n'; return 0; }
  printf '%s' "$json" | jq -r '
    [ (.model.display_name // ""),
      (if (.context_window.used_percentage | type) == "number"
         then (.context_window.used_percentage | tostring) else "" end),
      (.effort.level // "")
    ] | join("|")
  ' 2>/dev/null || printf '||\n'
}

# Tints the session prefix once the context window is filling up. Thresholds
# match the claude-rig 2.70-context plugin (80 amber, 90 red) so the two
# statuslines agree. An unknown percentage stays uncolored rather than
# defaulting to a reassuring green it cannot vouch for.
colorize_context() {
  local prefix="$1" ctx="$2"
  if [[ ! "$ctx" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$prefix"
  elif (( ctx >= 90 )); then
    printf '%s%s\n' "$MUTED_RED" "$prefix"
  elif (( ctx >= 80 )); then
    printf '%s%s\n' "$MUTED_YELLOW" "$prefix"
  else
    printf '%s\n' "$prefix"
  fi
}

# "Opus 5 high 23%ctx", dropping whichever pieces are unknown. Returns an
# empty string when nothing is known, so the caller adds no separator.
render_session_prefix() {
  local model="$1" ctx="$2" effort="$3" out=""
  [[ -n "$model" ]] && out="$model"
  if [[ -n "$effort" ]]; then
    [[ -n "$out" ]] && out+=" "
    out+="$effort"
  fi
  if [[ -n "$ctx" ]]; then
    [[ -n "$out" ]] && out+=" "
    out+="${ctx}%ctx"
  fi
  printf '%s\n' "$out"
}

# Raw minor units for arithmetic, as "used|limit". Same enabled/limit gating
# and same always-exit-0 contract as parse_usage_json, which formats the same
# fields for display instead.
parse_usage_minor() {
  local json="$1"
  printf '%s' "$json" | jq -r '
    if (.spend.enabled == true) and (.spend.limit.amount_minor >= 0) then
      "\(.spend.used.amount_minor)|\(.spend.limit.amount_minor)"
    else
      ""
    end
  ' 2>/dev/null || true
}

# ── The ratchet (DEVOPS-2345) ────────────────────────────────────────────
#
# dscout ratchets each user's monthly credit limit daily to simulate a daily
# cap Anthropic doesn't support natively:
#
#   allowance  = ceiling / days_in_month
#   slack(day) = 2*allowance * (ramp_days - day) / (ramp_days - 1)   # 0 past ramp
#   cap(day)   = min(day * allowance + slack(day), ceiling)
#
# The API returns cap(day) as spend.limit but NOT the tier ceiling, so the
# ceiling is recovered by inverting: cap(day) = (ceiling/n) * k(day), hence
# ceiling = cap(day) * n / k(day). Verified against live data — spend.limit
# $611.11 on 2026-09-02 (day 2, 30-day month) inverts to $5000.
#
# All money is in MINOR units (cents) and all arithmetic is integer, because
# bash has no floats. k is scaled by 1000 for the same reason.
RAMP_DAYS=7
# K_SCALE must be a multiple of (RAMP_DAYS - 1), the ramp's denominator, or
# k(day) truncates and the error compounds through ratchet_cap and
# invert_ceiling. At 1000 that cost $0.11 on cap(2) and put the inverted
# ceiling $0.91 ABOVE the true one; 6000 is exact for every ramp day.
K_SCALE=6000

# Calendar days in a month, with the full Gregorian leap rule.
days_in_month() {
  local year="$1" month="$2"
  case "$month" in
    1|3|5|7|8|10|12) printf '31\n' ;;
    4|6|9|11)        printf '30\n' ;;
    2)
      if (( year % 400 == 0 )) || { (( year % 4 == 0 )) && (( year % 100 != 0 )); }; then
        printf '29\n'
      else
        printf '28\n'
      fi
      ;;
    *) return 1 ;;
  esac
}

# The ratchet multiplier, scaled by K_SCALE. Inside the ramp the decaying
# slack adds to the linear term; past it k is just the day number.
ratchet_k() {
  local day="$1"
  if (( day <= RAMP_DAYS )); then
    printf '%s\n' $(( day * K_SCALE + 2 * (RAMP_DAYS - day) * K_SCALE / (RAMP_DAYS - 1) ))
  else
    printf '%s\n' $(( day * K_SCALE ))
  fi
}

# Recover the tier ceiling from an observed cap. NOTE this returns the
# EFFECTIVE ceiling: if the limit was manually bumped above today's ratchet
# grant, the result is inflated and is NOT the tier ceiling. Safe to use,
# unsafe to label as the tier — see inversion_bump_casegen.rb.
invert_ceiling() {
  local cap_minor="$1" day="$2" n="$3" k
  k="$(ratchet_k "$day")"
  (( k > 0 )) || return 1
  printf '%s\n' $(( cap_minor * n * K_SCALE / k ))
}

# cap(day) from a ceiling. day 0 yields 0 — the month-start baseline, so
# compute_grant can subtract it on day 1 without a special case.
ratchet_cap() {
  local day="$1" ceiling_minor="$2" n="$3" k cap
  (( day <= 0 )) && { printf '0\n'; return 0; }
  (( n > 0 )) || return 1
  k="$(ratchet_k "$day")"
  cap=$(( ceiling_minor * k / (n * K_SCALE) ))
  (( cap > ceiling_minor )) && cap="$ceiling_minor"
  printf '%s\n' "$cap"
}

# Today's added headroom: cap(day) - cap(day-1). This is the daily pacing
# target, NOT a cap — actual spend can exceed it, since the real limit is
# the month cap. Three regimes for a $5000/30-day month: day 1 = $500 (3x
# allowance), days 2-7 = $111.11 (only 2/3 of allowance — tighter than
# steady state, because the decaying slack is clawed back faster than the
# linear term accrues), day 8+ = $166.67. Zero at the clamp.
compute_grant() {
  local day="$1" ceiling_minor="$2" n="$3" today prev
  today="$(ratchet_cap "$day" "$ceiling_minor" "$n")" || return 1
  prev="$(ratchet_cap $(( day - 1 )) "$ceiling_minor" "$n")" || return 1
  printf '%s\n' $(( today - prev ))
}

# ── The midnight baseline ────────────────────────────────────────────────
#
# The API returns month-to-date spend, never today's. Today's spend is
# therefore mtd_now - mtd_at_last_UTC_midnight, and that second term has to
# be persisted. This file is the reason a daily display is possible at all:
# without it, "spent evenly all month" and "burned the month today" produce
# an identical response (verified: day 10, cap $1666.67, MTD $1500 renders
# the same for both). See daily_progress_casegen.rb.
#
# Deliberately NOT the TTL cache: that turns over every 60s, so the value it
# holds is a minute old, not a day old.

# Prints the stored baseline for the given UTC date, or nothing if there
# isn't one for that date (cold start, first run of a new day, corrupt file).
# Empty means "cannot compute today's spend" and the caller degrades.
read_baseline() {
  local today="$1" stored_date
  [[ -s "$BASELINE" ]] || return 0
  stored_date="$(jq -r '.date // empty' "$BASELINE" 2>/dev/null)" || return 0
  [[ "$stored_date" == "$today" ]] || return 0
  jq -r '.mtd_minor // empty' "$BASELINE" 2>/dev/null || return 0
}

# Records month-to-date as of the start of the given UTC date. Same temp
# file + rename as the cache, so a concurrent reader never sees a partial
# write, and the temp file is cleaned up whichever step fails.
write_baseline() {
  local today="$1" mtd_minor="$2"
  mkdir -p "$(dirname "$BASELINE")" 2>/dev/null
  if printf '{"date":"%s","mtd_minor":%s}' "$today" "$mtd_minor" \
      > "$BASELINE.$$" 2>/dev/null; then
    mv -f "$BASELINE.$$" "$BASELINE" 2>/dev/null || rm -f "$BASELINE.$$" 2>/dev/null
  else
    rm -f "$BASELINE.$$" 2>/dev/null
  fi
}

# Today's spend. Floored at zero: a negative result means a month rollover
# (MTD reset below the baseline) or a corrupt baseline, and a negative daily
# spend is never meaningful.
compute_today_spend() {
  local mtd_now="$1" baseline="$2" spend
  spend=$(( mtd_now - baseline ))
  (( spend < 0 )) && spend=0
  printf '%s\n' "$spend"
}

# Color: red at/above 90% absolute spend, yellow at/over pace, green under
# pace. Same thresholds drive both segments, so they never disagree in color.
# elapsed/DAY_SECONDS is "how far into the day", scaled by 100 and compared
# against pct so both sides of the pace check stay integer arithmetic.
compute_color() {
  local pct="$1" elapsed="$2" day_seconds="$3"
  if (( pct >= 90 )); then
    printf 'red\n'
  elif (( elapsed > 0 )) && (( pct * day_seconds >= 100 * elapsed )); then
    printf 'yellow\n'
  else
    printf 'green\n'
  fi
}

# Maps a numerator/denominator ratio onto a slot index in [0, slots), used
# for both "where spend actually is" (pct/100) and "where the clock says it
# should be" (elapsed/day_seconds). Clamped so a value at or above the
# denominator lands on the last slot instead of one past the end.
compute_slot() {
  local numerator="$1" denominator="$2" slots="$3"
  (( denominator > 0 )) || return 1
  local slot=$(( numerator * slots / denominator ))
  (( slot >= slots )) && slot=$(( slots - 1 ))
  (( slot < 0 )) && slot=0
  printf '%s\n' "$slot"
}

# Renders the SLOTS-wide bar: ◉ where both markers land on the same slot, ●
# for the actual-spend marker alone, ◇ for the expected-pace marker alone,
# and · for every other slot.
render_bar() {
  local slot_used="$1" slot_expected="$2" slots="$3"
  local bar="" i
  for (( i = 0; i < slots; i++ )); do
    if   (( i == slot_used && i == slot_expected )); then bar+="◉"
    elif (( i == slot_used     ));                   then bar+="●"
    elif (( i == slot_expected ));                   then bar+="◇"
    else                                                  bar+="·"
    fi
  done
  printf '%s\n' "$bar"
}

# Day-of-month position for the month bar's ◇ marker. Distinct from
# compute_slot's time-of-day: this maps the CALENDAR day onto the bar, so ◇
# advances once per day rather than continuously.
month_slot() {
  local day="$1" n="$2" slots="$3" slot
  (( n > 0 )) || return 1
  slot=$(( (day - 1) * slots / n ))
  (( slot >= slots )) && slot=$(( slots - 1 ))
  (( slot < 0 )) && slot=0
  printf '%s\n' "$slot"
}

# Formats a minor-unit amount as whole dollars, rounded (not truncated).
format_dollars() {
  local minor="$1"
  printf '$%s\n' $(( (minor + 50) / 100 ))
}

# Assembles the whole line, uncolored. Two segments:
#
#   $142/$167 today [·····◇●·] 12h | mo [◉·······]
#
# LEFT is today: actual spend / today's grant, with ● where spend actually
# is against that grant and ◇ where the clock says it should be — the same
# glyph meanings the month-scoped version used, now applied to a number
# that is genuinely daily.
#
# RIGHT is the month on an ABSOLUTE scale, 0 -> tier ceiling, fixed all
# month so the same spend always renders in the same place. Bare bar, no
# amounts, to keep the line short. Its ◇ is day-of-month, not time-of-day.
#
# MIDDLE is the hard limit: month-to-date against spend.limit, the ratcheted
# cap the API actually reports. Both figures come straight from the API, so
# this is the one segment with nothing derived in it — the anchor for
# sanity-checking everything else on the line.
#
# today_spend_minor may be EMPTY, meaning "no baseline, cannot know" — that
# renders "?" and an empty daily bar rather than implying a position.
render_daily_line() {
  local today_minor="$1" grant_minor="$2" limit_minor="$3" mtd_minor="$4"
  local ceiling_minor="$5" day="$6" n="$7" remaining="$8"
  local daily_bar month_bar left elapsed clock_slot spend_slot
  local m_used_slot m_day_slot

  elapsed=$(( DAY_SECONDS - remaining ))
  clock_slot="$(compute_slot "$elapsed" "$DAY_SECONDS" "$SLOTS")"

  if [[ -z "$today_minor" ]]; then
    # Unknown daily spend: show the grant but no markers at all. An empty
    # bar is honest; a ● somewhere would be a guess.
    left="?/$(format_dollars "$grant_minor") today"
    daily_bar="$(render_bar -1 -1 "$SLOTS")"
  elif (( grant_minor <= 0 )); then
    # Zero grant at the ceiling clamp — no denominator to pace against.
    left="$(format_dollars "$today_minor")/-- today"
    daily_bar="$(render_bar -1 -1 "$SLOTS")"
  else
    left="$(format_dollars "$today_minor")/$(format_dollars "$grant_minor") today"
    spend_slot="$(compute_slot "$today_minor" "$grant_minor" "$SLOTS")"
    daily_bar="$(render_bar "$spend_slot" "$clock_slot" "$SLOTS")"
  fi

  m_used_slot="$(compute_slot "$mtd_minor" "$ceiling_minor" "$SLOTS")"
  m_day_slot="$(month_slot "$day" "$n" "$SLOTS")"
  month_bar="$(render_bar "$m_used_slot" "$m_day_slot" "$SLOTS")"

  # Three segments, pipe-separated, in decreasing order of trustworthiness:
  #
  #   today   — depends on the local baseline file AND the derived grant
  #   mtd/cap — spend.used / spend.limit, both straight from the API. Nothing
  #             derived. This is the anchor: if the other segments look wrong,
  #             these are the numbers to believe.
  #   mo      — the month bar, trailed by the DERIVED ceiling that is also
  #             the bar's scale. The ceiling is inverted from the ratchet
  #             rather than reported, so it is approximate, and a manually
  #             bumped limit inverts to an effective ceiling above the real
  #             tier. Shown anyway; documented, not hidden.
  #
  # MTD is printed once, in the cap pair — it used to appear in both the cap
  # and month segments. The ceiling sits AFTER the month bar so it reads as
  # that bar's upper bound rather than as a second ratio.
  #
  # Deliberately not compact — the absolute figures are here so the relative
  # ones can be checked against them.
  printf '%s [%s] %s | %s/%s | mo [%s] %s\n' \
    "$left" "$daily_bar" "$(format_remaining "$remaining")" \
    "$(format_dollars "$mtd_minor")" "$(format_dollars "$limit_minor")" \
    "$month_bar" "$(format_dollars "$ceiling_minor")"
}

# One dim glyph, printed when something failed. A fully blank statusline is
# ambiguous — you cannot tell a failure from a render that has not happened
# yet — and this is the smallest signal that resolves that without becoming
# noise. The reason lives in the log, not on your prompt.
render_fail_marker() {
  printf '%s·%s\n' "$COLOR_RESET" "$COLOR_RESET"
}

# Formats seconds remaining until UTC midnight as whole hours, else whole
# minutes, else "now" once under a minute is left.
format_remaining() {
  local remaining="$1"
  if   (( remaining >= 3600 )); then printf '%sh\n' "$(( remaining / 3600 ))"
  elif (( remaining >= 60   )); then printf '%sm\n' "$(( remaining / 60 ))"
  else                               printf 'now\n'
  fi
}

# Hits the endpoint and replaces the cache. Prints the body on success.
# Shared by the synchronous cold-start path and the background refresh.
fetch_and_cache() {
  local token json
  token="$(read_access_token)" || { log_failure no_credentials; return 1; }
  [[ -n "$token" ]] || { log_failure no_credentials "empty token"; return 1; }

  # -s, NOT -sS: `-S` makes curl print its error to stderr, which lands in
  # the status line ("curl: (56) ... error: 429" was observed live during a
  # rate limit). A status line must fail silently, so the error is swallowed
  # and the log is the only record.
  json="$(curl -s --fail --location --max-time 20 \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    --url "$ENDPOINT" 2>/dev/null)" || {
      log_failure fetch_failed "curl_exit=$?"
      return 1
    }
  [[ -n "$json" ]] || { log_failure fetch_failed "empty body"; return 1; }

  # A failed write is survivable — the fresh JSON still prints below, we just
  # re-fetch next render. But clean up the temp file whichever step failed, or
  # the cache dir accumulates one orphan per failure, forever.
  mkdir -p "$(dirname "$CACHE")" 2>/dev/null
  if printf '%s' "$json" > "$CACHE.$$" 2>/dev/null; then
    mv -f "$CACHE.$$" "$CACHE" 2>/dev/null || {
      log_failure cache_write_failed "rename"
      rm -f "$CACHE.$$" 2>/dev/null
    }
  else
    log_failure cache_write_failed "write"
    rm -f "$CACHE.$$" 2>/dev/null
  fi
  printf '%s' "$json"
}

# Kicks off a refresh that outlives this render. setsid/& fully detaches it so
# Claude Code isn't waiting on the pipe, and a mkdir lock means at most one
# refresh is in flight no matter how many renders fire during a slow fetch.
#
# The lock is a directory because mkdir is atomic on every POSIX filesystem;
# a `[[ -e ]]` test plus touch would race. Staleness is bounded so a killed
# refresh can't wedge future ones forever.
refresh_cache_async() {
  local lock="$CACHE.refresh.lock" lock_age

  if [[ -d "$lock" ]]; then
    lock_age=$(( $(date +%s) - $(stat -f %m "$lock" 2>/dev/null || echo 0) ))
    if (( lock_age < 120 )); then
      return 0    # a refresh is already running
    fi
    # Older than any plausible fetch (curl caps at 20s), so the holder died.
    rmdir "$lock" 2>/dev/null
    log_failure stale_refresh_lock "age=${lock_age}s"
  fi

  mkdir "$lock" 2>/dev/null || return 0   # lost the race; someone else has it

  (
    trap 'rmdir "$lock" 2>/dev/null' EXIT
    fetch_and_cache >/dev/null 2>&1
  ) </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null || true
}

# Serves the cache, refreshing in the background when it has gone stale —
# stale-while-revalidate. The render NEVER blocks on the network when there
# is anything at all to show, because a synchronous fetch behind
# `--max-time 20` could leave the statusline blank for twenty seconds on a
# slow or hanging endpoint. That was the observed "doesn't render right away".
#
# Only a completely absent cache forces a blocking fetch, since there is
# nothing else to display.
fetch_usage() {
  local age
  if [[ -s "$CACHE" ]]; then
    age=$(( $(date +%s) - $(stat -f %m "$CACHE" 2>/dev/null || echo 0) ))
    cat "$CACHE"
    (( age >= TTL )) && refresh_cache_async
    return 0
  fi

  fetch_and_cache || return 1
}

main() {
  local json used_minor limit_minor now_epoch elapsed remaining
  local today_str day month year n ceiling grant baseline today_spend
  local daily_pct color_name color line
  local session_json session_model session_ctx session_effort prefix

  # Claude Code pipes the session JSON in; a direct shell run supplies
  # nothing. The `-t 0` test is the whole guard: a terminal stdin would make
  # `cat` block forever, while a pipe or /dev/null reads to EOF immediately.
  #
  # NOT `read -t 0 -N 0` to peek without consuming — `-N` is bash 4+ and this
  # script runs under macOS's bash 3.2, where that silently fails the check
  # and the prefix never renders. Measured, not assumed.
  session_json=""
  if [[ ! -t 0 ]]; then
    session_json="$(cat 2>/dev/null)"
  fi
  IFS='|' read -r session_model session_ctx session_effort \
    < <(parse_session "$session_json")
  prefix="$(render_session_prefix "${session_model:-}" "${session_ctx:-}" \
    "${session_effort:-}")"

  # fetch_and_cache already logged whatever went wrong, so these paths just
  # surface the marker. FAIL_MARKER distinguishes "tried and failed" from
  # "still loading" — a fully blank line is ambiguous.
  json="$(fetch_usage)" || { render_fail_marker; exit 0; }
  [[ -n "$json" ]] || { render_fail_marker; exit 0; }

  IFS='|' read -r used_minor limit_minor < <(parse_usage_minor "$json")
  if [[ ! "${used_minor:-}" =~ ^[0-9]+$ || ! "${limit_minor:-}" =~ ^[0-9]+$ ]]; then
    # An account with usage credits disabled returns a well-formed response
    # with no spend figures — expected, not an error, and logging it on every
    # render would bury real failures. Only genuinely unreadable bodies log.
    if ! printf '%s' "$json" | jq -e '.spend.enabled == false' >/dev/null 2>&1; then
      log_failure parse_failed
      render_fail_marker
    fi
    exit 0
  fi

  now_epoch=$(date -u +%s)
  elapsed=$(( now_epoch % DAY_SECONDS ))
  remaining=$(( DAY_SECONDS - elapsed ))

  # All dates are UTC, matching the ratchet's midnight boundary.
  today_str="$(date -u +%Y-%m-%d)"
  year=$(date -u +%Y)
  month=$(date -u +%-m)
  day=$(date -u +%-d)
  n="$(days_in_month "$year" "$month")" || {
    log_failure bad_calendar "year=$year month=$month"
    render_fail_marker
    exit 0
  }

  # Recover the ceiling from today's cap, then derive today's grant from it.
  # This is the EFFECTIVE ceiling: a manually bumped limit inflates it, which
  # inflates the grant proportionally. That errs toward "you have room" — the
  # defensible direction for someone on urgent bumped work — and is the
  # documented lump we accept. See inversion_bump_casegen.rb.
  ceiling="$(invert_ceiling "$limit_minor" "$day" "$n")" || {
    log_failure inversion_failed "limit=$limit_minor day=$day n=$n"
    render_fail_marker
    exit 0
  }
  grant="$(compute_grant "$day" "$ceiling" "$n")" || {
    log_failure grant_failed "ceiling=$ceiling day=$day n=$n"
    render_fail_marker
    exit 0
  }

  # Today's spend needs the midnight baseline. On the first run of a new day
  # (or a cold start) there isn't one, so seed it with the current MTD and
  # render "?" — better than guessing a number we cannot know. From the next
  # run onward today's spend is exact.
  baseline="$(read_baseline "$today_str")"
  if [[ -z "$baseline" ]]; then
    write_baseline "$today_str" "$used_minor"
    today_spend=""
  else
    today_spend="$(compute_today_spend "$used_minor" "$baseline")"
  fi

  # Color keys off TODAY's pace, not the month's. Feeding a month-scoped
  # percentage to a time-of-day comparison is exactly the category error this
  # rewrite removes: it pinned red every afternoon by mid-month. With no
  # baseline yet there is no daily pace to judge, so stay green rather than
  # alarm on an unknown.
  if [[ -n "$today_spend" ]] && (( grant > 0 )); then
    daily_pct=$(( today_spend * 100 / grant ))
    color_name="$(compute_color "$daily_pct" "$elapsed" "$DAY_SECONDS")"
  else
    color_name=green
  fi
  case "$color_name" in
    red)    color="$MUTED_RED" ;;
    yellow) color="$MUTED_YELLOW" ;;
    *)      color="$MUTED_GREEN" ;;
  esac

  line="$(render_daily_line "$today_spend" "$grant" "$limit_minor" \
    "$used_minor" "$ceiling" "$day" "$n" "$remaining")"
  # The session prefix is uncolored: the spend colors mean "pacing", and
  # tinting the model name with them would imply something they do not say.
  # Context gets its own threshold coloring instead.
  if [[ -n "$prefix" ]]; then
    # colorize_context emits its own leading color (or none), so no reset is
    # needed ahead of it — one after, to stop it bleeding into the spend
    # segment, which then sets its own.
    printf '%s%s %s%s%s\n' \
      "$(colorize_context "$prefix" "${session_ctx:-}")" "$COLOR_RESET" \
      "$color" "$line" "$COLOR_RESET"
  else
    printf '%s%s%s\n' "$color" "$line" "$COLOR_RESET"
  fi
}

# Lets the test suite `source` this file for its functions without
# triggering a live run — same idea as Python's `if __name__ == "__main__"`.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
