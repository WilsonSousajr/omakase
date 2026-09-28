# Deploying the API on Coolify

Production is the `main` branch, deployed by Coolify (M6, #243, #244).
Coolify builds the containers, keeps them running and terminates TLS; the
repository carries no proxy configuration.

## The resource

1. In Coolify, create a resource from this repository's `main` branch
   with the **Docker Compose** build pack and the compose file
   `docker-compose.coolify.yml`.
2. Give the `backend` service the API's domain (for example
   `https://api.example.com`) on port **8000**. Leave `db` without a domain.
3. Set the health check path to **`/api/health/`**. The compose file's own
   healthcheck calls the same path.
4. Turn on automatic deploys for `main`. A promotion (develop → main) is
   then a release: merging it deploys.

## Environment variables

| Variable | Required | What it is |
|---|---|---|
| `DJANGO_SECRET_KEY` | yes | a long random string; never reused from development |
| `DJANGO_ALLOWED_HOSTS` | yes | the API's hostname, e.g. `api.example.com` (the compose file adds `localhost` for the probe) |
| `POSTGRES_PASSWORD` | yes | the database password |
| `DATABASE_URL` | yes | the whole URL the backend connects with: `postgres`, then the user, the password above, the host `db`, port 5432 and the database name (Coolify stores it as a secret) |
| `POSTGRES_USER`, `POSTGRES_DB` | no | default `omakase` |
| `GOOGLE_CLIENT_IDS` | yes | every OAuth client whose ID tokens the API accepts, comma-separated: the macOS client, later iOS |
| `CORS_ALLOWED_ORIGINS` | no | empty: the native clients send no `Origin` (#243) |
| `GUNICORN_WORKERS` | no | default 3 |

`DJANGO_DEBUG` is left unset, so it is `False`, and with it come the HTTPS
redirect and HSTS (`omakase/settings.py`).

## What happens on a deploy

- The `prod` image is built, and `collectstatic` runs at build time.
- At start, `docker-entrypoint.sh` runs `python manage.py migrate --noinput`,
  then execs gunicorn. A failed migration stops the container, and Coolify
  keeps the old one serving.
- Coolify waits for `/api/health/` to answer 200 (the database answers
  `SELECT 1`) before it routes traffic to the new container.

## Pointing the Mac app at it

Release builds read `OMAKASE_API_BASE_URL` from
`apps/apple/Config/Release.xcconfig` (#245). Set it to the domain above
before building a release; a placeholder that nobody filled in points at
`api.example.invalid`, which never resolves.

## Checks after a deploy

- `curl https://<domain>/api/health/` answers `{"status": "ok"}`.
- `curl -i https://<domain>/api/v1/auth/me/` answers 401 (auth required),
  not 500 or a proxy error.
- `curl -i http://<domain>/api/v1/auth/me/` redirects to HTTPS.
