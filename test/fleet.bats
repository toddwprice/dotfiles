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

@test "a sibling transcript in the same project dir is not read into the row" {
  # The script reads only the file named by .sessionId. Its own comment warns
  # that a project dir holds 10+ transcripts and globbing it reads the wrong
  # session — but nothing pinned that until this fixture put a second session in
  # the same dir. The sibling is deliberately the more recent of the two, so a
  # glob mutant loses the branch, the PR and the quiet column all at once.
  local t other
  t="$(transcript_for /w/glob-probe abcdef00-0000-0000-0000-000000000011)"
  cat > "$t" <<EOF
{"type":"attachment","gitBranch":"glob-probe-mine","timestamp":"$(iso_ago 120)"}
{"type":"pr-link","prNumber":11111,"timestamp":"$(iso_ago 115)"}
EOF
  other="$(transcript_for /w/glob-probe abcdef00-0000-0000-0000-000000000012)"
  cat > "$other" <<EOF
{"type":"attachment","gitBranch":"glob-probe-not-mine","timestamp":"$(iso_ago 10)"}
{"type":"pr-link","prNumber":99999,"timestamp":"$(iso_ago 5)"}
EOF
  cat > "$AGENTS" <<EOF
[{"pid":18,"cwd":"/w/glob-probe","kind":"interactive","status":"busy",
  "startedAt":$(ms_ago 300),"sessionId":"abcdef00-0000-0000-0000-000000000011",
  "name":"glob-probe-01"}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"glob-probe-mine"* ]]
  [[ "$output" == *"11111"* ]]
  [[ "$output" != *"glob-probe-not-mine"* ]]
  [[ "$output" != *"99999"* ]]
}

@test "records at the head of a long transcript are still read" {
  # The script reads the whole file, not a tail: pr-link and gitBranch records
  # appear anywhere in it. A `tail -n 200` mutant survives any fixture shorter
  # than 200 lines, so what a small fixture pins is only "a tail smaller than
  # this file" — not the rule. Here the branch and both pr-links sit at the
  # head with 250 lines after them.
  local t ts i
  t="$(transcript_for /w/tail-probe abcdef00-0000-0000-0000-000000000013)"
  ts="$(iso_ago 60)"
  {
    printf '{"type":"attachment","gitBranch":"tail-probe-branch","timestamp":"%s"}\n' "$(iso_ago 600)"
    printf '{"type":"pr-link","prNumber":22222,"timestamp":"%s"}\n' "$(iso_ago 599)"
    printf '{"type":"pr-link","prNumber":33333,"timestamp":"%s"}\n' "$(iso_ago 598)"
    for (( i = 0; i < 250; i++ )); do
      printf '{"type":"user","timestamp":"%s"}\n' "$ts"
    done
  } > "$t"
  [ "$(wc -l < "$t")" -gt 200 ]
  cat > "$AGENTS" <<EOF
[{"pid":19,"cwd":"/w/tail-probe","kind":"interactive","status":"busy",
  "startedAt":$(ms_ago 300),"sessionId":"abcdef00-0000-0000-0000-000000000013",
  "name":"tail-probe-01"}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tail-probe-branch"* ]]
  [[ "$output" == *"33333"* ]]
  [[ "$output" != *"22222"* ]]
  [[ "$output" != *"branch unavailable"* ]]
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

@test "a transcript that reads but doesn't parse marks its cells unavailable, not 'no PR'" {
  # Readable is not parseable. /todd:fleet.md promises `unavailable` means the
  # transcript was missing OR unparseable, and `no PR` is a claim about a
  # transcript that was never actually read. Keeping the row is INV-2; the cells
  # are what degrade.
  local t
  t="$(transcript_for /w/frg-1300 abcdef00-0000-0000-0000-000000000010)"
  printf 'this is not json\nneither is this\n' > "$t"
  cat > "$AGENTS" <<EOF
[{"pid":17,"cwd":"/w/frg-1300","kind":"interactive","status":"busy",
  "startedAt":$(ms_ago 300),"sessionId":"abcdef00-0000-0000-0000-000000000010",
  "name":"frg-1300-3b"}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"frg-1300-3b"* ]]
  [[ "$output" == *"branch unavailable"* ]]
  [[ "$output" == *"PR unavailable"* ]]
  [[ "$output" != *"no PR"* ]]
  run "$SCRIPT" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r 'length' <<<"$output")" -eq 1 ]
  [ "$(jq -r '.[0].transcript' <<<"$output")" = "unavailable" ]
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

@test "--json against an unreadable source exits non-zero rather than reading as an empty fleet" {
  # The human surface keeps exit 0 (test above) because it has prose to degrade
  # into. --json has none: with empty stdout and exit 0, `fleet --json | jq
  # length` yields nothing and a consumer reads it as a fleet with nothing in
  # it. Stdout must stay empty rather than become `[]`, so the exit code is the
  # only signal available.
  printf 'this is not json at all\n' > "$AGENTS"
  run bash -c '"$1" --json 2>/dev/null' _ "$SCRIPT"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  # The message still goes to stderr, for whoever is relaying it.
  run "$SCRIPT" --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"could not read the session list"* ]]
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

