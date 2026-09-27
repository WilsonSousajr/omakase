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
