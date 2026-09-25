# Prompt audit — 2026-09-24

Audit of the agent instruction surface for dated patterns, run with
`/claude-api prompt-audit` for #63. Findings are acted on in the same PR,
which replaces `CLAUDE.md` with `AGENTS.md` (the omatty structure).

## Assumptions

- **Scope.** Everything in the repository that reaches a model as text:
  `CLAUDE.md` (365 lines at `develop` 32bb898) and the untracked
  `docs/prompts/frontend-polish.md`. There is no model-calling code: no
  Anthropic or other provider SDK in `backend/requirements*.txt`, no provider
  import in `backend/`. Groups 3 (tool descriptions) and 4 (request config)
  therefore have nothing to audit.
- **Target model.** Claude Opus 5.5, the model Claude Code runs on in this
  repository. Nothing in the repository pins a model; the prompts file names
  Claude Opus 4.7 for a separate product.
- **Out of scope, noted.** The per-user auto-memory under
  `~/.claude/projects/.../memory/` still lists frontend testing gotchas. It is
  not in the repository.

## Provenance

`git blame CLAUDE.md`: 136 lines from 2026-02, 103 from 2026-03, 52 from
2026-04, 57 from 2026-05, 19 from 2026-09. Most of it was written while the
Next.js frontend existed and under the rule at line 361, which asks for a
CLAUDE.md update after every implementation. That rule is the common cause of
most findings below: it turned the instruction file into a record of what was
built.

## Summary

| Group | Findings | Highest |
|---|---|---|
| 1a Pressure language | 2 | Low |
| 1c Over-specification (stale examples) | 2 | High |
| 1d Fossils (unenforced rules, migration phrasing, dead stack) | 7 | High |
| 2 Brittle instruction files | 3 | High |
| 3 Tool descriptions | 0 | - |
| 4 Request config | 0 | - |

The three with the most effect:

