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

