#!/usr/bin/env bash
# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Run migration scripts for each version in a range and produce
# a consolidated report.
#
# Expected environment variables (set by the composite action):
#   OLD_VERSION          – version being upgraded from (e.g. 0.13.1)
#   NEW_VERSION          – version being upgraded to (e.g. 0.15.0)
#   SCRIPT_URL_TEMPLATE  – URL template with {version} placeholder
#                          (mutually exclusive with MIGRATION_SCRIPT)
#   MIGRATION_SCRIPT     – inline migration script body
#                          (mutually exclusive with SCRIPT_URL_TEMPLATE)
#   ITERATE_V0_MINORS    – "true" to iterate v0.x intermediate minors
#   MIGRATION_TOKEN_INPUT – optional token exposed as GITHUB_TOKEN
#                           and GH_TOKEN

set -uo pipefail
# We handle errors explicitly throughout this script.

OLD_MINOR=$(echo "$OLD_VERSION" | sed -E 's/^([0-9]+)\.([0-9]+)\..*/\2/')
NEW_MINOR=$(echo "$NEW_VERSION" | sed -E 's/^([0-9]+)\.([0-9]+)\..*/\2/')
OLD_MAJOR=$(echo "$OLD_VERSION" | sed -E 's/^([0-9]+)\..*/\1/')
NEW_MAJOR=$(echo "$NEW_VERSION" | sed -E 's/^([0-9]+)\..*/\1/')

echo "Old: v${OLD_MAJOR}.${OLD_MINOR}, New: v${NEW_MAJOR}.${NEW_MINOR}"

# Build the list of versions to migrate through.
VERSIONS=()
if [ "$ITERATE_V0_MINORS" = "true" ] &&
  [ "$OLD_MAJOR" = "0" ] && [ "$NEW_MAJOR" = "0" ]; then
  # v0.x: each minor bump is potentially breaking.
  for minor in $(seq $((OLD_MINOR + 1)) "$NEW_MINOR"); do
    VERSIONS+=("v0.${minor}.0")
  done
else
  # For v1+ or cross-major bumps, just target the new version.
  VERSIONS+=("v${NEW_VERSION}")
fi

if [ ${#VERSIONS[@]} -eq 0 ]; then
  echo "::warning::No versions to migrate (same minor version?)."
  {
    echo "overall_exit=0"
    echo "report<<REPORT_EOF"
    echo "No versions to migrate."
    echo "REPORT_EOF"
    echo "migration_ran=false"
  } >>"$GITHUB_OUTPUT"
  exit 0
fi

echo "Migration versions: ${VERSIONS[*]}"

OVERALL_EXIT=0
FULL_REPORT=""

for version in "${VERSIONS[@]}"; do
  SCRIPT_FILE="/tmp/migrate_${version}.py"

  if [ -n "${MIGRATION_SCRIPT:-}" ]; then
    # ── Inline script mode ──────────────────────────────────────────
    SECTION_HEADER="=== ${version} =========================================================
Source: inline script"

    echo ""
    echo "========================================"
    echo "Running migration for $version ..."
    echo "(inline script)"
    echo "========================================"

    printf '%s\n' "$MIGRATION_SCRIPT" >"$SCRIPT_FILE"
  else
    # ── URL template mode ───────────────────────────────────────────
    SCRIPT_URL="${SCRIPT_URL_TEMPLATE//\{version\}/$version}"
    SECTION_HEADER="=== ${version} =========================================================
Script URL: ${SCRIPT_URL}"

    echo ""
    echo "========================================"
    echo "Running migration for $version ..."
    echo "<$SCRIPT_URL>"
    echo "========================================"

    HTTP_CODE=$(curl -sL -w "%{http_code}" -o "$SCRIPT_FILE" "$SCRIPT_URL")

    if [ "$HTTP_CODE" != "200" ]; then
      echo "::error::Migration script not found for $version (HTTP $HTTP_CODE)."
      FULL_REPORT="${FULL_REPORT}${SECTION_HEADER}

Migration script not found (HTTP ${HTTP_CODE}).

"
      OVERALL_EXIT=1
      continue
    fi
  fi

  # ── Execute the migration script ────────────────────────────────
  #
  # We use Python -I (isolate) mode to prevent the migration script from
  # importing any modules (like `os.py`) from the current working directory,
  # which is the checked out untrusted pull request code.
  if [ -n "$MIGRATION_TOKEN_INPUT" ]; then
    SCRIPT_OUTPUT=$(MIGRATION_VERSION="$version" \
      GITHUB_TOKEN="$MIGRATION_TOKEN_INPUT" \
      GH_TOKEN="$MIGRATION_TOKEN_INPUT" \
      python3 -I "$SCRIPT_FILE" 2>&1)
  else
    SCRIPT_OUTPUT=$(env -u GITHUB_TOKEN -u GH_TOKEN \
      MIGRATION_VERSION="$version" \
      python3 -I "$SCRIPT_FILE" 2>&1)
  fi
  EXIT_CODE=$?

  echo "$SCRIPT_OUTPUT"

  # Keep ANSI in logs, but sanitise for reports/commit messages.
  CLEAN_OUTPUT=$(python3 -I -c 'import re, sys
text = sys.stdin.read()
sys.stdout.write(re.sub(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])", "", text))' <<<"$SCRIPT_OUTPUT")

  FULL_REPORT="${FULL_REPORT}${SECTION_HEADER}

${CLEAN_OUTPUT}

"

  if [ "$EXIT_CODE" -ne 0 ]; then
    OVERALL_EXIT=1
  fi
done

# ── Write outputs ────────────────────────────────────────────────
{
  echo "overall_exit=$OVERALL_EXIT"

  # Persist multi-line report using heredoc delimiter.
  echo "report<<REPORT_EOF"
  echo "$FULL_REPORT"
  echo "REPORT_EOF"

  # Signal that the migration loop completed.
  echo "migration_ran=true"
} >>"$GITHUB_OUTPUT"
