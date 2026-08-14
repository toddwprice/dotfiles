#!/usr/bin/env bats
#
# Tests for claude/scripts/fleet — the read-only Claude Code fleet digest.
#
# Every test is fixture-driven: CLAUDE_FLEET_AGENTS_JSON stands in for
# `claude agents --json`, and a fake ~/.claude/projects tree under the bats
# $HOME stands in for the real transcripts. Nothing here needs a live session,
# and nothing here can touch one.
#
# What a green run here does NOT prove (see the plan's Verification block):
#   - bats overrides $HOME, so a fully green suite is compatible with
#     ~/.claude/scripts/fleet not existing at all. Only the readlink checks in
#     the ticket's Verification block test the real symlink layout.
#   - A `skip` renders as `ok N <name> # skip <reason>`, so a TAP grep of the
#     form `grep -c '^ok .*<name>'` counts a skipped test as a pass. Any check
#     that leans on this suite's TAP output must exclude the skip marker:
#         grep -cE '^ok ([0-9]+ )?[^#]*<name>[^#]*$'
#     Verified on bats 1.13.0: the loose form prints 2 against one real pass
#     plus one skip, the tightened form prints 1.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../claude/scripts/fleet"
  export HOME="$BATS_TEST_TMPDIR/home"
  PROJECTS="$HOME/.claude/projects"
  AGENTS="$BATS_TEST_TMPDIR/agents.json"
  mkdir -p "$PROJECTS"
  export CLAUDE_FLEET_AGENTS_JSON="$AGENTS"
}

# --- fixture helpers ---------------------------------------------------------

# The slug replaces BOTH / and . with a dash, so a cwd containing a dot lands
# in a directory with a double dash. Mirrored deliberately from the script so a
# one-sided change fails a test instead of silently missing every dotted cwd.
slug_of() {
  local cwd=$1
  printf '%s' "${cwd//[\/.]/-}"
}

# transcript_for <cwd> <sessionId> -> prints the path, creating the parent dir
transcript_for() {
  local dir="$PROJECTS/$(slug_of "$1")"
  mkdir -p "$dir"
  printf '%s/%s.jsonl' "$dir" "$2"
}

# epoch millis, N seconds ago
ms_ago() { printf '%s' $(( ( $(date +%s) - $1 ) * 1000 )); }

# ISO-8601 UTC, N seconds ago (BSD date; these dotfiles are macOS)
iso_ago() { date -u -r $(( $(date +%s) - $1 )) +%Y-%m-%dT%H:%M:%S.000Z; }

# The output line that carries a given session's name — the state, stall marker
# and waitingFor all live there. Asserting against this line rather than the
# whole output keeps a footer legend that mentions "stalled" from satisfying a
# row-level stall assertion.
row_for() { grep -- "$1" <<<"$output" | head -1; }

line_no_of() { grep -n -- "$1" <<<"$output" | head -1 | cut -d: -f1; }

# ============================================================================
# slice 1 — enumerate, join to transcripts, render
# ============================================================================

@test "a live interactive session is reported with its branch and newest PR" {
  local t
  t="$(transcript_for /w/devops-2241 22faf95f-7441-46b0-8f15-6fde2c70f092)"
  # 28038 FIRST, 28035 later: the row must name the newest, not the first one
  # it happens to see. Ordered against life on purpose — in the real transcript
  # 28035 is also first, which would make this mutation invisible.
  cat > "$t" <<EOF
{"type":"attachment","gitBranch":"devops-2241-share-prefork-spacy-pipeline","timestamp":"$(iso_ago 120)"}
{"type":"pr-link","prNumber":28038,"prUrl":"https://github.com/dscout/dscout/pull/28038","timestamp":"$(iso_ago 110)"}
{"type":"pr-link","prNumber":28035,"prUrl":"https://github.com/dscout/dscout/pull/28035","timestamp":"$(iso_ago 100)"}
EOF
  cat > "$AGENTS" <<EOF
[{"pid":1,"cwd":"/w/devops-2241","kind":"interactive","status":"busy",
  "startedAt":$(ms_ago 300),"sessionId":"22faf95f-7441-46b0-8f15-6fde2c70f092",
  "name":"devops-2241-5e"}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"devops-2241-share-prefork-spacy-pipeline"* ]]
  [[ "$output" == *"28035"* ]]
  [[ "$output" != *"28038"* ]]
}

@test "an interactive row's absent state does not blank its status" {
  cat > "$AGENTS" <<EOF
[{"pid":2,"cwd":"/w/frg-1234","kind":"interactive","status":"waiting",
  "waitingFor":"input needed","startedAt":$(ms_ago 900),
  "sessionId":"aaaaaaaa-0000-0000-0000-000000000001","name":"frg-1234-12"}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  # State is the first column of the session's own line.
  [[ "$(row_for frg-1234-12)" =~ ^[[:space:]]*waiting[[:space:]] ]]
}

@test "a session whose transcript is missing is still listed" {
  cat > "$AGENTS" <<EOF
[{"pid":3,"cwd":"/w/frg-1105","kind":"interactive","status":"busy",
  "startedAt":$(ms_ago 300),"sessionId":"deadbeef-0000-0000-0000-000000000002",
  "name":"frg-1105-50"}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"frg-1105-50"* ]]
  [[ "$output" == *"branch unavailable"* ]]
  [[ "$output" == *"PR unavailable"* ]]
}

