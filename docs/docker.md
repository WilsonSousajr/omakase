# Docker Configuration

## Multi-Stage Build Strategy

The backend Dockerfile uses a multi-stage build to serve two purposes from one file:

### Backend (`backend/Dockerfile`)

| Stage  | Base Image        | Purpose                          | Size   |
|--------|------------------|----------------------------------|--------|
| `base` | python:3.12-slim | pip install + source copy        | ~350MB |
| `dev`  | base             | Adds dev deps + `runserver`      | ~386MB |
| `prod` | base             | `collectstatic` + gunicorn       | ~350MB |

## Security

- **Backend prod:** runs as `django` user (UID 1001)
- Dev stage runs as root (needed for bind mount compatibility)

## `.dockerignore`

**Backend excludes:** `.coverage`, `.pytest_cache/`, `.ruff_cache/`, `htmlcov/`

**Important:** Backend `.dockerignore` does NOT exclude `conftest.py`, `*/tests/`, or `requirements-dev.txt` because `.dockerignore` applies to the entire build context (not per-stage). The `dev` stage needs `requirements-dev.txt` for its explicit `COPY` instruction, and test files are needed for `COPY . .` in the base stage.

## Production Compose

`docker-compose.prod.yml` provides production overrides:

```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up
```

This targets the backend `prod` stage and swaps `runserver` for gunicorn.

> **Note:** docker-compose v1 (Python) merges volume sequences rather than replacing them. For true production deployment, build images with `--target prod` and run directly with `docker run`.

## CI Guardrails

Two CI jobs prevent Docker regressions:

1. **`docker-lint`** — runs hadolint on the backend Dockerfile (catches anti-patterns like missing `--no-cache-dir`, inefficient layer ordering, etc.)
2. **`docker-build`** — builds the backend prod image

## Key Design Decisions

- **`collectstatic` with `|| true`** — allows the build to succeed even without database access or if no static files exist yet.

## History

- The Next.js frontend (and its `frontend/Dockerfile`, standalone prod stage, and 500MB image-size CI guard) was removed on branch `chore/remove-frontend`. Recover it from git history if a web client is reintroduced.
