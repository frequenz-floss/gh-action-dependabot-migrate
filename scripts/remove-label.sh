#!/usr/bin/env bash
# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Remove a label from a pull request when it is present.
#
# Expected environment variables (set by the composite action):
#   GH_TOKEN    – token used by gh CLI
#   REPO        – owner/repository (for example org/repo)
#   PR_NUMBER   – pull request number
#   LABEL_NAME  – full label name

set -euo pipefail

LABELS=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json labels -q '.labels[].name')

if echo "$LABELS" | grep -qxF "$LABEL_NAME"; then
  if ! gh pr edit "$PR_NUMBER" --remove-label "$LABEL_NAME" --repo "$REPO"; then
    echo "::error::Could not remove label ${LABEL_NAME} from PR #${PR_NUMBER}."
    exit 1
  fi
else
  echo "Label ${LABEL_NAME} is not set on PR #${PR_NUMBER}; nothing to remove."
fi