@test "a cwd containing a dot still resolves to its transcript" {
  local t
  t="$(transcript_for /Users/toddprice/.claude bbbbbbbb-0000-0000-0000-000000000003)"
  # Belt check on the fixture itself: the dot must have become a second dash.
  [[ "$t" == *"/-Users-toddprice--claude/"* ]]
  cat > "$t" <<EOF
{"type":"attachment","gitBranch":"dotfiles-tod-6","timestamp":"$(iso_ago 60)"}
EOF
  cat > "$AGENTS" <<EOF
[{"pid":4,"cwd":"/Users/toddprice/.claude","kind":"interactive","status":"idle",
  "startedAt":$(ms_ago 300),"sessionId":"bbbbbbbb-0000-0000-0000-000000000003",
  "name":"claude-cfg-01"}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dotfiles-tod-6"* ]]
  [[ "$output" != *"branch unavailable"* ]]
}

@test "a transcript with no ai-title falls back rather than printing blank" {
  local t
  t="$(transcript_for /w/ena-443 cccccccc-0000-0000-0000-000000000004)"
  cat > "$t" <<EOF
{"type":"attachment","gitBranch":"ena-443-copy-data-manifest","timestamp":"$(iso_ago 60)"}
EOF
  cat > "$AGENTS" <<EOF
[{"pid":5,"cwd":"/w/ena-443","kind":"interactive","status":"idle",
  "startedAt":$(ms_ago 300),"sessionId":"cccccccc-0000-0000-0000-000000000004",
  "name":"ena-443-9c"}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  # The title line is the branch, and it is not empty.
  [[ "$output" == *"ena-443-copy-data-manifest"* ]]
  run "$SCRIPT" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[0].title' <<<"$output")" = "ena-443-copy-data-manifest" ]
}

@test "a suffixed worktree cwd still yields its ticket id" {
  cat > "$AGENTS" <<EOF
[{"pid":6,"cwd":"/Users/toddprice/dscout-wt/devops-2241-slice2","kind":"interactive",
  "status":"idle","startedAt":$(ms_ago 300),
  "sessionId":"dddddddd-0000-0000-0000-000000000005","name":"devops-2241-slice2-aa"}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DEVOPS-2241"* ]]
}

@test "a worktree with no ticket in its name shows no ticket rather than a wrong one" {
  cat > "$AGENTS" <<EOF
[{"pid":7,"cwd":"/Users/toddprice/dscout-wt/docker-dev-loop-speedup","kind":"interactive",
  "status":"idle","startedAt":$(ms_ago 300),
  "sessionId":"eeeeeeee-0000-0000-0000-000000000006","name":"docker-dev-loop-99"}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"DOCKER"* ]]
  [[ "$output" == *"docker-dev-loop-speedup"* ]]
  run "$SCRIPT" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[0].ticket' <<<"$output")" = "" ]
  [ "$(jq -r '.[0].title' <<<"$output")" = "docker-dev-loop-speedup" ]
}

@test "an empty session list says so instead of printing a bare header" {
  printf '[]\n' > "$AGENTS"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no sessions are running"* ]]
}

@test "an unreadable session source is reported as unreadable, not as an empty fleet" {
  printf 'this is not json at all\n' > "$AGENTS"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"could not read the session list"* ]]
  [[ "$output" != *"no sessions are running"* ]]
}

@test "a row carrying neither status nor state is still listed, with its state marked unavailable" {
  # Measured live 2026-08-14: 1 of 19 rows (an interactive session in
  # /Users/toddprice/dscout-wt/core-793) carried neither .status nor .state.
  # INV-1 says "read .status for every row", which gives no answer for a row
  # that hasn't got one — so fail open the way INV-2 does for a transcript:
  # mark the column, keep the row.
  cat > "$AGENTS" <<EOF
[{"pid":8,"cwd":"/Users/toddprice/dscout-wt/core-793","kind":"interactive",
  "startedAt":$(ms_ago 300),"sessionId":"ffffffff-0000-0000-0000-000000000007",
  "name":"core-793-86","waitingFor":null}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"core-793-86"* ]]
  [[ "$(row_for core-793-86)" =~ ^[[:space:]]*unavailable[[:space:]] ]]
  # An unknown state is not an invitation to guess it is blocked.
  [[ "$output" != *"BLOCKED ON YOU"* ]]
}

