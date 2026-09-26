# The field Omakase ships into, September 2026 - inventory

> Captured **2026-09-25**, against `develop` at `51abb80` (M0 and M1 merged).
> Every load-bearing claim below was checked against a live primary page on
> that date, not remembered. App Store figures come from Apple's lookup API
> (`https://itunes.apple.com/lookup?id=<id>&country=us`, the US storefront,
> iPhone listing unless marked), repository figures from the GitHub API. The
> commands are in "Reproducing the table".
>
> **Analysis only.** No implementation decision is made in this file, and no
> recommendation binds the roadmap. What Omakase should *do* about any of it
> is decided in `docs/ROADMAP.md`, in the open (#105).

## Why this document exists

Omakase makes one claim about its competition, and until this file existed
the repository could not support it. `docs/IDEA.md` says the product is
built around "two top-level organizational structures that share the same
time resource": work and study, on one calendar, worked in pomodoro
sessions, closed out in a daily review. That is only a product if nobody
else already does it, and the repository's entire record of the field was
"Sunsama-style" and "Notion-style" in `docs/design-system.md`.

M3 to M5 are about to be built from IDEA.md's nineteen feature sections. This file
names the field those milestones ship into, so that #105's later artifacts
can say which of those sections are table stakes, which are open ground,
and which are not worth building.

The target user for this pass is global: a student who also works, or a
learner with a job. Brazil's exam-prep platforms, which IDEA.md's Exam Prep
Mode points at, are out of scope for this pass.

### What is not a source

Searching for any product here returns, above the vendor's own pages, a
layer of "best Sunsama alternatives" and "Motion vs Reclaim" posts, most of
them published by a vendor that ranks itself first. They are not sources.
One is cited below (a claim that iStudiez shut down) and it is labelled
positioning evidence, because no primary page confirms it.

Primary sources only: the vendor's help centre or docs, pricing page,
changelog, App Store listing, public roadmap or feedback board, and, for
open source, the repository. How a feature *works* is taken from a help
page, not a landing page; a claim that rests on a landing page says so.

### Coverage

Twenty-four products and the three first-party platforms were checked
against the columns below; eight more were noted as candidates without a
full check, one of them (Helium) with repository figures only. Five are read in depth in their own files (#107). Some doors were shut: MyStudyLife's help centre failed a TLS
handshake from every client tried, Shovel's and Forest's help centres have
certificate errors, Vaia's pricing page is a 404, and Reddit refused
scripted access, so no Reddit user voice appears anywhere in this pass.
Mac UI frameworks are recorded only where the vendor states one or the
bundle was inspected. "Not documented" means no primary page said, not
that the feature is absent.

## 1. The camps

Seven of them. The first four compete with Omakase for the same planning
hour; the last three shape what its user already expects.

**A. Daily-planning rituals.** A guided morning plan, tasks timeboxed onto
the calendar, an evening shutdown. The camp Omakase's Plan → Focus → Review
loop belongs to: **Sunsama**, **Akiflow**, **Ellie Planner**, and the
visual-timeline planners **Structured** and **Tiimo**. **Routine** makes
the same claims on its marketing page and was not verified further.

**B. AI auto-schedulers.** The software places the blocks: **Motion**,
**Reclaim.ai**, and, leaning this way since their last repositioning,
**Morgen** ("Daily plans designed by AI, perfected by you") and **Amie**
(whose page title is now "AI Note Taker").

**C. Task managers with a calendar and a timer.** Lists first, with
timeboxing and focus bolted on to varying depth: **TickTick**, **Todoist**,
**Things 3**, **OmniFocus 4**, **Lunatask**, and the open-source **Super
Productivity**.

**D. Student planners.** A class timetable, assignments and exams:
**MyStudyLife**, **Power Planner** (open source), **Shovel**,
**StudySmarter/Vaia**, and the new open-source **Helium Student Planner**.
**iStudiez Pro** is gone from every store (§3).

**E. Focus timers.** **Forest**, **Session**, **Flow**, and **Focusmate**
(body-doubling over video). Timers, not planners.

**F. Study engines.** Spaced repetition: **Anki** (open source) and
**RemNote**. Relevant because IDEA §11 promises a spaced-repetition engine.

**G. First party.** **Apple** Calendar and Reminders, **Google** Calendar
and Tasks, and **Notion** with Notion Calendar. Checked first, because a
platform shipping the category's core matters more than any competitor.

## 2. Signal table

### Planners, schedulers and task managers (camps A-C)

| Product | Camp | Mac client | Offline | Entry paid (mo / yr per mo) | Student | Last release | App Store |
|---|---|---|---|---|---|---|---|
| Sunsama | A | Electron | No | $22 / $17 | yes, amount unstated | 2026-09-23 | 4.49 (504) |
| Akiflow | A | DMG, framework unstated | desktop only | $34 / $19 | 40% off yearly, for life | 2026-09-24 | 4.23 (189) |
| Ellie | A | DMG, framework unstated | not documented | $9.99 / $6.66 | 50% off yearly | 2026-08-23 | 4.64 (61) |
| Structured | A | App Store, universal | not documented | region-priced IAP | no (need-based scholarship) | App Store 2026-09-25 | 4.79 (166,477) |
| Morgen | B | framework unstated | not documented | $30 / $15 | 25%, permanently | 2026-04-17 | 4.44 (212) |
| Amie | B | framework unstated | not documented | not rendered | contact sales | 2026-09-03; iOS 2025-08-06 | 3.39 (128) |
| Motion | B | Electron | not documented | $19 per seat | none | no changelog; desktop 0.117.0 2025-12-15; iOS 2025-11-27 | 4.10 (1,854) |
| Reclaim.ai | B | PWA | not documented | $10-12 per seat | 50% for 12 months | 2026-06-04 | no app |
| TickTick | C | own Mac App Store app | not documented | - / $4.17 | 25%, one year | 2026-09-15 | 4.86 (46,001) |
| Todoist | C | own Mac App Store app | yes | $7 / $5 | none | 2026-09-17 | 4.80 (129,207) |
| Things 3 | C | Apple-only app | yes, full local DB | $49.99 once (Mac) | none | 2026-09-14 | 4.82 (27,957) |
| OmniFocus 4 | C | SwiftUI | not documented | $99.99/yr or $74.99 once | direct store only | 2026-09-22 | 4.03 (337) |
| Lunatask | C | Electron (v3 rewrite announced) | short-term, E2EE | $8 / $6 | 50% | 2026-07-10 | 4.42 (101) |

Sources, row by row: Sunsama
([FAQ, "The desktop app uses Electron"](https://help.sunsama.com/docs/faq/faq/),
[offline request open since 2020, 230 votes](https://roadmap.sunsama.com/improvements/p/offline-mode-for-desktop-app),
[pricing](https://www.sunsama.com/pricing),
[student](https://help.sunsama.com/docs/billing/overview/),
[changelog](https://roadmap.sunsama.com/changelog));
Akiflow ([desktop and offline](https://product.akiflow.com/en/help/articles/0883150-desktop-app),
[pricing](https://akiflow.com/pricing),
[changelog](https://product.akiflow.com/changelog));
Ellie ([pricing](https://ellieplanner.com/pricing),
[changelog](https://feedback.ellieplanner.com/changelog));
Structured ([plans](https://help.structured.app/en/articles/1897986),
[scholarship](https://help.structured.app/en/articles/331330),
[listing](https://apps.apple.com/us/app/structured-daily-planner-todo/id1499198946));
Morgen ([pricing](https://morgen.so/pricing),
[changelog](https://changelog.morgen.so/));
Amie ([billing](https://amie.so/documentation/account/billing),
[changelog](https://amie.so/changelog));
Motion ([pricing](https://www.usemotion.com/pricing); Electron from the
release archive's contents, in [`motion.md`](motion.md));
Reclaim ([PWA](https://help.reclaim.ai/en/articles/8709737-add-reclaim-to-your-desktop),
[pricing](https://reclaim.ai/pricing),
[updates](https://updates.reclaim.ai/));
TickTick ([upgrade](https://ticktick.com/about/upgrade),
[education](https://www.ticktick.com/education),
[what's new](https://help.ticktick.com/articles/7082552170989486080));
Todoist ([offline](https://www.todoist.com/help/articles/use-todoist-while-offline-4rbaZw),
[pricing FAQ](https://todoist.com/help/todoist/billing/todoist-plans-pricing-and-billing-faq-Vq2z0HWL6),
[no student discount](https://www.todoist.com/help/articles/do-you-offer-a-discount-uYpvgw4gv),
[changelog](https://www.todoist.com/help/articles/2026-changelog-HD3jJAtLd));
Things ([cloud, local database](https://culturedcode.com/things/cloud/),
[purchase](https://culturedcode.com/things/support/articles/2803552/),
[release notes](https://culturedcode.com/things/support/articles/1100684/));
OmniFocus ([manual, SwiftUI](https://support.omnigroup.com/documentation/omnifocus/universal/4.3.3/en/welcome-to-omnifocus/),
[buy](https://www.omnigroup.com/omnifocus/buy),
[release notes](https://www.omnigroup.com/releasenotes/omnifocus));
Lunatask ([FAQ, Electron and Lunatask 3](https://lunatask.app/docs/common-questions),
[offline](https://lunatask.app/docs/getting-started/privacy),
[education](https://lunatask.app/education),
[releases](https://lunatask.app/releases)).

Two figures conflict between a vendor's own pages and are recorded as
ranges: Reclaim's per-seat price ($10/$15 against $12/$18 depending on the
billing toggle) and Sunsama's (the pricing page shows $25/$20 per member,
the help centre $22/$17). Todoist's pricing page may show $4 a month billed
yearly; it did not render, and the billing FAQ's $5 is used.

### Student planners, focus timers, study engines (camps D-F)

| Product | Camp | Mac client | Offline | Entry paid | Last release | App Store |
|---|---|---|---|---|---|---|
| MyStudyLife | D | none (iPhone, iPad, web) | not documented | $6.99/mo, $39.99/yr; free capped at 5 tasks | 2026-09-17 | 4.50 (6,227) |
| Shovel | D | none (web; iOS "only a companion app") | not documented | $9.79/mo, $39/yr | 2026-08-21 | 4.22 (233) |
| Vaia | D | none | not documented | "free forever" plus premium IAP | 2026-09-23 | 4.71 (1,537) |
| Forest | E | none (iPad app at most) | not documented | about $5.99/mo | 2026-09-24 | 4.80 (49,483) |
| Session | E | yes, in the purchase | not documented | $4.99/mo, $39.99/yr; students 30% off | build 2026-07-16; changelog 2025-03-24 | 4.79 (364) |
| Flow | E | yes, in the purchase | iCloud sync | $39.99 lifetime IAP | 2026-08-10 | 4.76 (1,753) |
| Focusmate | E | none (web only) | n/a | $8/mo yearly | blog 2023; Labs note 2026-04 | no app |
| RemNote | F | web-app wrapper | desktop full | $8/mo | iOS 2026-09-17 | 4.84 (1,601) |

Sources: MyStudyLife ([MSL+](https://mystudylife.com/msl-plus/),
[listing](https://apps.apple.com/us/app/my-study-life-school-planner/id910639339));
Shovel ([pricing](https://shovelapp.io/pricing/),
[listing](https://apps.apple.com/us/app/shovel-study-planner/id1467742357));
Vaia ([study plan](https://www.vaia.com/en-us/features/study-plan/),
[listing](https://apps.apple.com/us/app/vaia-flashcards-study-guide/id1439949520));
Forest ([site](https://www.forestapp.cc/),
[listing](https://apps.apple.com/us/app/forest-focus-for-productivity/id866450515));
Session ([pricing](https://www.stayinsession.com/pricing),
[changelog](https://www.stayinsession.com/changelog));
Flow ([pricing](https://www.flow.app/pricing),
[changelog](https://www.flow.app/changelog));
Focusmate ([pricing](https://www.focusmate.com/pricing/),
[Labs](https://support.focusmate.com/en/articles/14797266-focusmate-labs));
RemNote ([desktop](https://help.remnote.com/en/articles/6030835-desktop-app),
[offline](https://help.remnote.com/en/articles/6752029-offline-mode),
[pricing](https://www.remnote.com/pricing)). "Mac client: yes, in the
purchase" means Apple's lookup API lists `MacDesktop` in the app's
`supportedDevices`.

### Open source

| Repository | Camp | Stars | Last push | Latest release | Open issues | Licence | Stack |
|---|---|---|---|---|---|---|---|
| `super-productivity/super-productivity` | C | 22,254 | 2026-09-25 | v19.1.0 (2026-09-19) | 1,290 | MIT | Angular; Electron desktop, Capacitor mobile |
| `ankitects/anki` | F | 31,540 | 2026-09-25 | 26.09.3 (2026-09-23) | 434 | AGPL-3.0+ | Rust, Python, Qt |
| `powerplanner/powerplannerapps` | D | 47 | 2026-09-13 | App Store 2026-09-17 | - | GPL-3.0 | C#, Xamarin, UWP |
| `HeliumEdu/platform` | D | 9 | 2026-09-25 | - | - | Apache-2.0 | **Django** API, Flutter client |

Super Productivity moved from `johannesjo/` to its own organisation; the
old path redirects. Its desktop is Electron (`"electron": "43.5.0"` in
`package.json`) and its mobile app is Capacitor 8.

### Features, across camps

`Y` yes, `P` partial, `N` documented no, `-` not found on the pages read
(weaker than `N`). Work tasks means projects or lists beyond school.

| Product | Timebox | Pomodoro | Plan ritual | Shutdown | Timetable | Grades | Work tasks |
|---|---|---|---|---|---|---|---|
| Sunsama | Y | Y | Y | Y | - | - | Y |
| Akiflow | Y | Y (desktop only) | Y | Y | - | - | Y |
| Ellie | Y | Y | Y (desktop only) | Y | - | - | Y |
| Structured | Y | Y | - | - | - | - | Y |
| Morgen | Y | N | Y (AI) | N | - | - | Y |
| Amie | Y | - | - | - | - | - | Y |
| Motion | Y (auto) | - | P | - | - | - | Y |
| Reclaim.ai | Y (auto) | P (separate tool) | N | - | - | - | Y |
| TickTick | Y | Y | P | P | P (China edition only) | - | Y |
| Todoist | Y (Pro) | N | P | - | - | - | Y |
| Lunatask | Y | P | - | P (journal) | - | - | Y |
| Things 3 | N | - | P | - | - | - | Y |
| OmniFocus 4 | N | N | P | P (project review) | - | - | Y |
| Super Productivity | Y | Y | P | Y | - | - | Y |
| MyStudyLife | - | P | - | - | Y | Y | P (paid "Activities") |
| Power Planner | - | - | - | - | Y | Y | - |
| Shovel | Y (App Store subtitle) | - | - | - | P | P | - |
| **Omakase, shipped** | **API only** | **API only** | **N** | **API only** | **API only** | **N** | **API only** |

The feature cells for competitors come from the help pages cited in their
rows above and, for the five deep-dived products, from
[`ticktick.md`](ticktick.md), [`sunsama.md`](sunsama.md),
[`motion.md`](motion.md), [`super-productivity.md`](super-productivity.md)
and [`mystudylife.md`](mystudylife.md) (#107). TickTick's timetable exists
only in Dida365, its China edition
([help article](https://help.dida365.com/articles/6950372717036044288));
none of TickTick's 96 international help articles mentions one.

**Omakase's row is its code on `develop`, not IDEA.md.** The API has
timeboxing (`timeblocks/`), pomodoro sessions (`pomodoro/sessions/`), a
daily review (`stats/reviews/`), a class timetable (`study/classschedules/`,
`study/class-occurrences/`) and a work hierarchy (`workspaces/`,
`projects/`, `tasks/`). The only client that can reach any of it today is
the Mac app's M1, which has two screens: sign-in and a Today checklist
(`apps/apple/Packages/OmakaseFeatures/Sources/OmakaseFeatures/`). The web
client that used these endpoints was removed in #62. A user cannot
timebox, run a pomodoro, or close a day in Omakase today.

### What the table says that a list of names does not

- **Nobody spans both halves.** Every product in camps A to C has work
  tasks and no timetable; every student planner with a timetable
  (MyStudyLife, Power Planner, Shovel, Helium) has no work. The one exception is behind a border: TickTick's timetable ships
  only in Dida365. MyStudyLife sells work as a paid add-on called
  Activities, and Shovel treats it as busy time to plan around
  ([`mystudylife.md`](mystudylife.md)). This is the square IDEA.md's first
  sentence claims, and on this evidence it is empty.
- **Timeboxing is no longer a feature, it is the floor.** Twelve of the
  fourteen planners and task managers above timebox, and so does Google
  Calendar, for free, on personal accounts, since November 2025 (§3.1).
  Omakase cannot win on timeboxing; it can only be absent from it.
- **Where the framework is documented, the planners run on Electron or
  the web.** Sunsama and Lunatask are Electron by their own words, Motion
  by its release archive, Reclaim is a PWA, and Sunsama has had an
  unanswered offline request since 2020. Akiflow, Ellie and Morgen do not
  say. The two apps that are documented native - Things (a full local
  database, offline) and OmniFocus (SwiftUI; offline not documented) -
  are list managers with no timeboxing and no timer. A native, offline-first
  Mac planner with the whole ritual is not in this table.
- **Student planners plan due dates, not time.** MyStudyLife and Power
  Planner hold the timetable and the deadlines and leave the hours to the
  student. Shovel is the only one that timeboxes study, and it has no Mac
  app and calls its iPhone app a companion.
- **The AI money went to scheduling, and one of its two leaders just
  stepped back.** Reclaim 2.0 no longer auto-schedules individual tasks: it
  "will recommend 3-5 tasks that are 'Relevant Now'", stages changes "in
  Preview Mode so you can review them before applying them", and sends
  users who want per-task auto-scheduling back to 1.0
  ([tasks overview](https://help.reclaim.ai/en/articles/16558552-reclaim-2-0-tasks-overview),
  [FAQ](https://help.reclaim.ai/en/articles/15280604-reclaim-2-0-faq)).
  That is close to IDEA §6's morning plan, which suggests up to five blocks
  to accept, modify or dismiss.
- **A student price is the norm, not a differentiator.** Nine of the
  thirteen products in the first table offer a student or education
  discount. Six state an amount: 25% (Morgen, TickTick), 40% (Akiflow),
  50% (Ellie, Lunatask, Reclaim). Sunsama and OmniFocus give none, and
  Amie says "contact sales". Todoist, Motion, Things and Structured (a
  need-based scholarship instead) do not offer one.
- **Liveness is uneven.** Motion has no public changelog; its iPhone app
  was last updated 2025-11-27 and its desktop app on 2025-12-15. Amie's iPhone app has not been updated since
  2025-08-06 and rates 3.39. Session's changelog stops at 2025-03-24 while
  "Session 3" waits. Focusmate's product blog stops in 2023.

### Sizing the field, and what that number is worth

Captured 2026-09-25 with the command in "Reproducing the table", and
re-run the same day by the audit of this file with the same results.

| Query (GitHub repository search) | Count |
|---|---|
| `topic:pomodoro` | 3,307 |
| `topic:study-planner` | 316 |
| `topic:daily-planner` | 121 |
| `topic:time-blocking` | 62 |
| `topic:student-planner` | 46 |
| `topic:timeblocking` | 9 |

These count repositories that chose a topic, not products; most pomodoro
repositories are someone's first timer. What the ratio shows is that a
timer is the thing everyone builds and a planner that timeboxes is rare,
even in open source. No open-source study planner in the topic searches has
more than 500 stars. The commercial field is better measured by the App
Store counts above: Structured (166,477 ratings), Todoist (129,207),
Forest (49,483) and TickTick (46,001) are the audiences. The three
planners with a full plan-and-shutdown ritual - Sunsama (504), Akiflow
(189) and Ellie (61) - are small by comparison.

## 3. What the notable ones actually are

### 3.1 First party: the calendar owners have shipped the floor, not the loop

**Apple.** The current release is **iOS 27 and macOS 27**, released
2026-09-14 ([newsroom](https://www.apple.com/newsroom/2026/09/major-updates-for-apples-software-platforms-are-now-available/)).
Omakase's Mac client spec targets macOS 26; that is recorded here as a
fact for #105 to weigh, not a recommendation.

- Reminders appear in Calendar: "Reminders with a time appear next to a
  specific time in the full-day schedule"
  ([Calendar guide](https://support.apple.com/guide/calendar/use-reminders-icl873b9a527/mac)).
  They are points in time; the guide gives them no duration.
- Apple Intelligence "can suggest reminders - like key action items from
  emails" ([support](https://support.apple.com/en-us/124025)); Calendar
  on macOS 27 creates events "with just a description"
  ([macOS](https://www.apple.com/os/macos/)); Siri AI can "Create a
  reminder", in beta, English only, and not initially in the EU
  ([iOS](https://www.apple.com/os/ios/), newsroom above).
- Not found on Apple's pages: a focus timer, a timetable, semesters,
  grades, a daily plan or review, or scheduling tasks into free time.
  Apple's AI today is capture, not planning.

**Google.** "Users can now easily block off time on their calendar to
work on a specific task", with start and end times on tasks, for
"users with personal Google accounts" among others, since 2025-11-17
([Workspace updates](https://workspaceupdates.googleblog.com/2025/11/block-time-for-tasks-google-calendar.html)).
**That is Omakase's task time block, free, on the calendar most users
already have.** Focus time needs a work or school account, Workspace for
Education included ([help](https://support.google.com/calendar/answer/11190973?hl=en&co=GENIE.Platform%3DDesktop)),
and the cross-app Gemini agent that schedules meetings and files to-dos
into Tasks is English-only on paid plans
([Workspace updates](https://workspaceupdates.googleblog.com/2026/09/create-content-schedule-events-and-coordinate-tasks-across-Workspace-regardless-of-what-app-you-are-in.html)).
Not found: a timer, a timetable, grades or a review.

**Notion.** Connect a database to Notion Calendar and "drag and drop these
events to specific times in the day, and your Notion database will
automatically update to mirror your calendar"
([guide](https://www.notion.com/help/guides/getting-started-with-notion-calendar)).
Offline mode shipped in 2.53 ([release](https://www.notion.com/releases/2025-08-19));
Notion Agent got calendar tools on 2026-07-16
([release](https://www.notion.com/releases/2026-07-16)); Education Plus is
free to students ([help](https://www.notion.com/help/notion-for-education)).
Both desktop apps are Electron: the installed `Notion.app` (7.34.0) and
`Notion Calendar.app` (1.139.0) each contain
`Contents/Frameworks/Electron Framework.framework`. Timetables, grades and
daily reviews exist in Notion only as templates a user builds.

**Verdict.** Putting a task on a calendar is now free in three places a
student already has. None of the three ships a timetable, a semester, a
focus timer or a daily review. The floor has moved up to meet Omakase's
first feature and stopped below its loop.

### 3.2 The work+study square, and who is nearest to it

- **TickTick** is the broadest single overlap: tasks, calendar
  timeboxing, a strong focus timer with notes and statistics, and habits
  ([`ticktick.md`](ticktick.md)). It has no guided plan or shutdown ritual - only
  Suggested Tasks and a generated Summary - and, in
  its international edition, no timetable. The calendar views and timed
  tasks are Premium.
- **Sunsama** owns the ritual - the guided plan with a workload threshold,
  the shutdown, the weekly review - for "modern professionals", with no
  study model, no free tier and no offline mode
  ([`sunsama.md`](sunsama.md)).
- **Super Productivity** is the strongest open-source reference for the
  work side: a planner, Pomodoro/Flowtime, a finish-day summary with an
  energy and impact rating, local-first storage. A code search for
  student, semester, school, lecture or timetable finds only icon names
  ([`super-productivity.md`](super-productivity.md)).
- **MyStudyLife** is the reference timetable - rotations, holidays, exams
  as their own items - and plans due dates, not hours; its 2024 rewrite
  cost it users ([`mystudylife.md`](mystudylife.md)).
- **Motion** is the opposite bet: the software places everything, and a
  lock expires if the task is not done within an hour of its slot
  ([`motion.md`](motion.md)).

### 3.3 Dead, moved, or not what it was

- **iStudiez Pro** returns nothing from Apple's lookup API in six
  storefronts, its store pages and Google Play listing are 404s, and its
  site returned HTTP 522 twice. The only statement that it shut down is a
  third-party blog post (positioning evidence only). Treated as dead.
- **Super Productivity** moved to `super-productivity/super-productivity`;
  not a death, a rename.
- **Amie** now titles its site "AI Note Taker". **Motion**'s funding post
  says it is "building the first end-to-end agentic work suite", focused
  on "small and mid-sized businesses"
  ([blog, 2025-09-08](https://www.usemotion.com/blog/motion-raises-60m-to-build-the-agentic-work-suite-for-businesses)).

## 4-6. Developments, recommendations, sources

Follow in #110, after the deep dives (#107) and the tracker mining (#108)
they depend on.

## Reproducing the table

App Store rows:

```bash
curl -s "https://itunes.apple.com/lookup?id=<id>&country=us" \
  | jq -r '.results[0]|[.trackName,(.averageUserRating|tostring),
      (.userRatingCount|tostring),.currentVersionReleaseDate[0:10],
      (.supportedDevices|map(select(test("Mac")))|join(","))]|@tsv'
```

Repository rows:

```bash
for r in super-productivity/super-productivity ankitects/anki \
         powerplanner/powerplannerapps HeliumEdu/platform; do
  j=$(gh api "repos/$r")
  oi=$(gh api "search/issues?q=repo:$r+is:issue+is:open&per_page=1" --jq .total_count)
  echo "$j" | jq -r --arg oi "$oi" \
    '[.full_name,(.stargazers_count|tostring),.pushed_at[0:10],$oi,
      (.license.spdx_id//"none")]|@tsv'
done
```

Field size (urlencode the query):

```bash
gh api "search/repositories?q=topic%3Apomodoro&per_page=1" --jq .total_count
```
