---
description: Report token spend for this project and estimate savings achieved by the model policy versus an all-top-tier baseline. Use when the user asks how many tokens the policy saved, for a spend report, or to verify calibration is working.
---

# Savings report

Prove (or disprove) that the policy is paying off. Be honest — if the policy saved nothing, say so.

## Step 1 — Collect usage

Claude Code writes session transcripts as JSONL under `~/.claude/projects/<encoded-project-path>/`. Computing **actual** dollar figures requires read access to that directory — which is *outside the project root*, so a sandboxed or restricted session cannot reach it. If you cannot read `~/.claude/projects/`, skip to "Degraded mode" below; do not invent token counts.

Try the community tool first (it reads the same transcripts):

```bash
npx -y ccusage@latest daily --json    # bare `--json` without a subcommand prints nothing
```

and filter to this project. If `ccusage` is unavailable, parse the JSONL directly: sum `usage` blocks (`input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`) grouped by `message.model`.

**Degraded mode** (transcripts unreadable and ccusage absent): you can still produce a useful report from `.calibrate/route-log.ndjson` (tier decisions) and the policy file (per-phase tiers). Report *theoretical* per-phase savings vs all-top-tier, clearly labelled as theoretical, and tell the user to either install ccusage or re-run this skill from the main interactive session (which has transcript access) to get actual dollars. Never present theoretical numbers as measured.

## Step 2 — Compute the comparison

- **Actual**: tokens × current per-token price for each model actually used. Look up current Claude pricing rather than assuming remembered prices.
- **Baseline**: the same token volumes priced as if every request ran on the project's top-tier model (the policy's `plan` model, or Opus if unset).
- **Delta**: baseline − actual, in dollars and as a percentage.

## Step 3 — Quality check

Savings are meaningless if quality dropped. Check `.calibrate/route-log.ndjson` (if present) for escalation events, and scan recent sessions for signals of cheap-tier failure: immediate retries, user corrections right after a routed task, test failures following a coding task. Report the count.

## Step 4 — Report

Output:

1. Spend by model for the period (table).
2. Actual vs all-top-tier baseline, with the delta.
3. Escalations and quality incidents observed.
4. One recommendation: keep the policy, or re-run `/calibrate:project` because the data suggests a phase is mis-tiered (e.g. frequent escalations in `code` → raise its default).

State clearly that dollar figures for subscription (Max/Pro) users represent quota value, not cash.
