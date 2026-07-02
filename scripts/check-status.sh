#!/usr/bin/env bash
# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Determine the migration status of a Dependabot PR from its labels
# AND the actual commits on the PR head.
#
# The migrated-label is a summary marker.  The migration commit
# carries a machine-readable trailer (MIGRATION_MARKER) set in the
# build-commit-message step — if the label is present but no commit
# on the PR head contains the trailer, the migration commit has been
# overwritten (typically by `@dependabot recreate`, which force-pushes
# a fresh commit from the current base).  In that case the label is
# stale and the migration should run again: self-heal by clearing the
# migrated, intervention-pending, and intervention-done labels, and
# report already_migrated=false so the migration flow re-runs on the
# recreated commit.
#
# Expected environment variables (set by the composite action):
#   PR_NUMBER          – pull request number
#   REPO               – owner/repository (e.g. org/repo)
#   GH_TOKEN           – token used by gh CLI
#   LABEL_MIGRATED     – full migrated-label name
#   LABEL_PENDING      – full intervention-pending-label name
#   LABEL_DONE         – full intervention-done-label name
#   MIGRATION_MARKER   – literal string to look for in commit messages;
#                        MUST match the marker used in
#                        build-commit-message (see action.yml)
#   ACTION_PATH        – path to the action root

set -euo pipefail

LABELS=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json labels -q '.labels[].name')

if grep -qxF "$LABEL_MIGRATED" <<<"$LABELS"; then
  COMMIT_MESSAGES=$(gh api --paginate \
    "/repos/${REPO}/pulls/${PR_NUMBER}/commits" \
    --jq '.[].commit.message')

  if grep -qxF "$MIGRATION_MARKER" <<<"$COMMIT_MESSAGES"; then
    ALREADY_MIGRATED="true"
  else
    echo "Migrated label present but no migration commit on PR head" \
      "— clearing stale labels so migration re-runs on the recreated commit."
    ALREADY_MIGRATED="false"
    LABEL_NAME="$LABEL_MIGRATED" \
      "${ACTION_PATH}/scripts/remove-label.sh"
    LABEL_NAME="$LABEL_PENDING" \
      "${ACTION_PATH}/scripts/remove-label.sh"
    LABEL_NAME="$LABEL_DONE" \
      "${ACTION_PATH}/scripts/remove-label.sh"
    LABELS=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json labels -q '.labels[].name')
  fi
else
  ALREADY_MIGRATED="false"
fi

echo "already_migrated=$ALREADY_MIGRATED" >>"$GITHUB_OUTPUT"

if grep -qxF "$LABEL_PENDING" <<<"$LABELS"; then
  echo "intervention_pending=true" >>"$GITHUB_OUTPUT"
else
  echo "intervention_pending=false" >>"$GITHUB_OUTPUT"
fi
