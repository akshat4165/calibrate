# calibrate

**Your Claude Code learns each project's cheapest *safe* model policy — and proves the savings.**

Heavy Claude users burn tokens guessing which model to use: Opus to plan? Sonnet to code? Haiku to review? The right answer depends on the project — its size, risk surface, and test coverage. `calibrate` has Claude analyze the repo once, write an auditable per-project routing policy, route phase work through it, and report measured savings versus running everything on the top tier.

## It reasons per project, not from a template

Calibrate two different repos and you get two different policies — because the analysis is grounded in each repo's actual risk and safety net. Real output from two projects:

| Phase | A security-sensitive Next.js app | A standard Python FastAPI + RAG backend |
|---|---|---|
| **plan** | **opus** — subtle partner-sync + Firestore-rules security, no tests to catch a bad design | **sonnet** — standard patterns, no architectural complexity worth Opus |
| **code** | sonnet — strong types + `next build` catch errors | sonnet — zero tests, so not cheaper than this |
| **review** | sonnet, escalates to opus on `auth/**`, `partner/**`, `firestore.rules` | sonnet, escalates to opus on `main.py`, `rag.py`, `ingest/**`, `config.py` |
| **explore** | haiku | haiku |

The planning tier dropped from **Opus to Sonnet** on the simpler project — that's the whole idea: Claude already knows how hard a project is, so let it decide.

## Measured savings

On a **verified** end-to-end run in the Next.js app — routing checked against the session logs, not the model's self-report — the policy cost **$1.48 vs $2.78 all-Opus: 46.8% saved**. That run *deliberately* touched security-sensitive code, so 3 of 4 agents escalated to Opus; a task that doesn't hit flagged paths keeps code+review on Sonnet and saves more. So ~47% is roughly the floor, on a worst-case task. (Dollar figures are subscription quota-value, not cash.)

> Honest caveat: that's a single verified data point so far. The second project's savings are estimated (50–65%) pending its own measured run. Calibrate reports *theoretical* numbers as theoretical and *measured* numbers as measured — never the two confused.

## How it works

1. **`/calibrate:project`** — Claude profiles the repo (scale, stack, risk paths, test/CI safety net; interviews you instead if the repo is empty) and writes `.claude/model-policy.json`: a model tier per phase, each with a one-line evidence-based rationale, plus escalation rules for risky paths and repeated failures. Tier aliases (`haiku`/`sonnet`/`opus`/`fable`) auto-upgrade as Anthropic ships new model versions.
2. **Phase agents** — `planner`, `coder`, `reviewer`, `explorer` subagents run on the policy's model for their phase, escalating when a diff touches a flagged path. Switching happens at subagent and session boundaries, never mid-conversation — so the prompt cache survives.
3. **`/calibrate:savings`** — parses your local usage logs, compares actual spend against an all-top-tier baseline, and reports the delta alongside quality incidents (escalations, retries, test failures) so savings claims stay honest.

## Install

```
/plugin marketplace add akshat4165/calibrate
/plugin install calibrate@calibrate
```

For development: `claude --plugin-dir ./calibrate`. Then, inside any project: `/calibrate:project`.

## What's proven vs. what's next

Honest status — this is early:

- [x] **Routing works**, verified against session logs across two projects (TypeScript + Python)
- [x] **Per-project reasoning**, demonstrated (the plan-tier contrast above)
- [x] **Published & installable** from this marketplace; `claude plugin validate` passes
- [x] **One measured savings run** (46.8%, verified)
- [x] **Phase-0 question answered** — a hook can't switch the *main* conversation's model mid-session, but `.claude/settings.json` cleanly sets what each *new* session starts on (see [anthropics/claude-code#43326](https://github.com/anthropics/claude-code/issues/43326))
- [ ] **More measured runs** across more languages before claiming a headline savings number
- [ ] **Phase 2 — the learning loop**: auto-adjust the policy from observed escalations, retries, and test failures (the durable moat; not built yet)
- [ ] **Community marketplace** submission

Known rough edges: `/calibrate:savings` needs read access to `~/.claude/projects/` (or `ccusage`) to compute actual dollars — a restricted session falls back to theoretical-only. Creating `.claude/` in a fresh repo prompts for permission once.

## Repository layout

```
calibrate/
├── .claude-plugin/
│   ├── plugin.json              # manifest
│   └── marketplace.json         # marketplace catalog
├── skills/
│   ├── project/SKILL.md         # /calibrate:project — analyze repo, write policy
│   └── savings/SKILL.md         # /calibrate:savings — spend report vs baseline
├── agents/                      # planner / coder / reviewer / explorer
├── policy/
│   ├── schema.json              # model-policy.json schema
│   └── example.model-policy.json
└── hooks/
    ├── hooks.json               # UserPromptSubmit → route.sh
    └── route.sh                 # log-only tier classifier (classifier-accuracy data)
```

## Design principles

- **Calibration over routing.** Per-prompt difficulty routers are a commodity (and the big vendors ship them natively). The durable value is a per-project policy learned from evidence, with receipts.
- **Auditable, never magic.** Every tier choice carries a rationale; pin any phase with `"pinned": true` and re-calibration respects it.
- **Honest accounting.** Savings reports include quality incidents and label theoretical vs. measured. If the policy saved nothing, the report says so.
- **Switch at boundaries.** Model switches happen at subagent and session boundaries, not mid-conversation, to preserve the prompt cache.

## License

MIT
