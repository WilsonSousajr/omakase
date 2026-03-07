
# Omakase — Detailed Feature Plan

> This document serves as the complete feature specification for Omakase. Every feature is described with its purpose, behavior, data model considerations, edge cases, and implementation priority. This is a living document that should evolve as development progresses.

---

## Table of Contents

1. [Core Data Architecture](#1-core-data-architecture)
2. [Work Side: Projects](#2-work-side-projects)
3. [Study Side: Semesters](#3-study-side-semesters)
4. [Exam Prep Mode](#4-exam-prep-mode)
5. [Unified Calendar & Time Blocking](#5-unified-calendar--time-blocking)
6. [Daily Planning Ritual](#6-daily-planning-ritual)
7. [Focus Mode](#7-focus-mode)
8. [Daily Review & Shutdown](#8-daily-review--shutdown)
9. [Analytics & Dashboards](#9-analytics--dashboards)
10. [Study Plan Generator](#10-study-plan-generator)
11. [Spaced Repetition Engine](#11-spaced-repetition-engine)
12. [Deadline Aggregator](#12-deadline-aggregator)
13. [Energy Mapping & Smart Scheduling](#13-energy-mapping--smart-scheduling)
14. [Templates & Routines](#14-templates--routines)
15. [Habits & Retention Mechanics](#15-habits--retention-mechanics)
16. [Notes System](#16-notes-system)
17. [Quick Capture Inbox](#17-quick-capture-inbox)
18. [Export & Sharing](#18-export--sharing)
19. [Settings & Personalization](#19-settings--personalization)
20. [Implementation Roadmap](#20-implementation-roadmap)

---

## 1. Core Data Architecture

### 1.1 Two Parallel Hierarchies

Omakase is built around two top-level organizational structures that share the same time resource:

**Work Hierarchy:**

```
User
└── Workspace
    └── Project
        └── Task
            └── Subtask
```

**Study Hierarchy:**

```
User
└── Semester (or Exam Plan)
    └── Discipline (or Subject)
        └── Study Block
            └── Topic
```

Both hierarchies feed into a unified **Daily Plan** — the central interface where all blocks, regardless of origin, are scheduled on the same timeline.

### 1.2 The Time Block as Universal Unit

Every schedulable item in Omakase is ultimately represented as a **Time Block** on the calendar. A Time Block has:

- `id`: unique identifier
- `title`: display name
- `source_type`: enum — `work_task`, `study_block`, `class_schedule`, `personal`, `routine`
- `source_id`: foreign key back to the originating task, study block, or routine
- `context`: enum — `work`, `study`, `personal`
- `date`: the day this block is scheduled for
- `start_time`: scheduled start (nullable for unscheduled blocks)
- `end_time`: scheduled end (nullable for unscheduled blocks)
- `estimated_minutes`: how long the user thinks it will take
- `actual_minutes`: how long it actually took (filled after completion or via Pomodoro tracking)
- `status`: enum — `planned`, `in_progress`, `completed`, `skipped`, `rolled_over`
- `energy_level`: enum — `deep_work`, `moderate`, `low_energy` (inherited from user's energy map or manually set)
- `pomodoro_count`: number of Pomodoro sessions completed against this block
- `notes`: free-text session notes captured during or after execution
- `color`: inherited from project/discipline color or manually overridden
- `order`: integer for ordering within the daily Kanban view

This is the atomic unit that powers the calendar, the focus mode, the review, and the analytics.

### 1.3 User Profile & Preferences

- `timezone`: auto-detected, manually overridable
- `work_hours`: start/end of workday (used for energy mapping defaults)
- `study_hours`: preferred study window (e.g., 18:00–22:00)
- `pomodoro_defaults`: work duration, short break, long break, sessions before long break
- `week_starts_on`: Monday or Sunday
- `daily_study_goal_hours`: target for weekly goal tracking
- `daily_work_goal_hours`: target for weekly goal tracking
- `theme`: dark/light (dark by default)
- `notification_preferences`: morning plan reminder, focus session alerts, daily shutdown reminder

---

## 2. Work Side: Projects

### 2.1 Workspace

The Workspace is the top-level container for all work-related activity. A user has one active Workspace (multi-workspace support can be added later for freelancers with multiple clients).

**Attributes:**
- `name`: e.g., "FigVell", "Guia Educação", "Freelance"
- `color`: workspace accent color
- `created_at`, `updated_at`

### 2.2 Projects

A Project represents a bounded body of work with a goal and optional deadline.

**Attributes:**
- `name`: e.g., "Athena ETL Pipeline", "TutorPE Security Improvements"
- `description`: markdown-supported project description
- `color`: used for time block coloring on the calendar
- `status`: enum — `active`, `paused`, `completed`, `archived`
- `deadline`: optional target completion date
- `estimated_hours`: optional total estimated effort
- `logged_hours`: auto-calculated from completed time blocks
- `created_at`, `updated_at`

**Behaviors:**
- Projects can be paused, which removes their tasks from the daily planning suggestions but preserves all data.
- Archiving a project moves it out of the active view but keeps it available for analytics and reference.
- The project detail view shows a task list, a burndown of estimated vs. logged hours, and a timeline of upcoming deadlines.

### 2.3 Tasks

A Task is a discrete unit of work within a Project.

**Attributes:**
- `title`: short description of the work
- `description`: optional markdown-supported details
- `project_id`: parent project
- `priority`: enum — `urgent`, `high`, `medium`, `low`
- `status`: enum — `backlog`, `todo`, `in_progress`, `done`, `cancelled`
- `deadline`: optional due date
- `estimated_minutes`: how long the user thinks it will take
- `actual_minutes`: auto-summed from time blocks
- `recurrence`: optional — `daily`, `weekly`, `weekdays`, `custom` (for recurring tasks like "daily standup prep")
- `labels`: user-defined tags (e.g., "bug", "feature", "meeting-prep")
- `created_at`, `updated_at`, `completed_at`

**Behaviors:**
- Tasks can be scheduled onto the calendar by dragging them into a time slot, which creates a Time Block linked to the task.
- A single task can span multiple time blocks across multiple days (e.g., a large feature broken into 3 work sessions).
- When a task's time block is marked complete in Focus mode, the task status auto-updates. If all time blocks for a task are done, the task moves to `done`.
- Tasks without a scheduled time block appear in a "Backlog" sidebar panel, always accessible during planning.

### 2.4 Subtasks

Subtasks are lightweight checklist items within a Task. They don't have their own time blocks — they are checked off during a parent task's focus session.

**Attributes:**
- `title`: short description
- `is_completed`: boolean
- `order`: display order within the parent task

---

## 3. Study Side: Semesters

### 3.1 Semester

A Semester represents an academic period with defined boundaries.

**Attributes:**
- `name`: e.g., "2025/1", "5º Semestre"
- `institution`: optional — e.g., "UnB"
- `start_date`: semester start
- `end_date`: semester end
- `status`: enum — `active`, `completed`, `archived`
- `created_at`, `updated_at`

**Behaviors:**
- Only one Semester can be `active` at a time. When a new semester starts, the previous one auto-transitions to `completed`.
- The semester overview shows all disciplines, their grade status, and a burndown of syllabus progress.
- At semester end, a summary report is generated showing total study hours, grade outcomes, and discipline-level breakdowns.

### 3.2 Disciplines

A Discipline represents a single course or subject within a Semester.

**Attributes:**
- `name`: e.g., "Cálculo 2", "Banco de Dados", "Sinais e Sistemas"
- `code`: optional course code — e.g., "MAT0021"
- `professor`: optional
- `color`: used for time block coloring and analytics segmentation
- `semester_id`: parent semester
- `credits`: optional — useful for weighted calculations
- `target_grade`: the minimum grade the user wants (e.g., 5.0 for "just pass" or 9.0 for "excel")
- `status`: enum — `active`, `completed`, `dropped`
- `created_at`, `updated_at`

### 3.3 Class Schedule

Each Discipline has a weekly recurring class schedule that auto-generates fixed blocks on the calendar.

**Attributes:**
- `discipline_id`: parent discipline
- `day_of_week`: enum — Monday through Saturday
- `start_time`: e.g., 10:00
- `end_time`: e.g., 11:40
- `location`: optional — e.g., "ICC Sul, Sala AT-096"
- `type`: enum — `lecture`, `lab`, `tutorial`, `seminar`

**Behaviors:**
- When a discipline's class schedule is defined, recurring Time Blocks are auto-generated for every matching day within the semester's date range.
- These blocks appear as "fixed" on the calendar — they can't be dragged or resized, only hidden if the class is cancelled on a specific date.
- The user can mark individual class occurrences as `cancelled` or `holiday` to remove them from a specific day without affecting the recurring pattern.

### 3.4 Syllabus & Topics

Each Discipline has an ordered list of Topics representing the syllabus.

**Attributes:**
- `discipline_id`: parent discipline
- `title`: e.g., "Transformada de Laplace", "Normalização de Bancos de Dados"
- `order`: position in the syllabus
- `status`: enum — `not_started`, `in_progress`, `studied`, `needs_review`
- `last_studied_at`: timestamp of the most recent study session covering this topic
- `next_review_at`: calculated by the spaced repetition engine
- `notes`: optional markdown notes or references for this topic
- `estimated_hours`: optional — how long the user thinks this topic requires
- `actual_hours`: auto-summed from study blocks tagged with this topic

**Behaviors:**
- The syllabus is displayed as a vertical progress tracker. Each topic shows its status with a visual indicator (not started = gray, in progress = yellow, studied = green, needs review = orange).
- The user can reorder topics via drag-and-drop to match the actual lecture progression.
- A "pace indicator" compares current progress against the semester timeline: "You've covered 6/15 topics and the semester is 50% done — you're on track" or "You're 3 topics behind pace."
- Topics marked as `studied` automatically get a `next_review_at` date set by the spaced repetition engine.

### 3.5 Grade Tracker

Each Discipline has a configurable grading structure.

**Attributes (Evaluation):**
- `discipline_id`: parent discipline
- `name`: e.g., "P1", "P2", "Lista 3", "Trabalho Final"
- `type`: enum — `exam`, `assignment`, `quiz`, `project`, `participation`, `lab_report`
- `weight`: decimal — the weight of this evaluation in the final grade (e.g., 0.30 for 30%)
- `max_score`: the maximum possible score (e.g., 10.0)
- `score`: the user's actual score (nullable until graded)
- `date`: when this evaluation occurs or is due
- `status`: enum — `upcoming`, `completed`, `graded`

**Calculated Fields:**
- `current_average`: weighted average of all graded evaluations
- `projected_final_grade`: based on current average applied to remaining weight
- `needed_score`: for each upcoming evaluation, "you need X on this to reach your target grade"
- `passing_risk`: enum — `safe`, `at_risk`, `critical` — based on whether it's mathematically possible to reach the minimum passing grade

**Behaviors:**
- The grade tracker is displayed as a card per discipline with a progress ring showing current average vs. target.
- For ungraded evaluations, the user sees a clear "What do I need?" projection. For example: "Current average: 6.5 (P1: 7.0 × 0.3 + Lista avg: 6.0 × 0.2). You need 6.2 on P2 (weight 0.3) to reach your target of 6.5."
- If reaching the target becomes mathematically impossible, the UI clearly flags it: "Even scoring 10.0 on all remaining evaluations, your maximum final grade would be 5.8."
- Grade data feeds into the analytics dashboard for cross-discipline comparisons.

### 3.6 Study Blocks

A Study Block is the study equivalent of a work Task — it represents a planned study activity.

**Attributes:**
- `title`: e.g., "Resolver Lista 4 de Cálculo", "Revisar Normalização"
- `discipline_id`: parent discipline
- `topic_ids`: array — which syllabus topics this study block covers
- `type`: enum — `theory`, `exercises`, `review`, `assignment`, `exam_prep`, `lab`, `reading`
- `priority`: enum — `urgent`, `high`, `medium`, `low`
- `status`: enum — `planned`, `in_progress`, `completed`, `skipped`
- `estimated_minutes`: how long the user expects this to take
- `actual_minutes`: auto-summed from Pomodoro sessions
- `deadline`: optional — linked to an evaluation date or assignment due date
- `evaluation_id`: optional — links this study block to a specific upcoming evaluation (e.g., "this study session is preparation for P2")
- `notes`: session notes captured during focus
- `created_at`, `completed_at`

**Behaviors:**
- Study blocks are scheduled onto the calendar the same way as work tasks — drag from the backlog into a time slot.
- When a study block is completed, any linked topics automatically update their `last_studied_at` and `status`.
- Study blocks linked to an evaluation appear in the evaluation's "preparation timeline" — the user can see how many hours they've invested preparing for each exam.

---

## 4. Exam Prep Mode

Exam Prep Mode is an alternative to the Semester structure for users preparing for competitive exams (concursos públicos, vestibular, OAB, ENEM, certifications, etc.).

### 4.1 Exam Plan

**Attributes:**
- `name`: e.g., "Concurso TRF-1 2025", "ENEM 2025"
- `target_date`: the exam date
- `status`: enum — `active`, `completed`, `archived`
- `total_weekly_hours`: how many hours per week the user can dedicate to preparation
- `created_at`, `updated_at`

### 4.2 Exam Subjects

**Attributes:**
- `exam_plan_id`: parent exam plan
- `name`: e.g., "Direito Constitucional", "Raciocínio Lógico", "Português"
- `weight`: how much this subject counts in the exam (or number of questions)
- `proficiency`: self-assessed level — enum `beginner`, `intermediate`, `advanced`
- `color`: for calendar and analytics
- `target_score`: optional — desired performance level in this subject
- `topics`: ordered list of sub-topics within the subject

**Behaviors:**
- The system calculates a **priority score** for each subject: `weight × inverse_proficiency`. High-weight subjects where the user is weak get the most study time.
- The weekly study plan auto-distributes `total_weekly_hours` across subjects proportional to their priority score.
- The user can override auto-distribution by locking hours for specific subjects (e.g., "I always want at least 3h/week on Português regardless of priority").
- A progress dashboard shows proficiency evolution over time — the user periodically re-assesses their level, and the distribution auto-adjusts.

### 4.3 Mock Exam Tracking

**Attributes:**
- `exam_plan_id`: parent exam plan
- `date`: when the mock was taken
- `source`: e.g., "Simulado QConcursos #3", "Prova TRF-2 2019"
- `scores_per_subject`: array of `{ subject_id, correct, total }`
- `total_score`: overall result
- `notes`: markdown notes about performance observations

**Behaviors:**
- Mock exam results feed into subject proficiency tracking — if the user consistently scores well on Raciocínio Lógico, its priority decreases automatically.
- A chart shows score progression across mocks over time with trend lines per subject.
- After each mock, the system suggests which subjects need more attention based on the gap between performance and weight.

---

## 5. Unified Calendar & Time Blocking

### 5.1 Calendar View

The calendar is the central interface for planning. It displays all time blocks from all sources on a single timeline.

**Views:**
- **Day view**: hourly timeline for detailed scheduling. This is the primary planning interface.
- **Week view**: 7-day grid showing the shape of the week at a glance. Useful for weekly planning.
- **Agenda view**: a flat list of all upcoming blocks/deadlines, sorted chronologically. Good for quick scanning.

**Visual Design:**
- Each block is color-coded by source: work projects use their project color, disciplines use their discipline color, personal blocks use a neutral tone.
- Context badges appear as small icons on each block: 🏢 work, 📚 study, 🏠 personal.
- Fixed blocks (class schedules, work hours) have a subtle pattern or border to distinguish them from user-scheduled blocks.
- Current time is shown as a red horizontal line that moves in real-time.
- Available/empty slots are subtly highlighted during the planning phase to guide the user toward filling gaps.

### 5.2 Time Blocking Interactions

- **Drag from backlog**: a sidebar panel shows unscheduled tasks and study blocks. The user drags one onto the calendar to create a time block.
- **Drag to reschedule**: existing blocks can be dragged to a different time slot or day.
- **Resize**: blocks can be resized by dragging their bottom edge to adjust duration.
- **Click to edit**: clicking a block opens a detail panel showing the linked task/study block, notes, subtasks, and a quick action menu (start focus, mark done, reschedule, delete).
- **Quick add**: clicking an empty slot opens a minimal creation form — the user types a title, picks a context (work/study/personal), and optionally links it to a project or discipline.
- **Split block**: a large block can be split into two (e.g., "I want to study 2 hours but take a break in the middle" → splits into two 1-hour blocks with a gap).

### 5.3 Conflict Detection

- If the user tries to schedule a block overlapping an existing one, the UI shows a warning with options: replace, shrink, or move.
- Double-booking is allowed but flagged visually (overlapping blocks render side-by-side with reduced width).
- Calendar integrations (future feature) will import Google Calendar events as read-only fixed blocks for conflict detection.

---

## 6. Daily Planning Ritual

### 6.1 Morning Plan

Triggered when the user opens Omakase for the first time each day (or manually via a "Plan My Day" button).

**Flow:**

1. **Review carried-over items**: any blocks from yesterday marked as `rolled_over` are shown first. The user decides: reschedule for today, move to another day, or drop.

2. **Show fixed blocks**: class schedules and recurring work commitments are pre-populated on the timeline. The user sees their non-negotiable time commitments.

3. **Show suggested blocks**: based on upcoming deadlines, overdue study blocks, and spaced repetition triggers, Omakase suggests up to 5 blocks for the day. The user can accept, modify, or dismiss each suggestion.

4. **Backlog access**: the full backlog of unscheduled tasks and study blocks is available in a sidebar for manual scheduling.

5. **Workload check**: after the user finishes planning, a summary shows total planned hours for the day, split by context. If the total exceeds a configurable threshold (e.g., 10 hours), a gentle warning appears: "You've planned 11.5 hours today. Consider moving 1-2 blocks to tomorrow."

6. **Commit**: the user presses "Start My Day" which locks the plan and transitions to the main calendar view. The plan can still be adjusted throughout the day, but the commit action serves as a psychological contract.

### 6.2 Weekly Plan (Sunday/Monday)

A broader planning session triggered once a week.

**Flow:**

1. **Review last week**: summary of hours worked vs. studied, completed vs. planned blocks, grade updates, and streak status.

2. **Set weekly objectives**: the user defines 2-5 high-level goals for the week (e.g., "Finish Lista 5 de Sinais", "Ship Athena dashboard MVP", "Study 3 new chapters of Constitucional").

3. **Distribute blocks**: the user populates the week's calendar at a high level — they don't need to assign exact times, just assign blocks to days. Exact scheduling happens during each morning plan.

4. **Weekly study goal**: set or adjust the target study hours for the week. A progress bar persists in the sidebar all week.

---

## 7. Focus Mode

### 7.1 Overview

Focus Mode is the execution state — the user is working on a specific block and everything else fades away.

**Entry points:**
- Click "Start Focus" on any scheduled time block.
- Press a global keyboard shortcut (e.g., `Ctrl+Shift+F`).
- Automatically triggered when the current time reaches a scheduled block's start time (optional, configurable).

### 7.2 Interface

When Focus Mode activates, the full UI transitions to a minimal layout:

**Left panel — Day Kanban (narrow):**
- Three columns: To Do, In Progress, Done.
- Shows only today's remaining blocks.
- The currently active block is highlighted and pinned to the top of "In Progress."
- Completed blocks auto-move to "Done" with a subtle animation.
- Blocks can be reordered in "To Do" to adjust execution order.

**Center panel — Current Block:**
- The block's title, linked project/discipline, and any subtasks are displayed prominently.
- Subtasks appear as a checklist that can be ticked off during the session.
- A large, clear indication of what the user is supposed to be doing right now.

**Right panel — Timer & Notes:**
- **Pomodoro Timer**: large circular countdown showing remaining time in the current Pomodoro.
  - Configurable: 25/5, 50/10, or custom intervals.
  - Visual states: Focus (red/warm accent), Short Break (green/cool accent), Long Break (blue accent).
  - Session counter: "#3" showing how many Pomodoros completed in this block.
  - Controls: Start, Pause, Skip Break, Reset.
  - Auto-start next Pomodoro after break is configurable (on/off).
- **Session Notes**: a markdown textarea where the user captures thoughts, observations, or progress notes during the session. These notes are saved to the time block and are visible in Review and Analytics.
- **Quick Capture Inbox**: a small input field at the bottom. Anything typed here goes into the Inbox (see section 17), not into the current block's notes. This is for capturing stray "oh I need to remember to do X" thoughts without breaking focus.

### 7.3 Ambient Mode

An optional sub-feature within Focus Mode:

- A simple audio player with preset categories: lo-fi, rain, café, white noise, nature, silence.
- Volume control and mix options (e.g., rain + café at different levels).
- The audio auto-pauses during breaks and resumes when the next Pomodoro starts (configurable).
- No YouTube integration — this is intentionally a curated, non-distracting audio experience. Audio files are served from the backend or a CDN, not from external platforms that could become rabbit holes.

### 7.4 Focus Session Completion

When the user finishes the time block (either by completing all Pomodoros, manually ending, or the estimated time elapses):

1. A brief prompt appears: "How did this session go?" — optional 1-5 rating.
2. "What did you accomplish?" — optional free-text (pre-filled with checked subtasks if any).
3. The block's `actual_minutes` is recorded based on Pomodoro tracking.
4. The block moves to "Done" in the Kanban.
5. If the task/study block has more scheduled blocks on future days, a note appears: "Continuing tomorrow at 14:00."
6. The next block in "To Do" is suggested: "Up next: Resolver Lista 4 de Cálculo (📚 45 min)." The user can start immediately or take a break.

### 7.5 Session Interruption Handling

Real life interrupts focus sessions. Omakase handles this gracefully:

- **Pause**: the timer pauses. If paused for more than 5 minutes, a gentle nudge: "Still on break? Resume or reschedule?"
- **Abandon**: the user can abandon the current block. The time already spent is logged as `actual_minutes`. The block can be rescheduled or marked as partially done.
- **Overflow**: if the Pomodoro count exceeds the estimated duration, the timer keeps running but the UI shows "overtime" — the block border turns amber. The user can continue or stop. Overtime is tracked separately in analytics.

---

## 8. Daily Review & Shutdown

### 8.1 Trigger

The Daily Review activates at the user's configured shutdown time (e.g., 22:00) via a notification, or manually via a "Shut Down" button. It takes 2-3 minutes maximum.

### 8.2 Flow

1. **Completion summary**: side-by-side view of planned vs. completed blocks. Each block shows:
   - ✅ Completed (with actual vs. estimated time comparison)
   - ⏭️ Skipped (with option to add a reason)
   - 🔄 Rolled over to tomorrow (default for incomplete blocks)
   - ❌ Cancelled

2. **Rollover decisions**: for each incomplete block, the user chooses:
   - Roll over to tomorrow (default — the block appears in tomorrow's morning plan).
   - Move to a specific future date.
   - Send back to backlog (deprioritized).
   - Cancel (the linked task/study block returns to its previous status).

3. **Daily productivity score**: a simple self-assessment — "How productive did you feel today?" on a 1-5 scale. This is stored as `daily_productivity_rating` and feeds into trend analytics.

4. **Win of the day**: an optional prompt — "What was your biggest win today?" Free text. Stored and shown in the weekly review for positive reinforcement.

5. **Tomorrow's preview**: a quick glance at tomorrow's fixed blocks and any already-scheduled items. No planning required — that happens in the morning.

6. **Shutdown confirmation**: "Great work today. Time to rest." The UI transitions to a calm shutdown screen. If the user tries to open planning or focus features after shutdown, a gentle reminder appears (not a hard block — just a nudge).

### 8.3 Review History

The review page has a **Today / History** tab bar above the wizard. "Today" shows the 6-step wizard (default). "History" shows a paginated list of past daily reviews, newest-first.

Each history card shows a **compact view**: date (e.g. "Friday, March 6"), year label, rating dots (1-5, filled/unfilled), win excerpt (single line with quotes), and a moon icon if shutdown was completed. Clicking a card **expands** it to lazy-load the full review summary (hours focused, blocks, completion %, completed items, incomplete items). Data is cached by date — collapse and re-expand is instant.

"Load more" button at the bottom fetches the next page. No backend changes needed — the existing `DailyReviewViewSet` list endpoint (without date filter) and `ReviewSummaryView` already support everything.

---

## 9. Analytics & Dashboards

### 9.1 Daily Stats (visible in sidebar)

- Hours focused today (auto-tracked from Pomodoro sessions)
- Blocks completed / total planned
- Current streak (consecutive days with ≥ 1 completed block)
- Weekly study/work hour progress bars

### 9.2 Weekly Dashboard

**Time Distribution:**
- Stacked bar chart: Mon–Sun, each bar split by context (work / study / personal).
- Hover to see breakdown by project or discipline.
- Total hours per context for the week.

**Study Consistency Heatmap:**
- GitHub-style contribution graph showing study hours per day over the last 12 weeks.
- Color intensity represents hours: 0h = gray, 1-2h = light green, 3-4h = medium, 5h+ = dark green.
- Separate heatmaps for work and study available on toggle.

**Planned vs. Actual:**
- Bar chart comparing planned hours vs. actual hours per day.
- Helps the user calibrate their time estimates over time.
- A "estimation accuracy" metric: average ratio of actual/estimated across all completed blocks this week.

**Context Split:**
- Pie chart showing work vs. study vs. personal time proportions.
- Comparison with the previous week: "You studied 15% more this week."

### 9.3 Semester Dashboard

**Grade Overview:**
- Card grid showing each discipline with:
  - Current weighted average (big number)
  - Target grade (smaller, for comparison)
  - Status indicator: 🟢 on track, 🟡 at risk, 🔴 critical
  - Next evaluation name and date
  - "Need X on next exam" calculation

**Syllabus Burndown:**
- Per-discipline line chart: topics covered over time vs. ideal pace line.
- If the user is behind, the gap is highlighted in red.
- "At current pace, you'll finish the syllabus by [date]" projection.

**Study Hours by Discipline:**
- Horizontal bar chart ranking disciplines by total study hours invested.
- Helps identify if the user is over-investing in one discipline at the expense of others.

**Upcoming Deadlines Timeline:**
- A horizontal timeline showing all upcoming exams, assignments, and project deadlines across all disciplines and work projects.
- Color-coded by source. Click to see preparation status.

### 9.4 Exam Prep Dashboard (for Exam Prep Mode)

- Subject priority matrix: scatter plot with weight on X-axis and proficiency on Y-axis. Quadrant highlighting: high weight + low proficiency = focus here.
- Mock exam progression: line chart showing total score and per-subject scores across mocks.
- Weekly hours distribution vs. recommended distribution.
- Countdown: "X days until exam. At current pace, you'll cover Y% of the material."

### 9.5 Long-Term Trends

- Monthly and quarterly views for study hours, productivity ratings, and streak length.
- Semester-over-semester comparison: "You studied 20% more this semester than last."
- Personal records: "Your longest streak is 34 days," "Your most productive week was Feb 10-16 with 42 focused hours."

---

## 10. Study Plan Generator

### 10.1 Purpose

Given a discipline, an upcoming exam, and the user's available time, the Study Plan Generator creates an optimal study schedule that distributes topics across available slots with built-in review sessions.

### 10.2 Input

- `discipline_id` or manual topic list
- `exam_date`: the target date
- `topics`: which topics to cover (defaults to all `not_started` and `needs_review` topics in the discipline)
- `available_hours_per_week`: how many hours the user can dedicate to this discipline specifically
- `preferred_session_length`: 45min, 60min, 90min, or 120min blocks
- `preferred_days`: which days of the week the user wants to study this discipline
- `difficulty_ratings`: optional per-topic difficulty (1-5) — harder topics get more time

### 10.3 Algorithm

1. **Calculate total available time**: `available_hours_per_week × weeks_until_exam`.
2. **Distribute time across topics**: proportional to difficulty rating (or evenly if no ratings). Each topic gets a `time_budget`.
3. **Schedule initial study sessions**: place topics in chronological order across available days, respecting preferred session length. Earlier topics (foundations) come first.
4. **Insert review sessions**: for each topic, schedule review sessions using the spaced repetition intervals (1 day, 3 days, 7 days after initial study). Reviews are shorter (half the initial session length).
5. **Reserve final review**: the last 2-3 days before the exam are reserved for a comprehensive review — a single long session touching all topics briefly.
6. **Validate feasibility**: if total required time exceeds available time, the system flags it: "You need ~45 hours but only have ~30 available. Consider extending study days or reducing session length." It still generates a best-effort plan covering as many topics as possible, prioritized by weight/difficulty.

### 10.4 Output

- A list of study blocks pre-assigned to specific dates (but not specific times — the user assigns times during daily planning).
- A visual timeline showing the study plan laid out across the weeks until the exam.
- Each generated study block is linked to the relevant topic(s) and tagged with the type (initial study or review).

### 10.5 Adaptability

- If the user falls behind (misses a study block or it takes longer than planned), the generator can be re-run to produce an updated plan with the remaining time.
- The user can lock specific blocks (e.g., "I definitely want to study Transformada de Laplace on Tuesday") and regenerate around those constraints.

---

## 11. Spaced Repetition Engine

### 11.1 Purpose

Automatically suggest when the user should review previously studied topics, based on proven memory retention intervals.

### 11.2 Algorithm

Using a simplified SM-2 variant:

- After first study: review after **1 day**
- After first review: review after **3 days**
- After second review: review after **7 days**
- After third review: review after **14 days**
- After fourth review: review after **30 days**

Each successful review increases the interval. If the user rates a review as "difficult" (optional prompt), the interval resets or shortens.

### 11.3 Integration Points

- **Morning Plan**: "You have 3 topics due for review today" appears as a suggestion card.
- **Study Plan Generator**: review sessions are automatically woven into generated plans.
- **Topic Status**: topics transition from `studied` to `needs_review` when their `next_review_at` date arrives.
- **Discipline View**: a "Due for Review" section shows all topics needing attention, sorted by overdue duration.

### 11.4 User Control

- Spaced repetition is opt-in per discipline. Some disciplines (e.g., lab courses) may not benefit from it.
- The user can snooze review reminders by 1 day or dismiss them entirely.
- Review intervals are customizable per discipline or globally.

---

## 12. Deadline Aggregator

### 12.1 Purpose

A unified view of everything that has a due date across work and study, with preparation intelligence.

### 12.2 Data Sources

- Work task deadlines
- Study block deadlines (assignment due dates)
- Evaluation dates (exams, quizzes)
- Project milestones
- Exam Plan target date

### 12.3 Display

A chronological list grouped by time horizon:

- **Overdue**: anything past due (red)
- **Today**: due today (amber)
- **This Week**: due within 7 days
- **Next Week**: due in 8-14 days
- **This Month**: due in 15-30 days
- **Later**: beyond 30 days

Each deadline entry shows:

- Title and source (project or discipline name, color-coded)
- Due date and countdown ("in 5 days")
- **Preparation status**: for evaluations, shows topics covered vs. total and estimated remaining study hours. For work tasks, shows estimated hours remaining.
- **Risk indicator**: green (on track), yellow (cutting it close), red (likely won't finish in time based on current pace).

### 12.4 Smart Alerts

- **7-day warning**: when an evaluation is 7 days away and less than 50% of its topics have been studied.
- **3-day warning**: for any deadline with remaining work that exceeds the user's available hours in the next 3 days.
- **Same-day conflicts**: when multiple deadlines fall on the same day or adjacent days.

---

## 13. Energy Mapping & Smart Scheduling

### 13.1 Energy Profile

The user defines their typical daily energy curve once in settings:

- **Time slots** broken into configurable blocks (e.g., 2-hour windows)
- **Energy level** per slot: `deep_work` (🔴), `moderate` (🟡), `low_energy` (🟢)

Example:

| Time        | Energy Level |
|-------------|-------------|
| 06:00-08:00 | Deep Work   |
| 08:00-12:00 | Moderate    |
| 12:00-14:00 | Low Energy  |
| 14:00-16:00 | Moderate    |
| 16:00-18:00 | Low Energy  |
| 18:00-20:00 | Deep Work   |
| 20:00-22:00 | Moderate    |

### 13.2 Scheduling Intelligence

- When the user drags a study block tagged as `theory` or `exam_prep` (high cognitive load) into a `low_energy` slot, a non-blocking warning appears: "This is a low-energy time for you. Consider moving intensive study to your deep work hours."
- The Study Plan Generator uses the energy profile to prefer deep work slots for hard topics and low energy slots for lighter tasks (exercise sets, reading, admin).
- In the morning plan, suggested blocks are ordered by energy fit — deep work suggestions appear in the user's deep work slots.

### 13.3 Learning Over Time (Phase 3+)

- Track which blocks were completed "on time" vs. "overtime" by energy slot.
- Over weeks, the system learns the user's actual productive patterns and refines suggestions. (This is a future ML feature — for MVP, the static energy profile is sufficient.)

---

## 14. Templates & Routines

### 14.1 Study Session Templates

Pre-configured block types that reduce friction when planning:

- **Teoria** (Theory): 90 min default, deep work energy, focus mode with minimal breaks
- **Lista de Exercícios** (Exercise List): 120 min default, moderate energy, longer Pomodoro intervals (50/10)
- **Revisão** (Review): 45 min default, any energy level, shorter Pomodoro (25/5)
- **Leitura** (Reading): 60 min default, moderate energy
- **Laboratório** (Lab): custom duration, pre-filled with lab location

Users can create custom templates with preset duration, Pomodoro config, energy level, and tags.

### 14.2 Work Templates

- **Deep Work**: 120 min, no interruptions, deep work energy
- **Meeting Prep**: 30 min, moderate energy
- **Code Review**: 45 min, moderate energy
- **Admin/Email**: 30 min, low energy

### 14.3 Recurring Routines

Routines are recurring time blocks that auto-populate the calendar:

**Attributes:**
- `name`: e.g., "Evening Study Session", "Morning Standup Prep"
- `days`: which days of the week
- `start_time`: preferred time (can be flexible — "anytime between 18:00-20:00")
- `duration`: in minutes
- `context`: work / study / personal
- `linked_discipline_id`: optional — rotate between disciplines automatically
- `template_id`: optional — apply a study/work template

**Behaviors:**
- Routines appear as suggested blocks during the morning plan. They're not hard-committed like class schedules — the user confirms or skips each day.
- A "rotation" routine cycles through disciplines: "Every weekday 19:00-21:00: study [Cálculo → Banco de Dados → Sinais → Constitucional → Review Day]."

---

## 15. Habits & Retention Mechanics

### 15.1 Streak Counter

- Tracks consecutive days where the user completed at least 1 time block (configurable: "at least 1 study block" or "at least 1 block of any type").
- Displayed prominently in the sidebar or nav bar.
- Streak milestones at 7, 14, 30, 60, 90, 180, 365 days with subtle visual celebrations (no gamification bloat — just a brief acknowledgment).
- A "freeze" mechanism: the user gets 1 streak freeze per week (skippable day without breaking the streak). Unused freezes don't accumulate.

### 15.2 Weekly Goals

- **Study hours goal**: "I want to study 20 hours this week."
- **Work hours goal**: "I want to log 30 work hours this week."
- A progress bar for each goal is visible in the sidebar throughout the week.
- At the end of the week, the review shows goal achievement and suggests adjustments: "You consistently hit 17-18 hours. Consider adjusting your goal to 18 hours for more realistic planning."

### 15.3 Daily Highlight

- During the morning plan, the user can optionally set a "daily highlight" — the single most important thing to accomplish today.
- The highlight is visually emphasized in the calendar and focus mode.
- In the daily review, the first question is: "Did you complete your highlight?" — tracked for a weekly highlight completion rate.

---

## 16. Notes System

### 16.1 Per-Discipline Notebook

Each discipline has a dedicated markdown notebook with:

- **Pages**: organized by topic or custom categories (e.g., "Aulas", "Resumos", "Fórmulas")
- **Markdown support**: headings, bold/italic, code blocks, LaTeX math (critical for engineering/science students), tables, links
- **Linked references**: notes can link to specific topics in the syllabus
- **Search**: full-text search across all notebooks

### 16.2 Session Notes

Notes captured during focus mode are:

- Attached to the specific time block
- Visible in the block's detail view
- Searchable
- Optionally appended to the discipline notebook after the session

### 16.3 Quick Notes

A global "scratch pad" accessible from anywhere in the app via a keyboard shortcut. Content here is unstructured and serves as a temporary holding area before the user organizes notes into the proper discipline notebook.

---

## 17. Quick Capture Inbox

### 17.1 Purpose

A universal inbox for capturing thoughts, tasks, and ideas without leaving the current context.

### 17.2 Access

- Available in Focus Mode as a small input field.
- Available globally via keyboard shortcut (`Ctrl+Shift+I` or similar).
- Available from a persistent floating button (optional, configurable).

### 17.3 Behavior

- The user types a quick thought and hits Enter. It's saved to the Inbox with a timestamp.
- No categorization required at capture time — the point is zero friction.
- During the morning plan or daily review, the user triages the inbox:
  - Convert to a work task (assign to a project)
  - Convert to a study block (assign to a discipline)
  - Convert to a note (move to a notebook)
  - Dismiss (delete)
- Inbox items older than 7 days without triage get a gentle reminder: "You have 5 unprocessed inbox items."

---

## 18. Export & Sharing

### 18.1 Weekly Summary Export

Generate a shareable summary of the week:

- Total hours by context
- Disciplines studied with hours per discipline
- Streak status
- Key accomplishments (from daily "wins")
- Format: PNG image (Instagram/WhatsApp-friendly), PDF, or Markdown

### 18.2 Study Schedule Export

- Export the weekly study plan as a PDF or image for printing or sharing with study groups.
- Export to `.ics` (iCalendar) format for importing into Google Calendar, Apple Calendar, etc.

### 18.3 Grade Report

- Per-semester grade summary exportable as PDF: all disciplines, evaluations, scores, final averages.

---

## 19. Settings & Personalization

### 19.1 General

- Theme: dark mode (default), light mode
- Language: Portuguese (BR) as default, English
- Timezone
- Week starts on: Monday / Sunday
- Date format: DD/MM/YYYY (default) / MM/DD/YYYY / YYYY-MM-DD

### 19.2 Planning

- Morning plan auto-open: on/off
- Daily shutdown reminder time
- Weekly plan day: Sunday or Monday
- Default block duration for new items
- Workload warning threshold (hours per day)

### 19.3 Focus

- Pomodoro defaults: work, short break, long break, sessions before long break
- Auto-start next Pomodoro: on/off
- Auto-start breaks: on/off
- Focus session completion prompt: on/off
- Ambient audio: on/off, default category

### 19.4 Notifications

- Morning plan reminder: time, on/off
- Upcoming block reminder: X minutes before, on/off
- Daily shutdown reminder: time, on/off
- Deadline warnings: 7-day, 3-day, 1-day, on/off
- Spaced repetition review reminders: on/off
- Streak at-risk warning: on/off

### 19.5 Energy Profile

- Configure energy levels per time slot (see section 13)
- Profile can be different for weekdays vs. weekends

### 19.6 Integrations (future)

- Google Calendar sync (read-only import of external events)
- Notion import (for existing study databases)
- GitHub/GitLab integration (auto-create work tasks from issues)

---

## 20. Implementation Roadmap

### Phase 1 — Core Loop (MVP)

**Goal:** Validate the Plan → Focus → Review cycle for the dual work+study user.

- User authentication (JWT via DRF)
- Workspace + Project + Task CRUD
- Semester + Discipline + Study Block CRUD
- Class schedule with auto-generated recurring blocks
- Unified calendar with day/week views
- Time blocking: drag-and-drop scheduling
- Focus mode with Pomodoro timer + day Kanban
- Session notes
- Daily review with rollover
- Basic sidebar stats (hours today, streak)

**Tech milestones:**
- Next.js app scaffold with app router
- DRF API with all core models
- Calendar component (react-big-calendar or @schedule-x/react)
- Drag-and-drop (dnd-kit)
- Pomodoro timer state management
- PostgreSQL schema with all Phase 1 models

### Phase 2 — Intelligence

**Goal:** Make Omakase smarter than a static planner.

- Grade tracker with projections and "what do I need" calculations
- Syllabus tracking with pace indicators
- Study Plan Generator (algorithm + UI)
- Spaced repetition engine with review suggestions
- Deadline aggregator with preparation estimates
- Energy mapping with scheduling warnings
- Weekly planning ritual
- Analytics: weekly dashboard with time distribution charts

### Phase 3 — Retention & Polish

**Goal:** Make Omakase sticky and delightful.

- Streak mechanics with freezes and milestones
- Weekly goals with progress bars
- Daily highlight feature
- Templates and routines (study session templates, recurring routines)
- Quick capture inbox
- Ambient audio in focus mode
- Per-discipline notebooks with markdown
- Consistency heatmap
- Export: weekly summary image, .ics export, grade report PDF

### Phase 4 — Exam Prep & Expansion

**Goal:** Serve the competitive exam market.

- Exam Prep Mode (Exam Plan + Subjects + Priority scoring)
- Mock exam tracking with score progression
- Auto-distribution of study hours by weight × proficiency
- Exam prep dashboard
- Long-term trend analytics (monthly, quarterly, semester-over-semester)

### Phase 5 — Integrations & Platform

**Goal:** Connect Omakase to the user's existing world.

- Google Calendar bi-directional sync
- Notion database import
- GitHub/GitLab issue sync
- Mobile responsive design or PWA
- Offline support for focus mode
- Collaborative features (study groups sharing schedules)
- API for third-party integrations

### Phase 6 — Native Apps

**Goal:** Deliver a native experience on mobile and desktop for fast, reliable access with platform-specific capabilities.

#### 6a. Mobile — iOS & Android

- Native iOS app (Swift/SwiftUI)
- Native Android app (Kotlin/Jetpack Compose)
- Shared REST API backend (same DRF API, no BFF needed initially)
- Push notifications for Pomodoro timer, upcoming time blocks, deadlines, and streak reminders
- Offline-first architecture: local persistence (Core Data / Room) with background sync
- Quick capture widget (iOS home screen widget, Android app widget)
- Focus mode with system-level Do Not Disturb integration
- Haptic feedback on timer events and task completion
- Biometric authentication (Face ID / fingerprint)
- Deep links for shared schedules and study blocks

#### 6b. Desktop — macOS

- Native macOS app (Swift/SwiftUI, AppKit where needed)
- Menu bar companion: quick timer controls, next time block preview, quick capture
- Full app window with sidebar navigation (mirrors web layout)
- Native keyboard shortcuts and macOS menu integration
- System notifications for Pomodoro transitions and upcoming blocks
- Global hotkey for quick capture (e.g. `⌥⌘N` to add a task from anywhere)
- Spotlight integration for searching tasks and study blocks
- Calendar.app integration via EventKit
- Auto-launch on login option
- Handoff support between macOS and iOS apps

#### Native App Strategy

- **API-first**: All native apps consume the same `/api/v1/` endpoints — no app-specific backend changes
- **Offline sync**: Conflict resolution strategy using last-write-wins with server timestamps; critical operations (task completion, timer state) queue and retry
- **Authentication**: Same JWT flow with secure keychain/keystore storage (no localStorage)
- **Shared design language**: Monochrome palette and Outfit font carry over, but respect platform conventions (SF Symbols on Apple, Material icons on Android)
- **Release cadence**: Web-first for new features, native apps follow after API stabilization

---

> **Note on scope**: This document describes the complete vision. The MVP (Phase 1) should be shippable within 6-8 weeks for a solo developer working part-time, or 3-4 weeks full-time. Each subsequent phase adds 3-5 weeks. Resist the temptation to build everything at once — validate the core loop first, then layer intelligence on top of proven usage patterns.