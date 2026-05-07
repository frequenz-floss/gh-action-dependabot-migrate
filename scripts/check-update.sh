#!/usr/bin/env bash
# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Decide whether a migration is needed based on the Dependabot
# update metadata.
#
# Resolves the old/new version range from the updated-dependencies
# JSON and determines the update type.  When version-iteration is
# NOT set (backward-compat path), patch-only bumps short-circuit
# with needs_migration=false so that handle-patch-update.sh can
# handle them.  When version-iteration IS set, all update types
# — including patch — are forwarded to run-migration.sh.
#
# Expected environment variables (set by the composite action):
#   UPDATE_TYPE        – update type from dependabot/fetch-metadata
#                        (may be empty for grouped updates)
#   DEPS_JSON          – updated-dependencies-json from
#                        dependabot/fetch-metadata
#   VERSION_ITERATION  – iteration mode (empty when not set)

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "::error::jq is required to parse updated-dependencies-json."
  exit 1
fi

OLD_VERSIONS=$(echo "$DEPS_JSON" \
  | jq -r '.[].prevVersion | select(. != "" and . != null)')
NEW_VERSIONS=$(echo "$DEPS_JSON" \
  | jq -r '.[].newVersion | select(. != "" and . != null)')

if [ -z "$OLD_VERSIONS" ] || [ -z "$NEW_VERSIONS" ]; then
  echo "::error::Could not resolve versions from updated-dependencies-json."
  echo "::error::updated-dependencies-json: $DEPS_JSON"
  exit 1
fi

OLD_VERSION=$(echo "$OLD_VERSIONS" | sort -V | head -1)
NEW_VERSION=$(echo "$NEW_VERSIONS" | sort -V | tail -1)
echo "Resolved update range: ${OLD_VERSION} → ${NEW_VERSION}"

if [ -z "$UPDATE_TYPE" ]; then
  if echo "$DEPS_JSON" \
    | jq -e '.[] | select(.updateType == "version-update:semver-major")' \
      >/dev/null; then
    UPDATE_TYPE="version-update:semver-major"
  elif echo "$DEPS_JSON" \
    | jq -e '.[] | select(.updateType == "version-update:semver-minor")' \
      >/dev/null; then
    UPDATE_TYPE="version-update:semver-minor"
  else
    UPDATE_TYPE="version-update:semver-patch"
  fi
fi

{
  echo "update_type=$UPDATE_TYPE"
  echo "old_version=$OLD_VERSION"
  echo "new_version=$NEW_VERSION"
} >>"$GITHUB_OUTPUT"

if [ -z "$VERSION_ITERATION" ] \
  && [ "$UPDATE_TYPE" = "version-update:semver-patch" ]; then
  echo "needs_migration=false" >>"$GITHUB_OUTPUT"
  echo "Patch update only — no migration needed."
else
  echo "needs_migration=true" >>"$GITHUB_OUTPUT"
fi
