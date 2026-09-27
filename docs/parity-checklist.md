# Parity checklist

M5's promise (`docs/ROADMAP.md`): "After M5 the web client is not missed."
Each row is a page or feature of the web client removed in `074d353` (#62),
the Mac screen that replaces it, the PR that built it, and the `SMOKE.md`
section that proves it in the real app. **Checked** is ticked when that
section passes against the stack being released.

## Pages

| Web | Mac | PR | Smoke | Checked |
|---|---|---|---|---|
| Login (Google) | Sign-in screen, Google PKCE | #92-#98 | M1 | [ ] |
| Focus: task list and Kanban | Focus, list and board | #159, #160 | M3.2 | [ ] |
| Focus: active-task panel, subtasks | Focus panel | #160 | M3.2 | [ ] |
| Pomodoro timer, session completion | Timer, end-of-focus prompt, menu-bar timer | #165-#167 | M3.3 | [ ] |
| Plan: day and week calendar | Plan | #205, #208 | M4 | [ ] |
| Plan: drag to create, move, resize; overlap warning | Plan | #209, #212 | M4 | [ ] |
| Plan: class blocks, current-time line | Plan (classes behind, the now line) | #205, #208 | M4 | [ ] |
| Review: summary, rollover, score, win, shutdown | Review | #181, #189 | M3.4 | [ ] |
| Projects: workspaces, projects | Projects | #241 | M5 - Projects | [ ] |
| Study: semesters, disciplines, class schedules | Study | #242 | M5 - Study | [ ] |
| Settings: profile, week start, pomodoro, goals, log out | Settings (⌘,) | #240, #238 | M5 - Settings | [ ] |
| Task form | Task editor | #222 | M4 (Edit a task) | [ ] |

## Beyond the web client

What the Mac has that the web never did, from M7's findings.

| Feature | PR | Smoke | Checked |
|---|---|---|---|
| Offline writes, the sync indicator, failed writes | #155, #190, #197 | M3.5 | [ ] |
| ⌥⌘N capture from anywhere, the Inbox | #195, #239 | M3.5, M5 - Inbox | [ ] |
| Workload check, energy on the review | #182, #188, #181 | M3.4 | [ ] |
| Reminders: block heads-up, task reminders, shutdown | #191, #198 | M3.6 | [ ] |
| Recurring tasks, computed on the server | #232, #237 | M8 - Recurring tasks | [ ] |
| Week A/B rotation, holidays, cancelled classes | #210, #211, #235 | M8 - Cancelled classes, M5 - Study | [ ] |
| Calendar.app overlay (read-only) | #231 | M5 - Calendar.app overlay | [ ] |
| Launch at login | #240 | M5 - Settings | [ ] |

## Not carried over, on purpose

| Web | Why |
|---|---|
| The Morning Plan wizard | It needs its own design; Plan and the workload check cover placing the day (M5 spec). |
| Markdown notes in focus | Not rebuilt; session notes are plain text on the block (#166). |
| Tag management | The web had a hook and no screen. |
| A project's task list | Tasks aren't cached by project; a follow-up (#241). |
| A discipline's study blocks, credits and target grade | Follow-ups (#242). |
| First and last name editing | Account shows the email only; a follow-up (#240). |

## Production

| Check | Where | Checked |
|---|---|---|
| Coolify resource, variables, health path | `docs/deploy-coolify.md` (#244) | [ ] |
| `GET /api/health/` answers 200 over HTTPS | #247 | [ ] |
| A release build points at the domain | `apps/apple/Config/Release.xcconfig` (#249) | [ ] |
| Sign in against production, then run M1 and M3.2 there | `SMOKE.md` | [ ] |
