#!/usr/bin/env bash
# k6 local runner for PokerMind page controller scenarios.
#
# Prerequisites:
#   - k6 installed (https://grafana.com/docs/k6/latest/set-up/install-k6/)
#   - Phoenix server running at BASE_URL (default: http://localhost:4000)
#     Start it with: mix phx.server
#
# Usage:
#   ./k6/run.sh                             # runs against http://localhost:4000
#   BASE_URL=http://localhost:4001 ./k6/run.sh
#   ./k6/run.sh --url http://localhost:4001
#
# Windows (no bash): set BASE_URL and call k6 directly:
#   $env:BASE_URL="http://localhost:4000"; k6 run k6/scenarios/page_controller.js

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:4000}"
SCENARIO="$(dirname "$0")/scenarios/page_controller.js"

# -- Parse flags ---------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    --url)
      BASE_URL="$2"
      shift 2
      ;;
    --help|-h)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# -- Preflight checks ----------------------------------------------------------
if ! command -v k6 &>/dev/null; then
  echo "ERROR: k6 is not installed."
  echo "Install it from: https://grafana.com/docs/k6/latest/set-up/install-k6/"
  exit 1
fi

echo "Checking server at ${BASE_URL} ..."
if ! curl -sf --max-time 5 "${BASE_URL}/" >/dev/null 2>&1; then
  echo "ERROR: No server responding at ${BASE_URL}"
  echo "Start the Phoenix server first:"
  echo "  mix phx.server"
  exit 1
fi

# -- Run -----------------------------------------------------------------------
echo "Running k6 performance tests against ${BASE_URL}"
echo ""
BASE_URL="${BASE_URL}" k6 run "${SCENARIO}"
