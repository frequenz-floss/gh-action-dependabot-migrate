#!/usr/bin/env bash
# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Validate composite action inputs.
#
# Expected environment variables (set by the composite action):
#   TOKEN               – token input
#   AUTO_MERGE_ON_CHANGES – whether auto-merge is enabled
#   SCRIPT_URL_TEMPLATE – URL template for migration scripts
#   MIGRATION_SCRIPT    – inline migration script body
#   VERSION_ITERATION   – iteration mode input
#   IF_NO_ITERATIONS    – no-iterations behaviour input
#   ITERATE_V0_MINORS   – deprecated v0.x iteration input

set -euo pipefail

if [ -n "$SCRIPT_URL_TEMPLATE" ] && [ -n "$MIGRATION_SCRIPT" ]; then
  echo "::error::\`script-url-template\` and \`migration-script\` are" \
    "mutually exclusive — provide exactly one."
  exit 1
fi

if [ -z "$SCRIPT_URL_TEMPLATE" ] && [ -z "$MIGRATION_SCRIPT" ]; then
  echo "::error::Either \`script-url-template\` or \`migration-script\`" \
    "must be provided."
  exit 1
fi

if [ "$AUTO_MERGE_ON_CHANGES" = "true" ] && [ -z "$TOKEN" ]; then
  echo "::error::\`auto-merge-on-changes\` requires the \`token\` input."
  exit 1
fi

if [ -n "$VERSION_ITERATION" ]; then
  case "$VERSION_ITERATION" in
  false|major|minor|patch) ;;
  *)
    echo "::error::\`version-iteration\` must be one of:" \
      "false, major, minor, patch."
    exit 1
    ;;
  esac
fi

if [ -n "$ITERATE_V0_MINORS" ]; then
  case "$ITERATE_V0_MINORS" in
  true|false) ;;
  *)
    echo "::error::\`iterate-v0-minors\` must be one of: true, false."
    exit 1
    ;;
  esac
fi

if [ -n "$VERSION_ITERATION" ] && [ -n "$ITERATE_V0_MINORS" ]; then
  echo "::error::\`version-iteration\` and \`iterate-v0-minors\` are" \
    "mutually exclusive — remove \`iterate-v0-minors\` when using" \
    "\`version-iteration\`."
  exit 1
fi

case "$IF_NO_ITERATIONS" in
""|error|pass) ;;
*)
  echo "::error::\`if-no-iterations\` must be one of: error, pass."
  exit 1
  ;;
esac
