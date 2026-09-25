#!/usr/bin/env bash
# Run the quality gate locally, inside the backend dev container - the same
# steps CI runs (backend/gate.sh). Usage: scripts/gate.sh
set -euo pipefail
cd "$(dirname "$0")/.."
docker-compose exec -T backend ./gate.sh