@test "--json emits one object per session with the joined fields" {
  # The plan's own Verification block flags `fleet --json | jq -e 'type ==
  # "array"'` as passing on []. This asserts the array actually carries the
  # sessions, which is the part that line never proves.
  local t
  t="$(transcript_for /w/frg-1240 11111111-0000-0000-0000-000000000008)"
  cat > "$t" <<EOF
{"type":"ai-title","aiTitle":"Bound scale anchor labels"}
{"type":"attachment","gitBranch":"frg-1240-bound-anchors","timestamp":"$(iso_ago 60)"}
{"type":"pr-link","prNumber":28026,"timestamp":"$(iso_ago 50)"}
EOF
  cat > "$AGENTS" <<EOF
[{"pid":9,"cwd":"/w/frg-1240","kind":"interactive","status":"busy",
  "startedAt":$(ms_ago 300),"sessionId":"11111111-0000-0000-0000-000000000008",
  "name":"frg-1240-7a"}]
EOF
  run "$SCRIPT" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r 'length' <<<"$output")" -eq 1 ]
  [ "$(jq -r '.[0].name' <<<"$output")" = "frg-1240-7a" ]
  [ "$(jq -r '.[0].ticket' <<<"$output")" = "FRG-1240" ]
  [ "$(jq -r '.[0].title' <<<"$output")" = "Bound scale anchor labels" ]
  [ "$(jq -r '.[0].branch' <<<"$output")" = "frg-1240-bound-anchors" ]
  [ "$(jq -r '.[0].pr' <<<"$output")" = "28026" ]
}

# ============================================================================
# slice 2 — attention triage
# ============================================================================

@test "sessions blocked on Todd are reported before anything else" {
  cat > "$AGENTS" <<EOF
[{"pid":10,"cwd":"/w/aaa","kind":"interactive","status":"idle",
  "startedAt":$(ms_ago 300),"sessionId":"22222222-0000-0000-0000-000000000009","name":"row-idle"},
 {"pid":11,"cwd":"/w/bbb","kind":"interactive","status":"busy",
  "startedAt":$(ms_ago 300),"sessionId":"33333333-0000-0000-0000-00000000000a","name":"row-busy"},
 {"pid":12,"cwd":"/w/ccc","kind":"interactive","status":"waiting","waitingFor":"input needed",
  "startedAt":$(ms_ago 300),"sessionId":"44444444-0000-0000-0000-00000000000b","name":"row-waiting"}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(line_no_of row-waiting)" -lt "$(line_no_of row-busy)" ]
  [ "$(line_no_of row-waiting)" -lt "$(line_no_of row-idle)" ]
  [[ "$output" == *"input needed"* ]]
}

@test "a finished background session is not reported as blocked" {
  cat > "$AGENTS" <<EOF
[{"pid":13,"cwd":"/w/ddd","kind":"background","id":"0b6f8ecb","status":"idle","state":"done",
  "startedAt":$(ms_ago 300),"sessionId":"55555555-0000-0000-0000-00000000000c","name":"pr review 28053"}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pr review 28053"* ]]
  [[ "$output" != *"BLOCKED ON YOU"* ]]
}

@test "with nothing blocked, the blocked section is omitted rather than printed empty" {
  cat > "$AGENTS" <<EOF
[{"pid":14,"cwd":"/w/eee","kind":"interactive","status":"idle",
  "startedAt":$(ms_ago 300),"sessionId":"66666666-0000-0000-0000-00000000000d","name":"row-quiet"},
 {"pid":15,"cwd":"/w/fff","kind":"interactive","status":"busy",
  "startedAt":$(ms_ago 300),"sessionId":"77777777-0000-0000-0000-00000000000e","name":"row-working"}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"BLOCKED ON YOU"* ]]
}

# The Scenario Outline's four Examples. Every one pins .startedAt to 3 days ago,
# so a mutant that ranks on session age instead of transcript recency marks all
# four stalled and the first two go red.
stall_case() {
  local quiet_secs=$1
  local t
  t="$(transcript_for /w/stall 88888888-0000-0000-0000-00000000000f)"
  cat > "$t" <<EOF
{"type":"attachment","gitBranch":"stall-probe","timestamp":"$(iso_ago "$quiet_secs")"}
EOF
  cat > "$AGENTS" <<EOF
[{"pid":16,"cwd":"/w/stall","kind":"interactive","status":"busy",
  "startedAt":$(ms_ago 259200),"sessionId":"88888888-0000-0000-0000-00000000000f",
  "name":"stall-probe-01"}]
EOF
}

@test "a busy session quiet for 30 seconds is not flagged stalled" {
  stall_case 30
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$(row_for stall-probe-01)" != *stalled* ]]
}

@test "a busy session quiet for 9 minutes is not flagged stalled" {
  stall_case 540
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$(row_for stall-probe-01)" != *stalled* ]]
}

@test "a busy session quiet for 11 minutes is flagged stalled" {
  stall_case 660
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$(row_for stall-probe-01)" == *stalled* ]]
  [[ "$output" == *"10m"* ]]  # the threshold is stated, not implied
}

@test "a busy session quiet for 3 days is flagged stalled" {
  stall_case 259200
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$(row_for stall-probe-01)" == *stalled* ]]
}
