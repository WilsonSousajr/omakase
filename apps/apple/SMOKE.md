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

