# calibrate

**Your Claude Code learns each project's cheapest safe model policy — and proves the savings.**

Heavy Claude users burn tokens guessing which model to use: Opus to plan? Sonnet to code? Haiku to review? The right answer depends on the project — its size, risk surface, and test coverage. `calibrate` has Claude analyze the repo once, write an auditable per-project routing policy, route phase work through it, and report measured savings versus running everything on the top tier.

## How it works

1. **`/calibrate:project`** — Claude profiles the repo (scale, stack, risk paths, test/CI safety net) and writes `.claude/model-policy.json`: a model tier per phase (plan / code / review / explore), each with a one-line evidence-based rationale, plus escalation rules for risky paths and repeated failures.
2. **Phase agents** — `planner`, `coder`, `reviewer`, and `explorer` subagents run on the policy's model for their phase, with escalation when a diff touches flagged paths.
3. **`/calibrate:savings`** — parses your local usage logs, compares actual spend against an all-top-tier baseline, and reports the delta alongside quality incidents (escalations, retries, test failures) so savings claims stay honest.

## Install

From a marketplace (once published):

```
/plugin marketplace add <owner>/<repo>
/plugin install calibrate@<marketplace>
```

For development:

```bash
claude --plugin-dir ./calibrate
```

Then, inside any project:

```
/calibrate:project
```

## Repository layout

```
calibrate/
├── .claude-plugin/plugin.json   # manifest
├── skills/
│   ├── project/SKILL.md         # /calibrate:project — analyze repo, write policy
│   └── savings/SKILL.md         # /calibrate:savings — spend report vs baseline
├── agents/                      # planner / coder / reviewer / explorer
├── policy/
│   ├── schema.json              # model-policy.json schema
│   └── example.model-policy.json
└── hooks/
    ├── hooks.json               # UserPromptSubmit → route.sh
    └── route.sh                 # Phase-0 spike: log-only tier classifier
```

## Status / roadmap

- [x] Phase 1 — policy format, `/calibrate:project`, phase agents
- [ ] Phase 0 spike — verify whether a hook-driven settings rewrite can switch the main-thread model mid-session (`CALIBRATE_SPIKE_SWITCH=1`, see [anthropics/claude-code#43326](https://github.com/anthropics/claude-code/issues/43326)); if not, routing stays at subagent/session boundaries — which also preserves prompt cache
- [ ] Phase 2 — feedback loop: adjust policy from observed escalations, retries, and test failures
- [ ] Phase 3 — publish to a GitHub marketplace, then submit to the Claude community marketplace

## Design principles

- **Calibration over routing.** Per-prompt difficulty routers are commodity (and the big vendors will ship them natively). The durable value is a per-project policy learned from evidence, with receipts.
- **Auditable, never magic.** Every tier choice carries a rationale; users can pin any phase (`"pinned": true`) and re-calibration respects it.
- **Honest accounting.** Savings reports include quality incidents. If the policy saved nothing, the report says so.
- **Switch at boundaries.** Model switches happen at subagent and session boundaries, not mid-conversation, to avoid destroying prompt cache.

## License

MIT
