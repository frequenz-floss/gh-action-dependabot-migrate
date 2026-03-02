#!/usr/bin/env bash
# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Ensure a repository label exists with a given colour and description.
#
# Expected environment variables (set by the composite action):
#   GH_TOKEN           – token used by gh CLI
#   REPO               – owner/repository (for example org/repo)
#   LABEL_NAME         – full label name
#   LABEL_COLOR        – hex colour in #RRGGBB format
#   LABEL_DESCRIPTION  – label description text

set -euo pipefail

case "$LABEL_COLOR" in
\#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
*)
  echo "::error::LABEL_COLOR must be in #RRGGBB format (for example #0E8A16)."
  exit 1
  ;;
esac

if ! gh label create "$LABEL_NAME" \
  --color "$LABEL_COLOR" \
  --description "$LABEL_DESCRIPTION" \
  --force \
  --repo "$REPO"; then
  echo "::error::Could not ensure label ${LABEL_NAME} exists."
  exit 1
fi
