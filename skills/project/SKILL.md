---
description: Analyze this repository and write a per-project model routing policy (.claude/model-policy.json) deciding which Claude model tier handles planning, coding, review, and exploration. Use when the user asks to calibrate the project, optimize token spend, or pick models for this repo.
---

# Calibrate this project

Produce an honest, auditable model policy for this repository. The goal is the cheapest tier that is *safe* for each phase of work — not the cheapest tier outright.

## Step 1 — Profile the repository

Gather these signals (use fast tools; do not read whole files):

- **Scale**: rough LOC, number of packages/modules, monorepo or single app.
- **Languages & stack**: compiled vs scripting, frameworks, build complexity.
- **Risk surface**: auth/crypto/payment/infra paths, concurrency or distributed-systems code, public API surface.
- **Safety net**: does the project have tests? CI? Type checking? A strong safety net means cheaper tiers are safer because mistakes get caught.
- **Churn**: recent git history — active hot spots vs stable code.

## Step 2 — Score each phase

Map signals to a tier per phase using this rubric as the starting point, then adjust with judgment:

The tier ladder, cheapest to most capable: `haiku` < `sonnet` < `opus` < `fable`.

| Phase | Default | Raise one tier when | Lower one tier when |
|---|---|---|---|
| plan | one tier above code | architectural/distributed complexity, many cross-cutting concerns | small codebase, well-trodden framework patterns |
| code | sonnet | weak/no tests, tricky concurrency, unfamiliar stack | strong tests + types, mostly boilerplate/CRUD |
| review | sonnet | security-sensitive paths, no CI | small diffs, CI enforces correctness |
| explore | haiku | almost never | — |

**When to recommend `fable`**: it is the tier above opus, built for long-horizon autonomous work — multi-hour migrations, root-cause investigations across a large codebase, architecture overhauls. Recommend it only as the `plan` tier on genuinely high-complexity repos (large monorepo, distributed systems, deep legacy entanglement), or as an escalation action for tasks the user describes as "rework/migrate the whole X". Most projects should NOT have fable in their policy — when complexity made you consider it, say so in the plan rationale (e.g. "opus suffices; fable reserved for the planned v2 migration"). Caveat: on security-research or biology-heavy codebases Fable's safety classifiers frequently reroute requests to Opus, so for those repos put `opus` in the policy directly.

## Greenfield projects (cold start)

If the repo has little or no code (new project, empty directory, just a README), there is nothing to profile — do NOT invent evidence. Switch to interview mode:

1. Ask the user 2-3 short questions: what are they building, with what stack, and whether any part is high-stakes (payments, auth, user data).
2. Write a **provisional** policy from their answers (`"provisional": true`): default to `plan` one tier up (early architecture decisions are cheap in tokens but expensive to get wrong), `code` mid-tier, `explore` cheapest. Rationales cite the user's stated intent instead of repo evidence.
3. Tell the user to re-run `/calibrate:project` once real code exists (first few features merged, or when tests appear) — the provisional flag is the reminder that this policy is intent-based, not evidence-based.

## Step 3 — Write the policy

Write `.claude/model-policy.json` in the project root, following the schema in `${CLAUDE_PLUGIN_ROOT}/policy/schema.json`. Use **tier aliases** (`haiku`, `sonnet`, `opus`, `fable`) so Claude Code resolves each to the current version of that tier; only pin a full model id if the user explicitly asks for version stability. Every phase entry MUST include a one-line `rationale` tied to evidence found in Step 1 — never a generic justification. Include `escalations` rules for the risk paths you actually found (glob patterns), plus two defaults: escalate after repeated test failures, and escalate review for security-sensitive paths. Skip a default when your explicit path rules already cover it — no redundant rules.

If a policy file already exists, read it first and preserve any entries marked `"pinned": true` — those are user overrides.

## Step 4 — Report

Show the user:

1. A short table: phase → model → rationale.
2. The escalation rules in plain English.
3. A rough savings estimate vs running everything on the top tier. State it as a relative estimate based on current per-token pricing (check current Claude pricing rather than assuming; do not present it as a guarantee).
4. One sentence on what would change the calibration (e.g. "if you add tests, code drops a tier").

Do not change any Claude Code settings in this skill. The policy file is the only output; routing happens via the plugin's agents and hooks.
