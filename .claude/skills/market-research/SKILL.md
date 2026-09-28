---
name: market-research
description: Survey the field Omakase ships into and turn it into roadmap decisions. Use when re-running the M7 competitive pass, checking a claim docs/comparison.md or docs/ROADMAP.md makes about competitors, evaluating a newly found planner, or before any milestone that changes what Omakase claims makes it different. Produces dated documents in docs/research/ and issues on project 11; never edits code.
---

# Market research

The method M7 ran on 2026-09-25, written down so the next pass re-runs it
instead of re-deriving it worse. It is adapted from omatty's M12 skill,
which was adapted from `akitaonrails/ai-memory`'s `docs/`. The difference
is the field. omatty's was open source, so it could read code. Omakase's
is mostly closed SaaS, so the evidence rules below are translated for a
field you mostly cannot read.

**Read `docs/research/2026-landscape.md` first.** It is the previous pass.
A new pass is a follow-up: it says what it follows up and what moved. It
does not start fresh.

## The rules, before the artifacts

1. **Put a capture date in every header**, with the sentence *"every
   load-bearing claim was checked against a live primary page on <date>,
   not remembered."* If you did not open it, do not write it.
2. **Use primary sources only.** These are the vendor's help centre or
   docs, pricing page, changelog, App Store listing, public roadmap or
   voting board, and, for open source, the repository.
   - **Never use a "best X alternatives" or "X vs Y" page.** Most are
     published by a vendor that ranks itself first.
   - Such a page may be cited only as evidence of how a vendor positions
     itself, and labelled that way.
3. **Read the product, not the marketing.** How a feature *works* comes
   from a help page, not a landing page. A claim that rests on a landing
   page says "(marketing page)". For open source (Super Productivity,
   Power Planner, Anki), cite the file path and the commit.
4. **Label vendor numbers.** User counts, "saves N hours" and the like are
   marked *vendor-self-reported*. App Store reviews and Trustpilot are
   *user voice*, never proof of how a feature works.
5. **Keep the separation of powers.** Research documents say "Analysis
   only" and make no decision. Recommendations are numbered `R1..Rn` and
   are inputs. `docs/ROADMAP.md` decides, in the open, after the owner
   accepts or refuses each one.
6. **Delete a claim that cannot name a URL or a file.** That includes
   claims about Omakase, which name a file on `develop`, not a section of
   IDEA.md.
7. **State your coverage honestly.** Say what was sampled and how, what
   would not load, and that a theme missing from a venue is not evidence
   of absence.

**Omakase has three layers, and a claim is never promoted between them:**
- shipped (in the API, or in a client)
- planned (a ROADMAP milestone)
- promised only (an IDEA.md section)

"The API has it" is not "Omakase does it". M7's sharpest finding was that
the backend holds the square nobody else holds and no screen shows it.

## The artifacts

Produce them in this order. Each is one issue and one PR labelled `docs`,
`area:docs` and the pass's milestone, and each is stacked on the one
before. Stopping after any of them still leaves the repository better.

| # | File | Job |
|---|---|---|
| 1 | `docs/research/<year>-landscape.md` §1-3 | Camps, the signal table, a first-party check, and Omakase's own row taken from the code |
| 2 | `docs/research/<product>.md` | Deep dives into the products that really overlap (skeleton below) |
| 3 | `docs/research/issues-<product>.md` and `issues-synthesis.md` | Mining the venues. **This is how features get discovered** |
| 4 | landscape §4-6 | Developments, `R1..Rn` with sizes, what is deliberately not recommended, sources |
| 5 | `docs/research/prior-art-findings.md` | A ledger against the code: what Omakase does, naming the file; P0/P1/P2; Ideas Not To Copy; corrections owed |
| 6 | `docs/research/competitive-parity.md` | The migration bar, the hypotheses tested, the verified moat, "did we copy without improving?", migration verdicts |
| 7 | `docs/comparison.md`, `docs/ROADMAP.md`, the `AGENTS.md` doc map, follow-up issues | Publish and decide |

### Deep-dive skeleton (artifact 2)

1. purpose and target user
2. data model (does it have work *and* study? recurring fixed classes?)
3. planning surface
4. daily ritual
5. focus
6. study features
7. analytics
8. platforms, native or not, offline
9. pricing and student plans
10. integrations
11. **strengths worth borrowing**
12. **weaknesses to avoid**
13. bottom line for a work+study planner
14. sources

