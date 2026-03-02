# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Common test helper for bats tests.  Loaded by each .bats file
# via `load test_helper/common`.

# Resolve paths relative to the repository root.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BATS_LIB_DIR="${REPO_ROOT}/tests/lib"

# Load bats helper libraries.
load "${BATS_LIB_DIR}/bats-support/load"
load "${BATS_LIB_DIR}/bats-assert/load"

# Set up a clean test environment.  Call from each test file's setup().
#
# Creates:
#   GITHUB_OUTPUT – temp file simulating the GitHub Actions output file
#   MOCK_DIR      – temp directory with a mock `curl` prepended to PATH
#
# The mock curl is configurable via environment variables:
#   MOCK_CURL_HTTP_CODE     – HTTP code to return (default: 200)
#   MOCK_CURL_SCRIPT_BODY   – Python code for the "downloaded" script
#                             (default: print("Mock migration output"))
#   MOCK_CURL_HTTP_CODE_N   – per-call override for the Nth curl call
#   MOCK_CURL_SCRIPT_BODY_N – per-call override for the Nth curl call
_common_setup() {
  GITHUB_OUTPUT="$(mktemp)"
  export GITHUB_OUTPUT
  MOCK_DIR="$(mktemp -d)"
  export MOCK_DIR

  # Write the mock curl script.  The single-quoted heredoc delimiter
  # prevents expansion at write time — variables like $MOCK_DIR are
  # resolved at run time from the exported environment.
  cat >"${MOCK_DIR}/curl" <<'MOCK_CURL'
#!/usr/bin/env bash

CALL_COUNT_FILE="${MOCK_DIR}/curl_call_count"
COUNT=0
if [ -f "$CALL_COUNT_FILE" ]; then
  COUNT=$(cat "$CALL_COUNT_FILE")
fi
COUNT=$((COUNT + 1))
printf '%s' "$COUNT" > "$CALL_COUNT_FILE"

OUTPUT_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) OUTPUT_FILE="$2"; shift 2 ;;
    -w) shift 2 ;;
    -*) shift ;;
    *)  shift ;;
  esac
done

VAR_NAME="MOCK_CURL_HTTP_CODE_${COUNT}"
HTTP_CODE="${!VAR_NAME:-${MOCK_CURL_HTTP_CODE:-200}}"

VAR_NAME="MOCK_CURL_SCRIPT_BODY_${COUNT}"
SCRIPT_BODY="${!VAR_NAME:-${MOCK_CURL_SCRIPT_BODY:-print(\"Mock migration output\")}}"

if [ -n "$OUTPUT_FILE" ] && [ "$HTTP_CODE" = "200" ]; then
  printf '%s\n' "$SCRIPT_BODY" > "$OUTPUT_FILE"
fi

printf '%s' "$HTTP_CODE"
MOCK_CURL
  chmod +x "${MOCK_DIR}/curl"

  # Prepend mock directory so mock curl shadows the real one.
  export PATH="${MOCK_DIR}:${PATH}"
}

# Clean up after each test.  Call from each test file's teardown().
_common_teardown() {
  rm -f "$GITHUB_OUTPUT"
  rm -rf "$MOCK_DIR"
  rm -f /tmp/migrate_*.py
}
