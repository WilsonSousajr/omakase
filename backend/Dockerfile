FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Development
FROM base AS dev
COPY requirements-dev.txt .
RUN pip install --no-cache-dir -r requirements-dev.txt
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]

# Production
FROM base AS prod

RUN addgroup --system --gid 1001 django && \
    adduser --system --uid 1001 --gid 1001 django

RUN python manage.py collectstatic --noinput 2>/dev/null || true
RUN chown -R django:django /app

USER django
CMD ["gunicorn", "omakase.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
