# Playbook

The [Manifesto](./MANIFESTO.md) is the mindset. This is where the numbers, gates, and mechanics live — the tunable dials. Expect these to change as models and tooling improve; the principles won't, these will.

Engineer-facing unless noted.

---

## Parallelism

- Keep **one active task** holding your focus. Everything else runs in the background.
- Aim for **≥3 background tasks in flight** — investigations, small fixes, prep for future work. This is a rule of thumb (popularized as "3–5 parallel worktrees"), not a quota.
- The ceiling is **your review capacity**, not the tooling — typically ~4–8 before verification becomes the bottleneck. When you can't verify the outputs, stop launching more.
- Good background candidates: cleanup, spikes, research, mechanical refactors, small independent bug fixes. Bad candidates: anything needing heavy specification or deep verification — keep those in the foreground.

## Verification & review

The order is always **cheapest first, human last**:

1. **Deterministic checks** — tests, linters, CI, type checks. Anything with a pass/fail answer.
2. **Self-review** — you are the first human to read your own PR. Always. If you didn't read it, why should the reviewer?
3. **AI review** — automated review pass before another person is involved.
4. **Human review** — the last gate, on what the first three couldn't clear.

Mechanics:
- Most AI review bots only run on **ready** PRs, not drafts. So: self-review → flip draft to ready → AI review → human. Flipping to ready is your signal that *you've* validated it.
- Every workflow / spec must declare its **acceptance criteria** up front — the definition of "done and correct." No criteria, no verification.
- **Give context, proportional to the PR.** Fill the PR template honestly (problem, why-now, plan) — a one-line copy fix needs a sentence; a non-trivial change needs the plan. Show it works: screenshot/GIF/video for visual changes, command or test output for behavior. Evidence lets the reviewer confirm in seconds instead of reverse-engineering intent.
- A reviewer may **bounce a PR back** if there's no self-review or no context — legitimate and non-hostile, and the review clock pauses until it's fixed. This protects reviewer time.

## Small PRs

- Target **~400–600 net added lines**, excluding generated code (lockfiles, schema clients, translation catalogs, dead-code deletion). The bar: a reviewer holds it in ~10–20 min.
- Long-lived feature branches are discouraged — they make a small, reviewable PR impossible. For dependent or unfinished work, use **stacked PRs** or **feature flags**.
- A **feature flag is debt, not a free switch** — whoever adds one owns removing it, as part of the same project. Don't leave flags lying around.
- Merging not-yet-used code is fine **with guardrails**: it's inert or behind a flag, the PR explains the plan, it ships with tests that exercise it, and it belongs to an active project.

## AI-approved merges (when the human is skipped)

Standardize on **one strong AI reviewer**, company-wide, configured with explicit rules. **The rules carry the safety; the AI carries the judgment within them** — standardizing concentrates the single point of failure, so don't trust the verdict, trust the bounds. Auto-merge with no human only when **all** hold:

- **Under the size cap** (~400 net lines, excl. generated) — this gates *reviewability*.
- The AI reviewer **rates it low-risk**.
- It touches **no hard-floor path** (below).
- **No structural tripwire** — doesn't span multiple modules, change a public interface, or touch more than a few files. A human regardless of "low-risk."
- Deterministic checks are green.

**Size gates reviewability, not safety — small does not mean safe. A one-line change can require a human.**

## The hard floor — always a human

These always need a human, no matter how small or how confident the AI:

- **Data migrations** — a bad one is data loss / downtime, not a revert.
- **Sensitive-data egress** — PHI or user data leaving to any third-party sink (analytics, logging, CRM). A miss is a reportable breach.
- **Money** — billing, credits, payment logic.
- **By content, regardless of size:** authorization/permission logic, money-adjacent math, concurrency/async, destructive or bulk data operations. (Judged by *content*, not file path — a typo in an auth file doesn't need a human; auth *logic* does.)

Enforce it mechanically, not by memory — the dangerous PR is the one whose author doesn't realize it touched a floor:
- A path/pattern-based **required-review gate** on sensitive paths → forces a human, overrides AI auto-merge.
- **CODEOWNERS** for routing (it *requests* the owning team; only the required-review rule *blocks*).
- **Sample-audit** a slice of auto-merged PRs to catch a company-wide blind spot or reviewer drift before it bites.

## PR ownership

- **You own your PR end to end** — what goes into it, and when it lands.
- **Approve** is the reviewer's job ("good to go whenever you're ready"); **merge** is the author's ("go — now"). Only the author knows the prerequisites are met (a dependent PR, a flag flip, a migration, a last check).
- **Don't commit to or merge a PR you don't own** — human or AI. Pointing your agent at someone else's branch is the same override, and worse: it collides with the context their own in-flight session holds. Comment freely; push only if invited.
- Exceptions (delegation, not override): the author asks you; the author is unreachable, the PR is approved, and it's blocking others (merge and leave a note — baton passed, not grabbed); an incident (whoever's driving the fix merges).

## Binômes — never solo

