#!/usr/bin/env bash
# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Ensure a label exists and add it to a pull request.
#
# Expected environment variables (set by the composite action):
#   GH_TOKEN           – token used by gh CLI
#   REPO               – owner/repository (for example org/repo)
#   LABEL_NAME         – full label name
#   LABEL_COLOR        – hex colour in #RRGGBB format
#   LABEL_DESCRIPTION  – label description text
#   PR_NUMBER          – pull request number

set -euo pipefail

if [ "${PR_NUMBER+x}" != "x" ] || [ -z "$PR_NUMBER" ]; then
  echo "::error::PR_NUMBER is required."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/create-label.sh"

if ! gh pr edit "$PR_NUMBER" --add-label "$LABEL_NAME" --repo "$REPO"; then
  echo "::error::Could not add label ${LABEL_NAME} to PR #${PR_NUMBER}."
  exit 1
fi
