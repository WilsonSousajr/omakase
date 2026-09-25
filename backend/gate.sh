#!/usr/bin/env bash
# The quality gate, step for step what .github/workflows/ci.yml's gate job
# runs (#66). tools/tests/test_gate_workflow.py fails if the two drift apart.
# Runs from backend/ with dev dependencies installed; scripts/gate.sh runs it
# inside the dev container.
set -euo pipefail
cd "$(dirname "$0")"
ruff check .
ruff format --check .
lint-imports
complexipy accounts tasks pomodoro study stats omakase -e "**/tests/**" -e "**/migrations/**" -q --max-complexity-allowed 28
python manage.py check --fail-level WARNING
python manage.py makemigrations --check --dry-run
pip-audit -r requirements.txt
python manage.py migrate --noinput
pytest --cov --cov-report=term-missing --cov-report=json:coverage.json --cov-fail-under=90
python -m tools.crapcheck --threshold 18 --report coverage.json
