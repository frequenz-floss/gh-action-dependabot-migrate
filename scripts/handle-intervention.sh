#!/usr/bin/env bash
# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Handle intervention resolution for a Dependabot migration PR.
#
# The user can signal that intervention is done in two ways:
#   a. Remove the intervention-pending-label.
#   b. Add the intervention-done-label.
#
# Users can also signal that intervention is needed again by adding
# the intervention-pending-label after completion.
#
# This script handles intervention label transitions and posts
# next-step instructions.  Removing the done-label or adding the
# pending-label again is treated as undoing completion and fails
# intentionally.
#
# Expected environment variables (set by the composite action):
#   PR_NUMBER          – pull request number
#   REPO               – owner/repository (e.g. org/repo)
#   GH_TOKEN           – token used by gh CLI
#   EVENT_ACTION       – github.event.action (labeled / unlabeled)
#   EVENT_LABEL        – github.event.label.name
#   LABEL_PENDING      – full intervention-pending label name
#   LABEL_PENDING_COLOR       – pending label colour (#RRGGBB)
#   LABEL_PENDING_DESCRIPTION – pending label description text
#   LABEL_DONE         – full intervention-done label name
#   LABEL_DONE_COLOR          – done label colour (#RRGGBB)
#   LABEL_DONE_DESCRIPTION    – done label description text
#   AUTO_MERGE_ON_CHANGES     – "true" / "false"
#   REPORT_TITLE              – heading for comments and summaries

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Pending-label addition: intervention needed again ─────────────
if [ "$EVENT_ACTION" = "labeled" ] &&
  [ "$EVENT_LABEL" = "$LABEL_PENDING" ]; then
  LABEL_NAME="$LABEL_DONE" \
    "${SCRIPT_DIR}/remove-label.sh"

  PARA="Manual intervention has been marked as needed again.  The "
  PARA="${PARA}\`${LABEL_DONE}\` label has been removed.  Please "
  PARA="${PARA}complete the manual steps and then remove the "
  PARA="${PARA}\`${LABEL_PENDING}\` label or add the \`${LABEL_DONE}\` "
  PARA="${PARA}label again."
  COMMENT_BODY=$(printf '%s\n' \
    "## ${REPORT_TITLE}" \
    "" \
    "${PARA}")
  gh pr comment "$PR_NUMBER" --repo "$REPO" --body "$COMMENT_BODY" || true

  {
    echo "## ${REPORT_TITLE}"
    echo ""
    echo "Manual intervention has been marked as needed again."
    echo ""
    echo "The \`${LABEL_DONE}\` label was removed."
  } >>"$GITHUB_STEP_SUMMARY"

  echo "::error::${LABEL_PENDING} was added. Intervention is pending again."
  exit 1
fi

# ── Done-label removal: undo intervention completion ──────────────
if [ "$EVENT_ACTION" = "unlabeled" ] &&
  [ "$EVENT_LABEL" = "$LABEL_DONE" ]; then
  LABEL_NAME="$LABEL_PENDING" \
    LABEL_COLOR="$LABEL_PENDING_COLOR" \
    LABEL_DESCRIPTION="$LABEL_PENDING_DESCRIPTION" \
    "${SCRIPT_DIR}/add-label.sh"

  PARA="Marking manual intervention as not yet done again "
  PARA="${PARA}(adding \`${LABEL_PENDING}\`).  Please remove the "
  PARA="${PARA}\`${LABEL_PENDING}\` or add the \`${LABEL_DONE}\` label "
  PARA="${PARA}again when manual resolution is done."
  COMMENT_BODY=$(printf '%s\n' \
    "## ${REPORT_TITLE}" \
    "" \
    "The \`${LABEL_DONE}\` label was removed." \
    "" \
    "${PARA}")
  gh pr comment "$PR_NUMBER" --repo "$REPO" --body "$COMMENT_BODY" || true

  echo "::error::${LABEL_DONE} was removed. Re-add it when intervention is complete."
  exit 1
fi

# ── Normalise labels: remove pending, add done ────────────────────
LABEL_NAME="$LABEL_PENDING" \
  "${SCRIPT_DIR}/remove-label.sh"

LABEL_NAME="$LABEL_DONE" \
  LABEL_COLOR="$LABEL_DONE_COLOR" \
  LABEL_DESCRIPTION="$LABEL_DONE_DESCRIPTION" \
  "${SCRIPT_DIR}/add-label.sh"

PARA="Because this PR required manual intervention, this action will not auto-approve or auto-merge it.  Please review, approve, and merge this PR manually."
COMMENT_BODY=$(printf '%s\n' \
  "## ${REPORT_TITLE}" \
  "" \
  "Manual intervention has been marked as completed." \
  "" \
  "${PARA}")
if [ "$AUTO_MERGE_ON_CHANGES" = "true" ]; then
  NOTE_TEXT="Note: \`auto-merge-on-changes\` is enabled, but it only "
  NOTE_TEXT="${NOTE_TEXT}applies to clean migrations that did not "
  NOTE_TEXT="${NOTE_TEXT}require manual intervention."
  COMMENT_BODY="${COMMENT_BODY}"$'\n\n'"${NOTE_TEXT}"
fi
gh pr comment "$PR_NUMBER" --repo "$REPO" --body "$COMMENT_BODY" || true

{
  echo "## ${REPORT_TITLE}"
  echo ""
  echo "Manual intervention has been marked as completed."
  echo ""
  echo "This PR now requires manual review, approval, and merge."
} >>"$GITHUB_STEP_SUMMARY"
