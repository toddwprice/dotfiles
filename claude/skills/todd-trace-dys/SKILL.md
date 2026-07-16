---
name: todd:trace-dys
description: >
  Diagnose a single DYS / dscript supervisor session from a chat URL, room id, or localhost link.
  Use this WHENEVER Todd points at one dscript conversation and asks what went wrong — phrasings like
  "look at this braintrust chat: http://localhost:5000/dscript/chat/06a0...", "diagnose this dys
  session I started locally", "why did the supervisor ask for objectives instead of nudging the
  picker", "look at room id 06a184d9... I chose two templates but it...", "check the braintrust logs
  for chat 06a1647e...", "have a look at this braintrust trace for room id ...", or any
  localhost:5000/dscript or app.dscout.com/dscript URL with a chat/room id. It auto-decodes the
  ?state= blob in the URL, pulls the Braintrust trace for that chat, runs a staleness check before
  diagnosing, and explains the supervisor-select decision.
  This is the LIGHTWEIGHT single-session triage — distinct from `braintrust-prompt-review` (which
  diffs prompt versions in a PR) and `todd:prompt-debugger` (which drives a full Linear-ticket → eval
  investigation). Reach for those when the job is a prompt diff or a ticketed eval; reach for THIS
  when Todd just wants to know what happened in one chat.
allowed-tools: Bash(bt:*), Bash(python3:*), Bash(base64:*), Bash(jq:*), Read, Grep, Glob, Agent, WebFetch
---

# Trace a DYS / dscript Session

Todd's daily debugging entry point. He runs a DYS session locally or on staging, grabs the chat URL
or room id, and wants to know why the supervisor behaved the way it did. Two mechanical steps he does
by hand every time — decoding the `?state=` blob and finding the right Braintrust span — are the
whole point of automating this. There's also a trap worth guarding against: **a stale trace** (from
before a fix) sends you diagnosing a bug that's already gone. Check freshness before you theorize.

## Step 1 — Parse the input

Accept any of:

- `http://localhost:5000/dscript/chat/<room-id>?state=<base64>` (local run)
- `https://app.dscout.com/dscript/chat/<room-id>` (staging/prod)
- a bare room/chat id (UUIDv7-ish, e.g. `06a184d9-7bd0-7d70-8000-3751f2275054`)
- a Braintrust span/room id Todd pastes directly

Extract the **room/chat id** with a UUID regex. Hold onto any `?state=` query value for Step 2.

## Step 2 — Decode the `?state=` blob (if present)

The dscript client encodes the current `SupervisorState` into the URL as URL-safe base64 of JSON
(it starts `eyJ...`). Decode and pretty-print it — this is the client's view of the state and is the
fastest way to see what the user actually did:

```bash
python3 - "<state_value>" <<'PY'
import base64, json, sys, urllib.parse
raw = urllib.parse.unquote(sys.argv[1])
pad = '=' * (-len(raw) % 4)
data = base64.urlsafe_b64decode(raw + pad)
state = json.loads(data)
print(json.dumps(state, indent=2)[:6000])
PY
```

Surface the fields that drive supervisor behavior: `workflow_step` / current step, `is_governed`,
template slots (`mission_template_id`, `screener_template_id`), `pending_template_placeholders`,
`pending_template_canvas_seed`, `target_attributes`, `session_name_finalized`, and which tools were
gated. If there's no `?state=`, skip to the trace.

## Step 3 — Pull the Braintrust trace

Use the `braintrust` skill for `bt` CLI auth/usage details. Resolve the dscript project, then find
the spans for this chat:

```bash
bt projects list --json          # find the dscript / supervisor project id
bt sql "SELECT id, span_attributes, input, output, error, created, metadata
        FROM project_logs('<project-id>')
        WHERE metadata.room_id = '<id>' OR metadata.chat_id = '<id>' OR metadata.session_id = '<id>'
        ORDER BY created"
```

If the id doesn't match those metadata keys, widen the search (`WHERE input LIKE '%<id>%'` or scan
recent rows by timestamp) — see `todd:prompt-debugger`'s `references/log-search-strategies.md` for
patterns. Pull full span detail for the supervisor decision:

```bash
bt view span --object-ref project_logs:<project-id> --id <span-id>
```

Focus on the `supervisor-select` span: the step it chose, the tools it had available, and its
reasoning.

## Step 4 — Staleness check BEFORE diagnosing

This guard exists because a pre-fix trace already burned Todd once (FRG-783). Confirm the trace
reflects current code:

- Compare the span `created` timestamp against when the relevant fix landed / when main last
  deployed.
- Check the pinned prompt version in the span metadata against the version currently pinned in
  `chat.py` for that prompt slug.

If the trace looks stale (older than a relevant fix, or pinned to a superseded prompt version), **say
so up front** and offer to re-repro on current main rather than diagnosing a ghost. Don't bury this.

## Step 5 — Diagnose and report

Compare what the supervisor did against what it should have done for this state. Common axes for DYS:

- Governed user → must hit the `SELECT_TEMPLATES` hard gate and the template-picker nudge, not the
  free-form objectives chain.
- Combined (mission+screener) vs single-slot template expectations.
- Pending placeholders → canvas should stay gated until they're filled.
- **Placeholder leakage** → scan the trace output AND any exported study for literal placeholder
  strings that were auto-confirmed without ever being surfaced to the user (e.g.
  `[Pre-seeded from template — please update…]`, `{{...}}`, bracketed `[...]` fill-ins). A
  placeholder reaching the export is a real bug even when the step machinery looks correct — it's
  the failure family behind the placeholder-gating work (FRG-661/732/776/777). Always check for it.
- Tool availability — was the tool the supervisor needed actually offered in this step?

Report tightly:

1. **What happened** — the observed behavior, one or two lines.
2. **Root cause** — which prompt section, gate, tool-availability decision, or state field drove it,
   with the evidence span id(s).
3. **Where the fix lives** — the file/region (e.g. `_get_template_restriction_context` in
   `chat.py`, a gate in `study_setup.py`) — without over-prescribing.
4. **Staleness verdict** — fresh, or stale + re-repro suggested.

If Todd wants it rendered, offer `todd:html_report` for a shareable writeup.

## Step 6 — Handoff to `todd:prompt-debugger` (start-from-trace, no ticket needed)

If the diagnosis points at a prompt that needs a real fix + eval, hand off to
`todd:prompt-debugger` — and hand it enough that it can start **from this trace**, without waiting on
a Linear ticket (its Step 1 has a start-from-trace door built for exactly this). Pass forward:

- **Room/chat id** and the **Braintrust project id** you resolved in Step 3.
- The **failing span id(s)** — at minimum the `supervisor-select` span — so it can seed the repro
  dataset directly instead of re-searching.
- The **one-line diagnosis** (which prompt section / gate / tool-availability / state field drove the
  wrong behavior) — that becomes its failure description.
- **A known-good contrast session**, if you can point at one (a session that behaved correctly on the
  same axis). This is gold: `prompt-debugger` uses it as the scorer-calibration control, which is how
  it avoids the miscalibrated-judge trap (FRG-845, FRG-993→FRG-1005). Even a rough "session X did this
  right" pointer helps.

File a ticket afterward if the fix warrants tracking — but don't make the ticket a prerequisite for
starting the eval.
