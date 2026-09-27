# M6 Production: design

**Status:** decided 2026-09-27 with the user. **Prepared, not promoted**:
the run ends at the develop→main promotion PR. Merging it deploys, and it
and the tag are the user's.
**Milestone:** M6 (`docs/ROADMAP.md`): "your data anywhere. Promote
`develop` to `main`, make the VPS serve the API alone (proxy, CORS), point
the app at it, and run the parity checklist."

## Decisions (with the user)

- **The API deploys on Coolify.** Coolify builds from the repo, runs the
  containers, and terminates TLS with its own proxy. The repo carries no
  proxy config, and the backend publishes no host port in production.
- **`deploy.yml`'s SSH deploy goes.** It pulled and ran compose on the VPS
  on every push to `main`. With Coolify deploying `main` too, the two
  would race. CI (`ci.yml`) is unchanged.
- **The Mac's production URL is a placeholder**, set in a release
  xcconfig for the user to fill in before a release build. Debug builds
  keep `http://localhost:8000`.
- **The release is `v0.1.0`**, 0.x until the in-app smoke runs pass. No
  tag exists yet.

## 1. Backend for Coolify (PR P1)

- **Migrations at start.** The prod image's command runs
  `migrate --noinput`, then `exec gunicorn`, through a small
  entrypoint script. `deploy.yml` used to run them as a separate step.
- **`GET /api/health/`**, `AllowAny`. It returns 200 `{"status": "ok"}`
  when the database answers `SELECT 1`, and 503 `{"status": "unavailable"}`
  otherwise. It is what Coolify's health check calls.
  - It is `AllowAny` because it reveals nothing: no user, no data, no
    version. The PR argues this, as AGENTS.md asks of every `AllowAny`.
- **CORS defaults to no origins.** The native clients send no `Origin`,
  and the web client is gone, so the old `localhost:3000` default only
  widens what a misconfigured deploy would allow. Explicit origins still
  come from the environment (invariant 7).
- **`docker-compose.coolify.yml`:** `backend` (prod target, no host port,
  env passthrough) and `db` (Postgres 16 with a volume). Coolify assigns
  the domain to `backend:8000`.

## 2. CI (PR P2)

- Remove `.github/workflows/deploy.yml`.
- `AGENTS.md`, `docs/docker.md` and a new `docs/deploy-coolify.md`
  describe the Coolify setup:
  - the build pack and compose file
  - the environment variables
  - the domain
  - the health check path
  - that `main` is what deploys

## 3. The app (PR P3)

- `apps/apple/Config/Release.xcconfig` sets `OMAKASE_API_BASE_URL` to
  `https://api.example.invalid`. `.invalid` is reserved (RFC 2606), so a
  release build that nobody filled in fails to connect, instead of
  reaching someone else's server. `project.yml` uses it for Release.
- `SMOKE.md`'s Setup notes how to point a build at production.

## 4. The release (PR P4, then the promotion)

- **`docs/parity-checklist.md`:** each web page and feature (from `074d353`'s
  removal) next to its Mac equivalent, with the PR and the smoke section
  that proves it.
- **`CHANGELOG.md`:** `Unreleased` becomes `[0.1.0] - <date>`.
- **The promotion PR** is develop → `main`, left open for the user.

## Verification

- **P1:** tests first.
  - Health returns 200 with the database up, and 503 with it down (a
    patched cursor).
  - The entrypoint is linted.
  - The CORS default is tested, empty when the environment sets nothing.
- **Real stack:** build the prod image, run it against the dev database
  with `DEBUG=False`, and `curl /api/health/`.
- The gate is green on every PR.
