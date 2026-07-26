---
name: savings
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

## Step 3 — Compliance check (do this before trusting any savings number)

`.calibrate/route-log.ndjson` records what the router *nudged* — a directive injected into the conversation, not a guarantee Claude followed it. Never treat a logged nudge as an applied one. Check the session transcripts for actual `calibrate:planner` / `calibrate:coder` / `calibrate:reviewer` / `calibrate:explorer` subagent invocations (Task/Agent tool calls with those subagent types) in the same window as the route log, and compute:

- **Compliance rate**: nudges that resulted in a matching subagent call ÷ total nudges.
- If compliance is 0% or near it, say so plainly and do not report a "policy savings" number — any Sonnet/Opus cost delta in that case is just baseline model pricing, not the policy working. This exact failure mode happened before (route.sh only logged intent and never nudged at all) — don't let a revived nudge mechanism get the same free pass without evidence it's actually being followed.

## Step 4 — Quality check

Check `.calibrate/route-log.ndjson` for escalation events, and scan recent sessions for signals of cheap-tier failure: immediate retries, user corrections right after a routed task, test failures following a coding task. Report the count.

## Step 5 — Report

Output:

1. Spend by model for the period (table).
2. Actual vs all-top-tier baseline, with the delta.
3. Compliance rate (nudged vs. actually delegated) — the number that tells you whether step 2's delta is attributable to the policy at all.
4. Escalations and quality incidents observed.
5. One recommendation: keep the policy, re-run `/calibrate:project` because a phase looks mis-tiered, or — if compliance is low — treat that as the priority fix over any tiering change.

State clearly that dollar figures for subscription (Max/Pro) users represent quota value, not cash.
