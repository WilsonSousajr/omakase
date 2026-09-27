#!/bin/sh
# The prod image's start (#243): Coolify runs no separate migrate step, so
# the schema is brought up to date before gunicorn takes requests.
set -eu
python manage.py migrate --noinput
exec gunicorn omakase.wsgi:application --bind 0.0.0.0:8000 --workers "${GUNICORN_WORKERS:-3}"