- **Never solo on a project. Always ≥2 people context-aware.**
- The second person engages **early** — challenging the approach at kickoff, reviewing the architecture/design — *not* parachuting in at review time. Cold discovery in the PR defeats the purpose.
- The binôme is the **default reviewer** and owns the review SLA for that feature; not exclusive — anyone can review as fallback.
- **Precondition:** this needs protected time for context-sharing. If that isn't committed, don't half-adopt — fall back to plain review + strong PR context. A half-committed binôme is *worse* than none: you keep the SLA cost and lose the warm-context benefit.

## Review SLA

- **Reviewing an open PR outranks starting your next task** — an unreviewed PR blocks a teammate.
- First response within **~2h** during overlapping working hours, for small ready PRs. Not "review in the minute" — a full review takes longer.
- Stay reachable; notifications however you like. The rule is responsiveness, not a specific tool.

## Draft & standby hygiene

- A **draft** means "actively building, not ready for review." Not a backlog item, a saved idea, or a parking lot.
- If work won't progress this week, it doesn't belong as an open draft — move it to a tracked issue. The code isn't lost (it's on the branch); reopen when you resume.
- Ask promptly for approval once ready; don't let approved PRs sit unmerged.
- Nudge stale PRs by who holds the ball: inactive drafts (~5 business days) → nudge the author & close; ready-and-waiting → shorter clock, nudge the reviewer / binôme.

## Tickets

- **Hard gate:** no PR merges without a **linked, categorized ticket**. Enforced mechanically (branch protection / CI), not by goodwill.
- Tickets are **receipts, not orders** — created as the work lands, filed into the right project. `1 ticket = 1 task`.
- **Automate the receipt:** generate the ticket from PR metadata so the gate costs the engineer ~nothing. Enforcement guarantees the record exists; automation guarantees it's honest (a tedious manual gate just produces junk "misc" tickets that poison your data).
- **Categorize** every ticket (e.g. run vs. build) so the measurement is usable.
- How you *plan* below the ticket is yours — Linear, a Claude session, a PR stack. That's personal organization, not team reporting.

## Project forecasting (management)

- Manage at the **project level**, not the task level. Don't refine or slice tickets for engineers.
- Estimate the project roughly. **Smaller projects iterate better** — bias toward small.
- **Re-forecast the release date on a cadence** (every X days). A rolling re-estimate is honest; a percentage-complete is not — tickets vary in size, and scope always grows at the end, so a % manufactures false deadlines.
- Report progress as **milestone state** (defined → in progress → shipped), not as a percentage.
- For status: a real conversation or a look at done-vs-project beats any dashboard number.

## Loop graduation (WAT)

- When you catch yourself doing the same thing twice, graduate it: use an agent to build the deterministic **tool** or **scheduled job**, then remove the agent from the hot path.
- Push every part you *can* to deterministic tools; keep the agent only for the judgment that's left. Mixed agent+tool is fine — the goal is *less* model in the loop, not zero.
- Graduated jobs must stay **observable** and be able to **escalate back to an agent/human** when their assumptions break. A silent broken cron is worse than no automation.
- See [WAT.md](./WAT.md) for the architecture.

## Model selection

**Per task:**
- **Cheap/fast models** for mechanical, high-volume, low-stakes work.
- **Strongest model** for judgment, planning, and verification.
- Using a lot of tokens is not a sign of doing it right — the wrong (expensive) model on a trivial task burns tokens *and* does worse. Match the model to the stakes.

**Where to set it (don't rely on discipline):**
- Bake the model into each **agent's definition** (frontmatter `model:`), so the right one is the default — search/explore agents on a cheap model, reviewer/architect agents on the strongest. Set once, forget.
- Override per-call only for exceptions. If you're routinely typing "use the cheap model for this," the agent's default is wrong — fix the definition.
- The biggest lever is **subagent fan-out**: running 5 parallel grunt-work agents on your top model is pure waste. Cheap model for the fan-out, strong model for the synthesis.

**Org-level billing & backend (ops decision, upstream of everything above):**
- **Seat subscription** (team/enterprise): flat per-seat cost. For heavy users this *is* the token optimization — usage doesn't scale linearly. Optimize inside it with model selection + prompt caching. Don't route around it.
- **Metered API** (pay-per-token): here a router/aggregator can help send trivial work to cheaper models. Only makes sense on metered billing.
- **Routing through a third-party aggregator on top of a seat subscription means paying twice** — the aggregator is metered and bypasses the flat rate you already bought.
- Managed cloud backends (running the models inside your own cloud account) exist mainly for centralized billing, committed spend, and compliance/data-residency — not for cost arbitrage. Prefer officially supported backends over unofficial gateways, which can break tooling features.

## Shared setup

- One shared set of **skills, context, and company knowledge** (via `CLAUDE.md`, a plugin/marketplace, or an internal knowledge base) — so a capability one person builds is one the whole team has.
- Everyone touching AI gets the basic literacy: **skills, MCP, agents, tools.** Not optional.