@test "a nameless row and a sessionId-less row both render, and the header counts what printed" {
  # Both are the INV-2 case: a row whose transcript can't be found still prints,
  # with the columns it fed marked. Dropping either one left the heading
  # counting a session it never printed — and dropping the sessionId-less one
  # made --json emit the `[]` that must never appear.
  cat > "$AGENTS" <<EOF
[{"pid":20,"cwd":"/Users/toddprice/dscout-wt/frg-1249","kind":"interactive",
  "status":"waiting","waitingFor":"input needed","startedAt":$(ms_ago 300),
  "sessionId":"abcdef00-0000-0000-0000-000000000014"},
 {"pid":21,"cwd":"/Users/toddprice/dscout-wt/frg-1250","kind":"interactive",
  "status":"waiting","waitingFor":"input needed","startedAt":$(ms_ago 300)}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BLOCKED ON YOU (2)"* ]]
  # The name column falls back to the ticket id rather than leaving the row out.
  [[ "$(row_for FRG-1249)" =~ ^[[:space:]]*waiting[[:space:]] ]]
  [[ "$(row_for FRG-1250)" =~ ^[[:space:]]*waiting[[:space:]] ]]
  # The heading's count equals the rows actually printed: each row carries its
  # own `<- input needed` note, and the footer legend carries none.
  [ "$(grep -c 'input needed' <<<"$output")" -eq 2 ]
  run "$SCRIPT" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r 'length' <<<"$output")" -eq 2 ]
  # A fallback is reported as a fallback: the raw name stays null either way.
  [ "$(jq -r '[.[] | select(.name == null)] | length' <<<"$output")" -eq 2 ]
  [ "$(jq -r '.[0].displayName' <<<"$output")" = "FRG-1249" ]
  [ "$(jq -r '[.[] | select(.sessionId == null)] | length' <<<"$output")" -eq 1 ]
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

@test "an interactive row's own status wins over a state the payload shouldn't carry" {
  # INV-1: .status is read for every row, .state only for a background one. Two
  # guards enforce it — the jq extraction blanks .state for anything
  # interactive, and the case that picks the effective state prefers .status for
  # it — and each masks the other, so both were removable with the suite green.
  # A row carrying a status and a contradicting state is what tells them apart:
  # with the guards gone, `interactive:done` matches no allowlist entry and this
  # row lands in UNKNOWN STATE instead of BLOCKED ON YOU.
  cat > "$AGENTS" <<EOF
[{"pid":22,"cwd":"/w/inv1","kind":"interactive","status":"waiting","state":"done",
  "waitingFor":"input needed","startedAt":$(ms_ago 300),
  "sessionId":"abcdef00-0000-0000-0000-000000000015","name":"inv1-probe-01"}]
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"BLOCKED ON YOU"* ]]
  [[ "$output" != *"UNKNOWN STATE"* ]]
  [[ "$(row_for inv1-probe-01)" =~ ^[[:space:]]*waiting[[:space:]] ]]
  run "$SCRIPT" --json
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[0].bucket' <<<"$output")" -eq 0 ]
  [ "$(jq -r '.[0].displayState' <<<"$output")" = "waiting" ]
  # Not merely deprioritized — an interactive row's .state is never read at all.
  [ "$(jq -r '.[0].state' <<<"$output")" = "null" ]
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

# Both not-stalled cases assert the quiet column as well as the absent marker.
# `row_for` prints nothing when the row isn't there, and an empty string does not
# contain "stalled" — so the marker assertion alone passes just as happily on a
# row that vanished, which is the one outcome this whole tool exists to prevent.
# The seconds are matched as a range: the fixture timestamp is written a moment
# before the script reads the clock, so a tick between the two renders 31s.
@test "a busy session quiet for 30 seconds is not flagged stalled" {
  stall_case 30
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local row
  row="$(row_for stall-probe-01)"
  [[ "$row" =~ quiet\ 3[0-9]s ]]
  [[ "$row" != *stalled* ]]
}

@test "a busy session quiet for 9 minutes is not flagged stalled" {
  stall_case 540
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  local row
  row="$(row_for stall-probe-01)"
  [[ "$row" == *"quiet 9m"* ]]
  [[ "$row" != *stalled* ]]
}

@test "a busy session quiet for 11 minutes is flagged stalled" {
  stall_case 660
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$(row_for stall-probe-01)" == *stalled* ]]
}

@test "a busy session quiet for 3 days is flagged stalled" {
  stall_case 259200
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$(row_for stall-probe-01)" == *stalled* ]]
}
