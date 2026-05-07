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
#   UPDATED_DEPENDENCIES_JSON – JSON array from dependabot/fetch-metadata
#                          with full dependency update details; passed
#                          through to migration scripts via the environment
#   SCRIPT_URL_TEMPLATE  – URL template with {version} placeholder
#                          (mutually exclusive with MIGRATION_SCRIPT)
#   MIGRATION_SCRIPT     – inline migration script body
#                          (mutually exclusive with SCRIPT_URL_TEMPLATE)
#   VERSION_ITERATION    – iteration mode: false, major, minor, patch
#                          (empty falls back to ITERATE_V0_MINORS,
#                          then to the implicit v0.x minor default;
#                          a deprecation warning is emitted until
#                          version-iteration is set explicitly)
#   IF_NO_ITERATIONS     – what to do when no migration versions are
#                          produced: error, pass (empty defaults to
#                          "error", or "pass" under the deprecated
#                          ITERATE_V0_MINORS fallback and the implicit
#                          v0.x default)
#   ITERATE_V0_MINORS    – deprecated; "true" to iterate v0.x
#                          intermediate minors, "false" for only the
#                          target version (empty means inactive;
#                          mutually exclusive with VERSION_ITERATION)
#   MIGRATION_TOKEN_INPUT – optional token exposed as GITHUB_TOKEN
#                           and GH_TOKEN

set -uo pipefail
# We handle errors explicitly throughout this script.

OLD_MAJOR=$(echo "$OLD_VERSION" | sed -E 's/^([0-9]+)\..*/\1/')
OLD_MINOR=$(echo "$OLD_VERSION" | sed -E 's/^([0-9]+)\.([0-9]+)\..*/\2/')
OLD_PATCH=$(echo "$OLD_VERSION" | sed -E 's/^([0-9]+)\.([0-9]+)\.([0-9]+).*/\3/')
NEW_MAJOR=$(echo "$NEW_VERSION" | sed -E 's/^([0-9]+)\..*/\1/')
NEW_MINOR=$(echo "$NEW_VERSION" | sed -E 's/^([0-9]+)\.([0-9]+)\..*/\2/')
NEW_PATCH=$(echo "$NEW_VERSION" | sed -E 's/^([0-9]+)\.([0-9]+)\.([0-9]+).*/\3/')

echo "Old: v${OLD_MAJOR}.${OLD_MINOR}.${OLD_PATCH}, New: v${NEW_MAJOR}.${NEW_MINOR}.${NEW_PATCH}"
echo "Updated dependencies JSON:"
echo "$UPDATED_DEPENDENCIES_JSON" | jq -C . 2>/dev/null || echo "$UPDATED_DEPENDENCIES_JSON"

# Resolve effective iteration mode from inputs.
#
# When VERSION_ITERATION is set, it takes precedence (setting both
# VERSION_ITERATION and ITERATE_V0_MINORS is rejected at validation).
# When only the deprecated ITERATE_V0_MINORS is set, map it to the
# new mode and emit a deprecation warning.
# When neither is set, preserve the historical default: v0.x bumps
# iterate intermediate minors (with if-no-iterations defaulting to
# "pass"), and v1+ bumps target only the new version.
if [ -n "${VERSION_ITERATION:-}" ] && [ -n "${ITERATE_V0_MINORS:-}" ]; then
  echo "::error::\`version-iteration\` and \`iterate-v0-minors\` are" \
    "mutually exclusive — remove \`iterate-v0-minors\` when using" \
    "\`version-iteration\`."
  exit 1
elif [ -n "${VERSION_ITERATION:-}" ]; then
  case "$VERSION_ITERATION" in
  false|major|minor|patch)
    ITERATION_MODE="$VERSION_ITERATION"
    ;;
  *)
    echo "::error::VERSION_ITERATION must be one of: false, major, minor, patch."
    exit 1
    ;;
  esac
elif [ -n "${ITERATE_V0_MINORS:-}" ]; then
  # Deprecated input — validate, warn, and map to the new mode.
  case "$ITERATE_V0_MINORS" in
  true)
    echo "::warning::\`iterate-v0-minors\` is deprecated." \
      "Replace with \`version-iteration: \"minor\"\`." \
      "If same-minor v0.x patch bumps should pass as a no-op," \
      "also set \`if-no-iterations: \"pass\"\`."
    if [ "$OLD_MAJOR" = "0" ] && [ "$NEW_MAJOR" = "0" ]; then
      ITERATION_MODE="minor"
      IF_NO_ITERATIONS="${IF_NO_ITERATIONS:-pass}"
    else
      ITERATION_MODE="false"
    fi
    ;;
  false)
    echo "::warning::\`iterate-v0-minors\` is deprecated." \
      "Replace with \`version-iteration: \"false\"\`."
    ITERATION_MODE="false"
    ;;
  *)
    echo "::error::ITERATE_V0_MINORS must be one of: true, false."
    exit 1
    ;;
  esac
