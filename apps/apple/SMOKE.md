# Smoke checklist - the real app against the real local stack

The gate proves units; this proves the wiring (AGENTS.md "necessary, not
sufficient"). Run it at the end of every milestone and paste the result into
the milestone's closing PR.

## Setup

1. `docker-compose up -d`. The backend's `GOOGLE_CLIENT_IDS` includes the
   macOS client ID.
2. The macOS OAuth client is a Google Cloud OAuth client of type **iOS**,
   bundle id `dev.omakase.mac`. Its ID goes in
   `apps/apple/Config/Local.xcconfig` (gitignored):
   `OMAKASE_GOOGLE_CLIENT_ID = <id>.apps.googleusercontent.com`
3. `cd apps/apple && ./install-tools.sh && .tools/bin/xcodegen generate`,
   then open `Omakase.xcodeproj` and Run.

## M1

1. Sign in with Google. Today shows today's tasks. If there are none, create
   one first with `POST /api/v1/tasks/` and `scheduled_date` set to today.
2. `docker-compose stop backend`. Today still shows them.
3. Check one task complete. It shows completed. Quit and relaunch the app:
   it's still completed.
3b. Quit the app, and relaunch it with the backend still stopped. Today
    shows the cached tasks, not the sign-in screen. Stored tokens decide
    whether you're signed in; only the server saying otherwise signs you out.
4. `docker-compose start backend`. Within seconds (reachability) or 5
   minutes (the timer), the server has it:
   `curl -H "Authorization: Bearer <token>" "localhost:8000/api/v1/tasks/today/?date=<today>"`
5. Uncheck it while offline, then go online. The server ends uncompleted:
   two PATCHes, sent in order.

Known M1 limitation: the Today window keeps the day it was opened on until
relaunch. M3's Today recomputes it when the app becomes active.

## M2

Run with the built app, against the same stack as M1.

1. The Dock shows the ensō icon: an ink brush circle on sumi.
2. The window opens dark and its ground is translucent: move it over a
   bright wallpaper, and the desktop tints through while text stays sharp.
3. Signed out: the `OMAKASE` wordmark, "Plan. Focus. Ship.", and a light ink
   pill "Sign in with Google". There is no red and no blue.
4. Signed in: the sidebar shows Focus, which holds today's list. Each row
   has a checkbox, a title and a priority pill.
5. Checkboxes and the sidebar selection are grey.
6. System Settings → Appearance → Light: the ground turns to paper, and
   everything stays readable.
7. No hard-coded style outside the tokens. This prints nothing:
   `grep -rnE 'Color\(red|\.padding\([0-9]|0x[0-9A-Fa-f]{6}' apps/apple --include='*.swift' | grep -v -e '/Design/' -e '/Tests/' -e '/.build/'`
8. The M1 checklist above passes again.

## M3.2

Focus, against the same stack. Seed through the API or the Django admin
first:
- three tasks scheduled today, with different priorities, one with a due
  date two days out and one with subtasks
- one task scheduled yesterday and not done, so it is carried over

1. The Focus sidebar item opens the Kanban board.
   - To do lists the carried task first, marked "from <weekday> <day>".
   - The task with a deadline shows "Due <weekday> <day>".
2. Switch to List: the sections are Carried over, To do, and so on. Quit and
   relaunch: List is remembered.
3. Click a task. The right panel shows its title, marks, subtasks, Complete
   and Reschedule.
4. Check a subtask. `curl …/tasks/<id>/` shows it `is_completed: true`.
5. Drag a card to Done: it completes. Drag it back to To do: it reopens.
   The server agrees each time (`curl …/tasks/today/?date=<today>`).
6. Reschedule a task to Tomorrow: it leaves the board, and the server has
   tomorrow's `scheduled_date`. Reschedule another to Backlog: the server
   has `"scheduled_date": null`.
7. Carried task, then Move to today: it moves into To do without the mark.
8. Stop the backend. Drag a card to In progress, then start the backend:
   the move replays, and the server has `kanban_status: "in_progress"`.
9. Leave the app open past midnight, or change the Mac's date, and
   reactivate it. The header shows the new day.

## M3.3

The timer, against the same stack. Use short durations: set the profile to
2/1/1 minutes with 2 before a long break (`PATCH /api/v1/auth/profile/`),
and give one of today's tasks a time block covering now.

1. Select that task and click Start focus. The disc counts down in shu, and
   the menu bar shows the countdown.
2. Pause, wait, then Resume: the paused time isn't counted. Quit the app
   while it's running, relaunch: the remaining time is right.
3. Let it run out, with the window hidden. A notification says "Focus done",
   and the sheet asks for a rating and notes, prefilled with the checked
   subtasks. Save.
   - The server has a session with the Mac's `started_at` and the block's
     `time_block`: `curl …/pomodoro/sessions/`.
   - The block has the rating and notes: `curl …/timeblocks/?date=<today>`.
4. The next phase is a short break, and it waits for Start. After two
   focuses, the break is the long one.
5. Start a focus and quit the app. Relaunch after it would have ended: the
   session is recorded, ending when it was due.
6. Skip a focus after a minute: a session with `completed: false` and the
   elapsed minutes. Skip within a minute: no session.
7. Offline (backend stopped): finish a focus, then start the backend. The
   session replays.
8. The menu-bar panel shows the next block and what's left today. Clicking a
   task focuses it in the window.


## M3.4

Review and shutdown, against the same stack. Seed three tasks scheduled
today, none done, two of them with `estimated_minutes`, and set the profile's
daily goals low enough (`PATCH /api/v1/auth/profile/`) that today's plan goes
over. `<today>` and `<tomorrow>` are the Mac's local dates.

1. The Focus header shows the workload line: planned against the goal, over,
   and partial because one task has no estimate.
   `curl …/stats/workload/?date=<today>` has the same `planned_minutes`,
   `goal_minutes` and `unestimated_count: 1`.
2. Complete one task, then open Review from the sidebar. The summary says
   "1 of 3 done"; the two open tasks are listed, each set to Tomorrow.
3. Rate the day, choose an energy and type a win. Pause a second, then
   `curl …/stats/reviews/?date=<today>`: the rating, `energy` and
   `win_of_the_day` are there, and `is_shutdown` is false.
4. Set one open task to Backlog; leave the other on Tomorrow. The hint under
   Shut down says "Moves 2 tasks and closes the day".
5. Shut down. The screen shows Day closed, "Great work today. Time to
   rest." and Reopen; the rollover rows are gone.
   - `curl …/stats/reviews/?date=<today>`: `is_shutdown: true` and
     `shutdown_at` set.
   - `curl …/tasks/<id>/` for each task: `"scheduled_date": "<tomorrow>"`
     for the first, `"scheduled_date": null` for the second.
6. Reopen. `curl …/stats/reviews/?date=<today>` has `is_shutdown: false`;
   the tasks stay where they moved.
7. Offline (backend stopped): add a task for today, shut down again, then
   start the backend. The review replays first, then the task's move.

## M3.5

Capture and offline, against the same stack. The toolbar indicator is the
indicator PR's (#185); capture is #186. `<today>` is the Mac's local date,
and `curl …` is `curl -H "Authorization: Bearer <token>" localhost:8000/api/v1`.

1. Signed in with the backend up and nothing queued, the toolbar shows a
   quiet `checkmark.icloud`.
2. `docker-compose stop backend`. The indicator turns to `icloud.slash`.
3. Switch to another app (Finder, say) and press ⌥⌘N. The capture panel
   floats over it, centred on the top third of the screen, with the field
   focused and the footer reading Today and "⏎ Today · ⌘⏎ Inbox · ⎋
   dismiss".
   - Type "Smoke capture today" and press ⏎. The panel closes and focus goes
     back to Finder. The task is on Focus at once.
   - ⌥⌘N again, type "Smoke capture inbox" and press ⌘⏎. It saves with no
     date, so Focus doesn't show it.
   - ⌥⌘N, type something, press ⎋: nothing is saved, and the next ⌥⌘N opens
     empty. ⏎ on an empty field saves nothing and leaves the panel open.
4. The indicator shows the queued count, 2.
5. `docker-compose start backend`. Within seconds the count drains to 0 and
   the indicator is back to `checkmark.icloud`.
   - `curl "…/tasks/today/?date=<today>"` has "Smoke capture today".
   - `curl "…/tasks/?search=Smoke%20capture%20inbox"` has it with
     `"scheduled_date": null`.
6. File > Capture Task… (⌥⌘N) opens the same panel while the app is active.
7. Force a park: `curl -X DELETE "…/tasks/<id>/"` for one of today's tasks,
   then complete it in the app before the next catch-up. The PATCH gets a
   404 and parks: the indicator shows `exclamationmark.icloud`.
8. Click it. The failed-writes sheet lists the write with the server's
   message. Retry sends it again and it parks again; Discard removes it, and
   the indicator returns to `checkmark.icloud`.

## M3.6

Reminders, against the same stack. The profile keeps its defaults: a
5-minute heads-up before blocks and no shutdown reminder. `<today>` is the
Mac's local date, and `curl …` is `curl -H "Authorization: Bearer <token>"
localhost:8000/api/v1`. Allow notifications when macOS asks.

1. Select one of today's tasks and choose Remind me > In 1 hour. A bell
   shows on its card and row.
   - `curl "…/tasks/<id>/"` has `remind_at` about an hour from now, in UTC.
2. Move it to a minute from now:
   `curl -X PATCH -H "Content-Type: application/json" -d '{"remind_at":"<now+1min, ISO-8601 with offset>"}' "…/tasks/<id>/"`.
   After the next refresh (reopen the app, or reconnect), the notification
   arrives with the task's title.
3. Create a time block for one of today's tasks starting in about 7 minutes:
   `curl -X POST -H "Content-Type: application/json" -d '{"task":"<id>","date":"<today>","start_time":"<now+7min>","end_time":"<now+37min>"}' "…/timeblocks/"`.
   After the next refresh, a heads-up arrives 5 minutes before it starts:
   the task's title, "Starts in 5 min, at <time>".
4. Remind me > Clear on the task. The bell goes.
   - `curl "…/tasks/<id>/"` has `"remind_at": null`.
5. Set `shutdown_reminder_time` a few minutes ahead
   (`PATCH …/auth/profile/`), refresh, and shut the day down in Review
   before it fires: no shutdown reminder arrives.

## M4

Plan, against the same stack. `<today>` and `<tomorrow>` are the Mac's
local dates, and `curl …` is `curl -H "Authorization: Bearer <token>"
localhost:8000/api/v1`. Seed first:
- three tasks scheduled today, "Essay", "Review PR" and "Reply to Ana"
- a class on today's weekday, through the API: a semester, a discipline
  with a colour, then its schedule:
  `curl -X POST -H "Content-Type: application/json" -d '{"name":"Term","start_date":"<a month ago>","end_date":"<in two months>"}' "…/study/semesters/"`,
  `curl -X POST -H "Content-Type: application/json" -d '{"semester":"<id>","name":"Linear algebra","color":"#4F46E5"}' "…/study/disciplines/"`,
  `curl -X POST -H "Content-Type: application/json" -d '{"discipline":"<id>","day_of_week":<0 is Monday>,"start_time":"08:00","end_time":"09:30"}' "…/study/classschedules/"`

1. Plan opens on today with 08:00 at the top, or, after 09:00, the hour
   before the now line (#215). Press › : tomorrow opens at 08:00. Press
   Today. Switch to Week: seven columns, Monday first, with today's header
   in ink and the shu now line on its column. Back to Day.
2. The class sits at 08:00-09:30 behind the grid, dashed with a book glyph,
   in indigo. It can't be dragged.
3. Drag "Essay" from the column onto 10:00. A 10:00-11:00 block appears at
   once.
   - `curl "…/timeblocks/?date=<today>"` has it, `10:00:00`-`11:00:00`.
   - `curl "…/tasks/<id>/"` has `"scheduled_date": "<today>"`.
4. Week view: drag the block onto tomorrow's column at 14:00. It moves,
   still an hour long and still titled "Essay", although the task leaves
   the column.
   - `curl "…/timeblocks/?date=<tomorrow>"` has it at `14:00:00`.
   - The task's `scheduled_date` is `<tomorrow>`.
5. Drag the block's bottom edge down 30 minutes: it grows as you drag, in
   15-minute steps, and ends 90 minutes long. `curl` has `15:30:00`.
6. Drag "Review PR" onto tomorrow at 14:30. The dialog says "Overlaps
   Essay. Place anyway?". Cancel: nothing is created. Drag it again and
   Place anyway: the two blocks stand side by side.
7. Right-click the "Review PR" block, Delete block: it goes, and
   `curl "…/timeblocks/?date=<tomorrow>"` no longer lists it.
8. `docker-compose stop backend`. Drag "Reply to Ana" onto today at 16:00: the
   block shows at once and the toolbar says a write is pending.
   `docker-compose start backend`; after the catch-up, `curl
   "…/timeblocks/?date=<today>"` lists exactly one 16:00 block
   (the replayed create is idempotent, #199).
9. Select "Essay" in Focus and run a focus session to the end (or shorten
   the profile's pomodoro to 1 minute). Back in Plan, a thin grey lane is
   drawn beside the block at the times it ran. Breaks are not drawn.
10. Click "Reply to Ana" in the task column: it gets a 2-pt grey border
    (never red) and a panel opens on the right with its title, marks and
    Complete, Reschedule and Remind me, as in Focus but without the timer.
    Dragging the row onto the grid still makes a block. Reschedule to
    Tomorrow: the row leaves the column, the panel stays, and `curl
    "…/tasks/<id>/"` has `"scheduled_date": "<tomorrow>"`.
11. Click the "Essay" block: the border moves to it and the panel shows
    "Essay", its day and times, Open task and Delete block. Drag the block
    by its body and resize it by its bottom edge: both still work.
    Open task: the panel shows the Essay task. Complete it: the button
    reads Reopen and `curl` has `"is_completed": true`. Reopen it.
12. Select the block again and Delete block: the block and the panel go
    at once. Click another block, then an empty slot, or press Escape:
    the panel closes.
13. Double-click "Reply to Ana" in the column: the task editor (#218)
    opens on it. Change its title and Save: the row, the panel and any of
    its blocks show the new title. Double-click one of its blocks, or
    select the block and press Return: the editor opens on its task.
    Escape closes it and nothing is sent. Focus's selection is unchanged.

### Edit a task (#218)

1. In Focus, double-click one of today's tasks (or select it and press
   Return, or choose Edit…). The editor opens on its current values.
2. Change the title, set the priority to Urgent, the estimate to 45 minutes
   and a due date, then Save (⌘Return). The row and card show the changes
   at once, offline too.
   - `curl "…/tasks/<id>/"` has the new `title`, `"priority": "urgent"`,
     `"estimated_minutes": 45` and the `due_date`.
3. Open it again, empty the estimate field, turn Due date off and Save.
   - `curl "…/tasks/<id>/"` has `"estimated_minutes": null` and
     `"due_date": null`.
4. Open it, blank the title: Save stays disabled. Escape closes the editor
   and nothing is sent.

## M5 - Calendar.app overlay

Plan, with Calendar.app holding an event today at 11:00-12:00 ("Dentist")
and one crossing midnight tonight (23:00-01:00). Start from a clean
permission: `tccutil reset Calendar dev.omakase.mac` and
`defaults delete dev.omakase.mac omakase.calendarOverlay`.

1. Plan's header shows a "Calendar" toggle, off. The grid has no events.
2. Turn it on: the system asks for calendar access with "Omakase shows
   your calendar's events behind your plan. It never changes them."
   Allow. "Dentist" appears at 11:00-12:00, dashed and muted, behind any
   block there, in its calendar's colour on the stroke only.
3. Drop a task onto 11:00: the block sits over the event and no
   "Overlaps" dialog appears. The event can't be dragged or resized.
4. Week view: the late event shows 23:00-24:00 tonight and 00:00-01:00
   tomorrow. An all-day event is not drawn.
5. Quit and relaunch: the toggle is still on and the events are back.
6. Turn it off: the events go. Relaunch: still off.
7. Deny: `tccutil reset Calendar dev.omakase.mac`, turn it on, choose
   Don't Allow. The toggle stays off and a popover says "Omakase needs
   access in System Settings > Privacy > Calendars".

## M8 - Cancelled classes

Plan, against the same stack, with `curl …` as in M4. Seed the class of
M4 on today's weekday (a semester, a discipline, a schedule through
`…/study/classschedules/`), and note the schedule's `<id>`.

1. Plan shows the class at 08:00-09:30, dashed, in its colour.
2. Right-click it: the menu offers "Cancel this class". Choose it. The
   class stays where it is, dimmed, its title struck through, behind any
   block.
   - `curl "…/study/class-occurrences/?date_from=<today>&date_to=<today>"`
     has it with `"is_cancelled": true`.
3. Right-click it again: the menu offers "Restore class". Choose it. The
   class is drawn as before, and `curl` has `"is_cancelled": false`.
4. Cancel it, then press ›, then Today: it is still struck through.
5. Restore it. `docker-compose stop backend`. Cancel it: it is struck
   through at once and the toolbar says a write is pending.
   `docker-compose start backend`; after the catch-up it is still struck
   through, `curl` has `"is_cancelled": true`, and the database has one
   cancellation for the date:
   `docker-compose exec db psql -U omakase -c "select count(*) from study_classcancellation where class_schedule_id = '<id>'"`
   is 1.
6. Restore it online. Offline again, cancel it and restore it before
   reconnecting: the toolbar shows nothing pending, because the two
   writes cancel out. Reconnect: `curl` has `"is_cancelled": false` and
   the count in 5 is 0.

## M8 - Recurring tasks

Focus, with one task "Gym" scheduled today and no other series. `D` is
today, `D+7` the same weekday next week.

1. Select "Gym". The panel's third row has a "Repeat" menu in ink. Choose
   "Weekly on <today's weekday>". A repeat glyph appears on its row or card.
   - `curl "…/tasks/<id>/"` has `"series": "<template id>"`,
     `"occurrence_date": "D"` and `"recurrence": {"freq": "weekly",
     "interval": 1, "weekdays": [<today>], "starts_on": "D", "until": null}`.
2. Next week's occurrence is computed, not stored.
   - `curl "…/tasks/today/?date=D+7"` has one item with `"id": null`,
     `"is_virtual": true` and `"series": "<template id>"`.
   - `curl "…/tasks/occurrences/?date_from=D&date_to=D+7"` lists the row
     on D and the virtual item on D+7; Plan reads the same for its week.
3. On D+7 (or with the Mac's clock set to it), complete the virtual "Gym"
   in Focus. It shows done at once, offline too.
   - `curl "…/tasks/today/?date=D+7"` has one item for it, now with an
     `id`, `"is_virtual": false`, `"occurrence_date": "D+7"` and
     `"is_completed": true`: one concrete row, not two.
   - Completing it again (Reopen) patches that row; no second row appears.
4. Choose Repeat > "Stop repeating". Future virtual occurrences leave the
   store at once.
   - `curl "…/tasks/<id>/"` has `"recurrence": {…, "until": "<D+7 - 1>"}`
     (the day before the Mac's today), and
     `curl "…/tasks/today/?date=D+14"` has no "Gym".
5. Offline, complete a virtual occurrence, then go online: the failed
   writes sheet stays empty. Had the server refused it, the sheet would say
   "Save repeating task", and Discard brings the occurrence back as it was
   on the next refresh.

## M5 - Inbox

The Inbox is every open task with no day (#225). Capture two tasks with
⌥⌘N, then ⌘⏎, so they land here, and note one task's `<id>` from
`curl "…/tasks/?unscheduled=true"`.

1. The sidebar shows Inbox with a badge of 2, and the screen lists both,
   newest first.
2. On one, press Today. It leaves the Inbox, and the badge drops to 1.
   It is in Focus's list.
   - `curl "…/tasks/<id>/"` has `"scheduled_date": "<today>"`.
3. On the other, use the ⋯ menu's Pick a date…, choose next Friday,
   and press Move. It leaves the Inbox.
   - `curl` has that date.
4. Capture a third to the Inbox. Double-click it, change the title, and
   save. The row shows the new title.
   - `curl` has it.
5. Right-click it, then Delete…. The dialog asks first. Confirm, and it
   is gone.
   - `curl "…/tasks/<id>/"` is a 404.
6. Offline (`docker-compose stop backend`), capture one to the Inbox and
   delete it before reconnecting. The toolbar shows nothing pending,
   because the unsent capture was withdrawn. Reconnect, and the server
   never had it.

## M5 - Settings

Settings is the ⌘, window (#228). Each change saves a moment after the
last one. `curl "…/auth/profile/"` shows what the server has.

1. The Account tab shows "Signed in as <your email>".
2. General: set Week starts on to Sunday.
   - `curl` has `"week_starts_on": "sunday"`.
3. Focus: set Focus to 50 min, and Work to 6h 30m.
   - `curl` has `"pomodoro_work_minutes": 50` and
     `"daily_work_goal_hours": "6.5"`.
   - Start a focus session: the timer counts down from 50:00.
4. Reminders: turn Heads-up off.
   - `curl` has `"block_reminder_minutes": null`.
   Turn it on and set 10 minutes: `curl` has `10`.
5. Reminders: turn on the shutdown reminder and set 21:30.
   - `curl` has `"shutdown_reminder_time": "21:30:00"`.
6. `docker-compose stop backend`, then change Focus to 45. Within a
   moment it goes back to 50, and the foot says "Needs a connection."
   Start the backend again.
7. General: turn on Open at login. It appears in System Settings >
   General > Login Items. Turn it off, and it goes.
8. Account: Sign Out…. The dialog names any unsent changes. Confirm, and
   the window returns to sign-in.
   - `curl -X POST …/auth/token/refresh/` with the old refresh token is
     a 401: it was revoked.

## M5 - Projects

Workspaces and projects, written online (#226). `curl "…/workspaces/"`
and `curl "…/projects/"` show what the server has.

1. Open Projects. The list shows All, then your workspaces; the grid shows
   every project.
2. New Workspace…, then "Clients". It appears, and `curl` lists it with a
   colour.
3. Select it, then New Project…, then "Site". The card shows "Active · 0
   tasks" and a colour bar.
   - `curl "…/projects/?workspace=<id>"` has it, with `"status": "active"`.
4. Right-click the card, then Status, then Paused. The card says Paused,
   and so does `curl`.
5. Right-click the card, then Rename…, then "Website". Both show the new
   name.
6. Right-click the workspace, then Delete…. The dialog says its projects
   go too and their tasks stay. Confirm, and both are gone from the
   screen and from `curl`.
7. `docker-compose stop backend`, then create a workspace. Nothing
   appears, and the foot says "Needs a connection." Start the backend
   again.

## M5 - Study

Semesters, disciplines, class schedules and holidays, written online
(#227). `curl "…/study/semesters/"` and the other lists show what the
server has.

1. Open Study. The semester today falls in is selected, or the next to
   start, or the latest.
2. New Semester…: name it "Fall", leave the dates, set Rotation to 2
   weeks, and Save.
   - `curl` has `"rotation_weeks": 2`.
3. Try to save a semester that ends before it starts. The form stays
   open and says so, and nothing is sent.
4. New Discipline… "Calculus" with a colour. Select it, then New Class…:
   Monday 10:00-11:40, Lecture, Week 1 only.
   - `curl "…/study/classschedules/"` has `"rotation_weeks_on": [1]`.
   - Plan shows the class on week-1 Mondays only
     (`curl "…/study/class-occurrences/?date_from=…&date_to=…"`).
5. New Holiday… covering a week-1 Monday. On Plan, that Monday has no
   class.
6. Delete the semester. The dialog says its disciplines, their classes
   and its holidays go too. Confirm, and all of them are gone from the
   screen and from `curl`.
