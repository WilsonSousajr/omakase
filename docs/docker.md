# Docker Configuration

## Multi-Stage Build Strategy

Both Dockerfiles use multi-stage builds to serve two purposes from one file:

### Frontend (`frontend/Dockerfile`)

| Stage     | Base Image       | Purpose                                  | Size     |
|-----------|-----------------|------------------------------------------|----------|
| `base`    | node:22-alpine  | pnpm setup + workdir                     | ~190MB   |
| `deps`    | base            | `pnpm install` (cached layer)            | ~1.5GB   |
| `dev`     | deps            | Hot reload via `pnpm dev`                | ~1.5GB   |
| `builder` | deps            | `pnpm build` (generates standalone)      | ~1.6GB   |
| `prod`    | node:22-alpine  | Standalone server + static assets only   | ~200-250MB |

The `prod` stage starts from a **fresh** `node:22-alpine` — no pnpm, no `node_modules`, no source code. It copies only:
- `.next/standalone/` — self-contained Node.js server (~60MB, includes traced dependencies)
- `.next/static/` — pre-built static assets (~27MB)

This works because `next.config.ts` has `output: "standalone"` configured.

### Backend (`backend/Dockerfile`)

| Stage  | Base Image        | Purpose                          | Size   |
|--------|------------------|----------------------------------|--------|
| `base` | python:3.12-slim | pip install + source copy        | ~350MB |
| `dev`  | base             | Adds dev deps + `runserver`      | ~386MB |
| `prod` | base             | `collectstatic` + gunicorn       | ~350MB |

## Security

- **Frontend prod:** runs as `nextjs` user (UID 1001, `nodejs` group)
- **Backend prod:** runs as `django` user (UID 1001)
- Dev stages run as root (needed for bind mount compatibility)

## `.dockerignore` Files

Both services exclude test files and dev tooling from the build context:

**Frontend excludes:** `coverage/`, `src/test/`, `src/**/__tests__/`, `vitest.config.ts`, `.pnpm-store/`, `tsconfig.tsbuildinfo`, `eslint.config.mjs`

**Backend excludes:** `.coverage`, `.pytest_cache/`, `.ruff_cache/`, `htmlcov/`, `conftest.py`, `*/tests/`, `requirements-dev.txt`

Safe for dev because `docker-compose.yml` uses bind mounts (`./backend:/app`, `./frontend:/app`) which override image contents at runtime.

## Production Compose

`docker-compose.prod.yml` provides production overrides:

```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up
```

This targets `prod` stages, passes `NEXT_PUBLIC_API_URL` as a build arg, and overrides dev commands.

> **Note:** docker-compose v1 (Python) merges volume sequences rather than replacing them. For true production deployment, build images with `--target prod` and run directly with `docker run`.

## CI Guardrails

Two CI jobs prevent Docker regressions:

1. **`docker-lint`** — runs hadolint on both Dockerfiles (catches anti-patterns like missing `--no-cache-dir`, inefficient layer ordering, etc.)
2. **`docker-build`** — builds both prod images and verifies the frontend image stays under 500MB (expected ~200-250MB, threshold is generous to avoid flaky failures)

## Key Design Decisions

- **`deps` stage shared by `dev` and `builder`** — maximizes Docker layer cache. Dependencies only reinstall when `package.json` or `pnpm-lock.yaml` change, not when source code changes.
- **`NEXT_PUBLIC_API_URL` as build arg** — Next.js bakes `NEXT_PUBLIC_*` environment variables at build time (they're inlined into the JavaScript bundle). Must be passed during `docker build`, not at runtime.
- **No `public/` COPY in prod** — the project has no `public/` directory. If one is added in the future, add `COPY --from=builder /app/public ./public` before the `USER` directive.
- **`collectstatic` with `|| true`** — allows the build to succeed even without database access or if no static files exist yet.