else
  # Neither input set — backward-compatible default.  Warn so users
  # migrate to the explicit version-iteration input.
  echo "::warning::\`version-iteration\` is not set." \
    "The implicit default (v0.x minor iteration) is deprecated and" \
    "will change in a future release.  Set \`version-iteration\`" \
    "explicitly to silence this warning."
  if [ "$OLD_MAJOR" = "0" ] && [ "$NEW_MAJOR" = "0" ]; then
    ITERATION_MODE="minor"
    IF_NO_ITERATIONS="${IF_NO_ITERATIONS:-pass}"
  else
    ITERATION_MODE="false"
  fi
fi

echo "Iteration mode: ${ITERATION_MODE}"
# Apply the default after mode resolution so the deprecated path
# can set its own backward-compatible default above.
IF_NO_ITERATIONS="${IF_NO_ITERATIONS:-error}"
case "$IF_NO_ITERATIONS" in
error|pass) ;;
*)
  echo "::error::IF_NO_ITERATIONS must be one of: error, pass."
  exit 1
  ;;
esac

# Build the list of versions to migrate through.
#
# The algorithm generates synthetic version numbers at semver
# boundaries.  Intermediate majors get vX.0.0, intermediate minors
# within the target major get vX.Y.0, and patches within the target
# minor are enumerated individually.
VERSIONS=()
case "$ITERATION_MODE" in
false)
  VERSIONS+=("v${NEW_VERSION}")
  ;;
major)
  for MAJOR in $(seq $((OLD_MAJOR + 1)) "$NEW_MAJOR"); do
    VERSIONS+=("v${MAJOR}.0.0")
  done
  ;;
minor)
  # Major boundaries.
  for MAJOR in $(seq $((OLD_MAJOR + 1)) "$NEW_MAJOR"); do
    VERSIONS+=("v${MAJOR}.0.0")
  done
  # Minor boundaries within the target major.
  if [ "$OLD_MAJOR" = "$NEW_MAJOR" ]; then
    MINOR_START=$((OLD_MINOR + 1))
  else
    MINOR_START=1 # v${NEW_MAJOR}.0.0 is already covered above.
  fi
  for MINOR in $(seq "$MINOR_START" "$NEW_MINOR"); do
    VERSIONS+=("v${NEW_MAJOR}.${MINOR}.0")
  done
  ;;
patch)
  # Major boundaries.
  for MAJOR in $(seq $((OLD_MAJOR + 1)) "$NEW_MAJOR"); do
    VERSIONS+=("v${MAJOR}.0.0")
  done
  # Minor boundaries within the target major.
  if [ "$OLD_MAJOR" = "$NEW_MAJOR" ]; then
    MINOR_START=$((OLD_MINOR + 1))
  else
    MINOR_START=1
  fi
  for MINOR in $(seq "$MINOR_START" "$NEW_MINOR"); do
    VERSIONS+=("v${NEW_MAJOR}.${MINOR}.0")
  done
  # Patch versions within the target minor.
  if [ "$OLD_MAJOR" = "$NEW_MAJOR" ] &&
    [ "$OLD_MINOR" = "$NEW_MINOR" ]; then
    PATCH_START=$((OLD_PATCH + 1))
  else
    PATCH_START=1 # v${NEW_MAJOR}.${NEW_MINOR}.0 is already covered above.
  fi
  for PATCH in $(seq "$PATCH_START" "$NEW_PATCH"); do
    VERSIONS+=("v${NEW_MAJOR}.${NEW_MINOR}.${PATCH}")
  done
  ;;
*)
  echo "::error::Unexpected iteration mode '${ITERATION_MODE}'.  Expected one of: false, major, minor, patch."
  exit 1
  ;;
esac

if [ ${#VERSIONS[@]} -eq 0 ]; then
  case "$IF_NO_ITERATIONS" in
  error)
    echo "::error::No versions to migrate."
    {
      echo "overall_exit=1"
      echo "report<<REPORT_EOF"
      echo "No versions to migrate."
      echo "REPORT_EOF"
      echo "migration_ran=false"
    } >>"$GITHUB_OUTPUT"
    exit 1
    ;;
  pass)
    echo "::notice::No versions to migrate."
    {
      echo "overall_exit=0"
      echo "report<<REPORT_EOF"
      echo "No versions to migrate."
      echo "REPORT_EOF"
      echo "migration_ran=true"
    } >>"$GITHUB_OUTPUT"
    exit 0
    ;;
  *)
    echo "::error::IF_NO_ITERATIONS has unexpected value:" \
      "'${IF_NO_ITERATIONS}'."
    exit 1
    ;;
  esac
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