### Mining skeleton (artifact 3)

Cover these in order:
1. the venue's character
2. pain points ranked by recurrence, each with its evidence and **the
   design choice that causes it**
3. a table, `| Need | Evidence | Class | Omakase today |`
4. what the maintainers have not solved
5. lessons not to repeat

Class every need:
- **(a)** Omakase's design already answers it. Name where.
- **(b)** Structural to their architecture and impossible in Omakase's.
  Name both causes.
- **(c)** Omakase also lacks it.

M7's audit moved many rows from (b) to (c). A missing feature is not a
structural advantage, so be strict about (b).

**A need that shows up independently in several venues is a different
kind of fact from one that shows up in one.** `issues-synthesis.md` exists
to find those needs. In M7 that meant recurring tasks, a phone app and not
losing data, each in five venues out of five.

## Where the evidence is, for a closed field

| Need | Source |
|---|---|
| Rating, rating count, last release, whether a real Mac build exists | Apple's lookup API: `https://itunes.apple.com/lookup?id=<id>&country=us`. `supportedDevices` containing `MacDesktop` means the purchase includes a Mac build |
| User voice where no board exists | Apple's review feed: `https://itunes.apple.com/us/rss/customerreviews/page=<n>/id=<id>/sortby=mosthelpful/json` (up to 10 pages) |
| Demand, ranked | Public voting boards. Canny boards (Sunsama, Ellie) expose JSON; Featurebase (Structured, Morgen); LaunchNotes (Reclaim). Rank by votes |
| Whether a desktop app is Electron | The vendor's FAQ if it says so; otherwise the app bundle's `Contents/Frameworks/Electron Framework.framework`, or the release archive's contents |
| Open-source trackers | `gh issue list --repo <r> --state all --limit 300 --json number,title,state,comments --jq '... (.comments|length) ...'`, sorted by comment count |

Field size, which counts repositories rather than products:

```bash
gh api "search/repositories?q=topic%3Apomodoro&per_page=1" --jq .total_count
```

The landscape's "Reproducing the table" section has the full commands.

## How M7 ran it, and what that cost

- **Research in parallel, one agent per product.** Each wrote notes with a
  URL on every claim to the scratchpad, never into the repo.
- **Conversion, then an adversarial audit, before any commit.** A
  separate agent tried to delete every claim it could not match to the
  notes or open live.
  - It found 11 problems in the landscape alone: counts that did not add
    up, and a paraphrase presented as a quote.
  - It found two cases where the notes had Omakase's own model wrong:
    `session_rating` is on `TimeBlock`, and `PomodoroSession` has a task
    foreign key only.
  - **Audit claims about Omakase against `git show`, not against the
    notes.**
- **The owner accepted or refused every R-item before ROADMAP changed,**
  and confirmed the follow-up issue list before any `gh issue create`
  loop (AGENTS.md).

## Traps this pass hit

- **Help centres fail.** MyStudyLife's failed a TLS handshake from every
  client, Shovel's and Forest's had certificate errors, and MyStudyLife's
  FAQ worked in the morning and was unreachable by afternoon. Say so in
  the header. A claim read once is not a claim re-verified.
- **Reddit refuses scripted access.** Do not plan on it for user voice.
- **Help centres that render client-side** (TickTick's, Amie's pricing)
  sometimes carry their content as embedded JSON. `curl` reads it where
  WebFetch returns nothing.
- **A rename is not a death.** `johannesjo/super-productivity` moved to
  `super-productivity/super-productivity`. Check the org before
  concluding a project is stale.
- **Check the first party first.** Google gave every personal account
  task time blocks in November 2025, which moved Omakase's first feature
  to the floor. The platforms also move. macOS 27 shipped mid-pass.
- **Writing `#N` in an issue body links this repository's issue N.** A
  competitor's issue number, or a sibling issue referred to as "#1", must
  be a full URL or the real number. M7 had to fix four bodies after
  creating them.
- **New issues are auto-added to project 11,** so `gh project item-add`
  fails with "Content already exists". Check the board; do not retry.

## When to run it

- **At each milestone close-out**, as a diff: re-run the signal table,
  note what moved, and deep-dive only what changed.
- **In full before M6's release**, and before anything claims in public
  what makes Omakase different. That claim has an expiry date, and this
  pass is what checks it.
- **On demand** when a new competitor appears. That is artifact 2 alone.

A second full pass that produces no decision should have been a
signal-table refresh.
