---
name: "linear-process-dreq"
allowed-tools: mcp__linear-server__*, Bash(gh:*), Bash(git:*), Bash(jq:*), Read, Edit, Grep, Glob
description: Process DREQ tickets into a PR that adds domain(s) to the target attributes seed file.
---

# Process Domain Requests (DREQ)

Finds approved domain request tickets on the DREQ board and creates a PR to add the domain(s) to
the production target attributes seed file. Part of the XT Customer Domain Request process.

## Step 1: Find Tickets

**If $ARGUMENTS is provided:** fetch those specific DREQ issue(s) from Linear (e.g., `DREQ-42 DREQ-43`).

**If $ARGUMENTS is empty:** use the Linear MCP tools to list issues on the **DREQ** team filtered by:
- **State**: `Ready for Eng`
- **Label**: `production`

If no tickets are found, inform the user and stop.

List the found tickets and confirm with the user before proceeding.

## Step 2: Parse Domain Info

For each ticket, extract from the title and/or description:
- **Domain** (e.g., `example.com`) — must be a bare domain, not a subdomain or full URL. Normalize by lowercasing and stripping whitespace.
- **Display name** (e.g., `Example`) — the human-readable site name. Capitalize each word (e.g., "amazon" → "Amazon", "best buy" → "Best Buy").

If either is ambiguous, ask the user to clarify.

## Step 3: Check Branch Name

Sort the found tickets by ID (lowest first). Get the branch name from the **lowest-numbered** Linear
ticket (the auto-generated `branchName` field). Check if a branch with that name already exists
locally (`git branch --list`) or on the remote (`git ls-remote --heads origin`). If it does, ask
the user how they want to proceed (e.g., switch to the existing branch, delete and recreate, or
use a different name) **before making any file changes**.

## Step 4: Validate Against Existing Entries

Read `apps/axon/priv/target_attributes/internals.json` and search for each normalized domain from
Step 2. If a domain already exists (look for `domain_last_visited_<domain_underscored>` in `target`
fields), notify the user and skip it. If **all** domains already exist, inform the user and stop.

## Step 5: Edit the Seed File

For each new domain, add an entry to `apps/axon/priv/target_attributes/internals.json` using this
exact pattern (matching existing domain entries):

```json
{
    "category": "Behavior",
    "label": "<Display Name> (<domain.com>)",
    "status": "unpublished",
    "structure": {
      "choices": [
        { "label": "Less than 14 days", "profile_value": "lt_14" },
        { "label": "Less than 30 days", "profile_value": "lt_30" },
        { "label": "Less than 60 days", "profile_value": "lt_60" },
        { "label": "Less than 90 days", "profile_value": "lt_90" },
        { "label": "Over 90 days", "profile_value": "gt_90" }
      ]
    },
    "target": "domain_last_visited_<domain_underscored>",
    "internal_name": "domain_last_visited_<domain_underscored>",
    "internal_use_only": false,
    "type": "single_select",
    "contexts": [
      "intercept"
    ],
    "display_order": 99,
    "prefixable": false,
    "description": "Include participants who last visited <Display Name> (<domain.com>)."
}
```

Where:
- `<Display Name>` = human-readable site name (e.g., "Amazon", "Walmart")
- `<domain.com>` = bare domain (e.g., "amazon.com")
- `<domain_underscored>` = domain with dots replaced by underscores (e.g., "amazon_com")

Insert new entries alphabetically among the existing domain entries (entries whose `target` starts
with `domain_last_visited_`). Maintain valid JSON with proper comma separation.

## Step 6: Validate JSON

Run `jq . apps/axon/priv/target_attributes/internals.json > /dev/null` to verify the file is still
valid JSON after editing. If validation fails, fix the JSON before proceeding.

## Step 7: Update Tests

Adding new domain entries will break hardcoded assertion counts in tests. Run the targeted test
directories to surface failures, fix them, then verify the full suite passes:

1. Run `cd apps/axon && mix test test/axon/recruit test/axon/extended` to find broken assertions.
2. Fix any failing assertion counts by incrementing them by the number of new domains added.
3. Run the full test suite to confirm everything passes.

## Step 8: Create Branch, Commit, and PR

1. **Branch**: Create the branch using the name resolved in Step 3.
2. **Commit**: `Add <domain(s)> to domain target attributes seed [DREQ-<number>]`
3. **PR** via `gh pr create`:
   - Title: include ALL related ticket IDs at the end, e.g., `Add example.com domain target attribute [DREQ-42][DREQ-43]`
   - Body:

```
## Summary
Add <domain(s)> to the domain target attributes seed file.

Linear: <link(s) to DREQ ticket(s)>

## Context
Part of the XT Customer Domain Request process.
After merge and deploy, move the DREQ ticket(s) to **Test** status for David to verify the domain shows up in production.

## Test plan
- [ ] `internals.json` is valid JSON
- [ ] New domain entry matches existing entry format
- [ ] Domain appears in production after deploy + seed run
```

## Step 9: Update Linear

Add a comment on each processed Linear issue with a link to the created PR.
Do **not** change the ticket status — leave it as-is.

## Important Notes

- `status` for new domains is always `"unpublished"` — the seeding process handles publishing.
- Every domain entry uses the same 5 time-based choices shown above.
- All domain entries use `"contexts": ["intercept"]`.
- The seed file is large JSON — be careful to maintain valid structure.