1. **Rules that nothing enforces are visibly broken** (findings 2-4). The
   file demands 20-line functions, typed signatures, two levels of nesting, a
   services layer and no server-side `date.today()`. Measured on production
   code, 8 of 79 functions exceed 20 lines (worst 76), 146 annotations are
   missing, cognitive complexity reaches 28, no app has a `services.py`, and
   `tasks/views.py:75` calls `date.today()`. A current model follows
   instructions literally; a file that contradicts the code in front of it
   teaches it that the file is optional. Each rule is either enforced by the
   gate (#66) or reworded to what is true.
2. **The update-after-every-implementation rule** (finding 1) is what filled
   the file with implementation notes. It is rewritten so that rules go in
   `AGENTS.md` and descriptions go in `docs/ARCHITECTURE.md`.
3. **Examples for a deleted stack** (findings 6-7). Commit examples name
   vitest, `uiStore` and `TaskCard`. Examples are the strongest signal in a
   prompt and the model copies their shape.

## Findings

### High

**1. `CLAUDE.md:361`** — *"Always update CLAUDE.md after completing an
implementation or discovering new patterns, gotchas, or learnings"*
- Pattern: Group 2, the recency trap; 1d, patch accretion.
- Why: every session's details became permanent rules. Before #62 the file
  had about 180 `Frontend:` bullets describing components, not constraints.
  The model spends effort reconciling notes that are only history.
- Action: **rewrite** — "When a rule would help most future sessions, write
  it in `AGENTS.md` with its reason. Descriptions of how something works go in
  `docs/ARCHITECTURE.md`."

**2. `CLAUDE.md:310, 314, 316`** — *"Functions: 4-20 lines"*, *"No `any`, no
`Dict`, no untyped functions"*, *"Max 2 levels of indentation"*
- Pattern: 1d, unenforced instructions visibly violated.
- Why: measured on production code, 8 of 79 functions are over 20 lines
  (`stats/views.py` `get` is 76), there are 146 ruff `ANN` findings, and
  complexipy scores `Task.save` and `StudyBlock.save` at 28. omatty enforces
  the same rules with `funlen`, `gocyclo` and `gocognit`, and says so next to
  each rule.
- Action: **rewrite** each rule to name what enforces it and its threshold
  (#66 sets ratchets at the measured worst). The typing rule becomes "new and
  changed functions carry annotations"; enforcing `ANN` repo-wide is a
  separate decision.

**3. `CLAUDE.md:346-348`** — *"all business logic lives inside services …
Business logic goes in `<app>/services.py`"*
- Pattern: 1d, unenforced instructions.
- Why: no app has a `services.py`. `tasks/views.py` holds `reorder_bulk`
  (CC 14, 45 lines) and `stats/views.py` holds the aggregations. The rule
  describes an architecture the code does not have, so it reads as optional.
- Action: **rewrite** as the direction for new and changed code, plus the
  part that can be checked now: views, serializers and models layer in that
  order, enforced by import-linter in #66.

**4. `CLAUDE.md:296`** — *"Never rely on server-side `date.today()` … The
`/tasks/today/?date=` endpoint was added to fix …"*
- Pattern: 1d, an unenforced instruction that is visibly violated.
- Why: `backend/tasks/views.py:75` falls back to `date.today()` when `?date=`
  is missing, which is the bug this line calls fixed (#65).
- Action: **rewrite** as an invariant enforced by ruff `DTZ011`, and fix the
  code (#65).

**5. `CLAUDE.md:14-17, 52-55, 165-174` vs `CLAUDE.md:301`** — commands use
`docker compose`; line 301 says to use `docker-compose` because the spaced
form does not work here.
- Pattern: Group 2, duplicates that disagree (the exception to keep-list
  item 8).
- Why: half the file's commands fail on the machine the other half
  describes.
- Action: **rewrite** to one form, `docker-compose`, through `scripts/gate.sh`
  (#66) where possible.

**6. `CLAUDE.md:201-204`** — commit examples `feat: add vitest config and
test setup`, `test: add uiStore tests`, `test: add TaskCard component tests`.
- Pattern: 1c, example over-indexing; 1d, fossil.
- Why: these are the only worked examples of the commit convention, and all
  of them name code deleted in #62.
- Action: **rewrite** with backend examples in the new `type(#N): message`
  form.

**7. `CLAUDE.md:256, 274`** — domain label `frontend`; *"Testing strategy —
backend (pytest, factories) + frontend (vitest, MSW)"*.
- Pattern: 1d, text that outlived its stack.
- Action: **rewrite**. The label scheme is replaced by omatty's (type +
  milestone + `area:*`); migrating existing issues is a separate decision.

**8. `docs/prompts/frontend-polish.md`** (untracked) — Claude Design prompts
for the Next.js frontend: `localhost:3000`, `pnpm lint`, Tailwind classes,
"powered by Claude Opus 4.7".
- Pattern: Group 2, a pinned model name and history; 1d, fossil.
- Why: every instruction targets code that no longer exists.
- Action: **remove**, or rewrite for the macOS client once its design exists.
  The file is untracked, so this PR does not touch it; the decision is the
  user's.

### Medium

**9. `CLAUDE.md:73-157`** — API endpoint list, "Key Patterns", "Plan ↔ Focus
Mode Sync": about 85 lines of field names, annotations and endpoint shapes.
- Pattern: Group 2, volatile specifics; describing things the code states.
- Why: most lines describe how something works rather than constrain a
  change, and "plan mode" and "focus mode kanban" refer to a client that no
  longer exists. The lines that are real constraints (user scoping in
  `get_queryset`, explicit `.order_by()` after annotation, `basename` when a
  ViewSet has no `queryset`) are worth keeping.
- Action: **move** the descriptions to `docs/ARCHITECTURE.md`; keep the
  constraints in `AGENTS.md` as invariants with their reasons.

**10. `CLAUDE.md:290-292`** — *"`end_time <= start_time` is now caught by
serializer `validate()`"*.
- Pattern: 1d, migration-relative phrasing.
- Why: "now" implies an earlier state the model never saw, and the per-user
  memory still says the opposite ("raises IntegrityError").
- Action: **rewrite** in the present tense.

**11. `CLAUDE.md:184`** — *"pytest with `--cov-fail-under=60`"*.
- Pattern: Group 2, factual claims nobody re-checks.
- Why: `[tool.coverage.run] source` lists three of six apps, so the 60% (and
  the 98.99% it reports) excludes `study` and `stats`. Measured over all
  production code, coverage is 95.4%.
- Action: **rewrite** when #66 lands.

**12. `CLAUDE.md:3, 9`** — *"Productivity app (Notion + Sunsama +
Focusbrew)"*, *"Frontend: none"*.
- Pattern: keep-list item 11, where re-baselining adds text.
- Why: the file no longer says what the backend is for. The next client (a
  native macOS app, then iOS and Android) is the most important context for
  any API decision.
- Action: **add** a product and direction paragraph. The client's specifics
  come from the brainstorm that follows this PR.

### Low (flag, no edit proposed)

**13. `CLAUDE.md:194, 209`** — *"Git Workflow (STRICT)"*, *"**NEVER create PRs
directly to main.**"*
- Pattern: 1a, pressure language.
- Why: it encodes a real policy, so it stays; the capitals carry no reason.
  The new file states it at normal volume with omatty's reason (a promotion
  is a merge commit that records what was released).

**14. `CLAUDE.md:192, 329, 367`** — the regression-test rule appears three
times.
- Pattern: keep-list item 8, working redundancy.
- Why: the three copies agree. The new file says it once, in omatty's
  procedure, and keeps line 367 (use subagents for the fix) because only this
  project asks for that.

**15. `CLAUDE.md:297`** — *"Behavior-change commits MUST update their tests
in the same commit"*.
- Pattern: 1a.
- Why: it carries its reason, so the rule is load-bearing. Only the capitals
  change.

## Applied

This PR applies findings 1-7 and 9-15 by writing `AGENTS.md`,
`docs/ARCHITECTURE.md` and `CHANGELOG.md`, and reducing `CLAUDE.md` to a
pointer. Finding 8 is left for the user because the file is untracked.
Finding 12's product paragraph gets its client specifics after the brainstorm.
Findings 2, 4 and 11 are finished by #65 and #66, which make the rules checks.
