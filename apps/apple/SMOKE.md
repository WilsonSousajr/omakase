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
