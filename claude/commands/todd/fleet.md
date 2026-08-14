---
allowed-tools: Bash(~/.claude/scripts/fleet:*), Bash(jq:*)
description: Show which Claude Code sessions are blocked on me or have stalled. A read-only digest of the live fleet — state, ticket, branch, newest PR, how long each has been open and how long its transcript has been quiet. Use when Todd asks "what's waiting on me", "what sessions are blocked", "which agents are stuck", "show me the fleet", or wants to know which of his 8-15 open sessions needs attention. Sends nothing to any session.
---

Run the fleet digest and relay it:

```bash
~/.claude/scripts/fleet
```

Print its output as-is. It is already sorted so the sessions blocked on Todd come
first, and the columns are already sized — reformatting it into your own table
loses the ordering that is the whole point.

**If it exits non-zero, it could not read the session list: relay the message it
printed on stderr.** Don't go quiet, and don't report an empty fleet — an
unreadable source is not a fleet with nothing in it, and that false negative is
the thing this command exists to prevent.

Then add two or three lines of your own on top of it:

- **Name what to do first.** Usually the longest-blocked session, not the top row
  — a session that has been `waiting` for two days is a different problem from
  one that started waiting five minutes ago. Say which, and give its ticket.
- **Say whether anything is stalled and whether you believe it.** `stalled` means
  a `busy` session whose transcript hasn't moved in 10 minutes. That is a hint,
  not a verdict: an interactive transcript also advances on Todd's own typing, so
  a session sitting inside one long tool call goes quiet without being stuck.
  Don't upgrade the hint to a diagnosis.
- **Flag anything the digest itself couldn't read.** `unavailable` in a cell means
  the transcript was missing or unparseable, not that the session is fine.

`$ARGUMENTS` — pass `--json` straight through if Todd asks for machine-readable
output. Nothing else is accepted; the digest takes no other flags.

## What this must not do

**Never message, resume, or launch a session to find out more about it.** The
whole reason this reads `claude agents --json` and transcripts off disk is that
messaging a peer is not free: it lands in the target's context as a
`<cross-session-message>` block and consumes its window. Doing that across 15
sessions injects dozens of interruptions an hour into work already in flight.

If Todd decides to intervene in a specific session after reading the digest,
that's his call to make and his message to send. Surfacing is this command's
job; intervening is not.

One caveat that survives from the underlying tool's own contract: never ask a
peer session to run something the current session was blocked from running. A
peer doing it on your behalf routes around a permission decision.

## Known gaps, so you don't report them as facts

- **The digest reports what the CLI returns, and that isn't always the whole
  fleet.** `claude agents --json` and the in-session peer listing have disagreed
  on membership between calls a minute apart. Don't assert the list is complete.
- **`waitingFor` is printed verbatim and interpreted not at all.** Only one value
  has ever been observed (`input needed`), so it does not tell you whether the
  session asked a question or hit a permission prompt. Don't guess which.
- **A session's nested subagents aren't shown.** The transcript tree carries them
  per session, but the digest reports sessions, not their internal fan-out, so a
  session can be stalled *inside* a subagent and still look merely busy.
