#!/usr/bin/env bash
# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Handle patch-only Dependabot updates.
#
# For patch-only updates we either auto-merge (when a token is
# provided) or post a guidance comment and leave merge/approval to
# a human.
#
# Expected environment variables (set by the composite action):
#   PR_URL             – pull request HTML URL (for gh review/merge)
#   PR_NUMBER          – pull request number
#   REPO               – owner/repository (e.g. org/repo)
#   GH_TOKEN           – token used by gh CLI
#   TOKEN              – optional token input (empty when not provided)
#   AUTO_MERGED_LABEL  – label applied after auto-merge
#   AUTO_MERGED_LABEL_COLOR       – label colour (#RRGGBB)
#   AUTO_MERGED_LABEL_DESCRIPTION – label description text
#   REPORT_TITLE        – heading for comments and summaries

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

{
  echo "## ${REPORT_TITLE}"
  echo ""
  echo "Patch-only update — no migration needed."
} >>"$GITHUB_STEP_SUMMARY"

if [ -z "$TOKEN" ]; then
  PARA="No \`token\` input was provided, so this action cannot auto-approve or auto-merge this PR.  Please review and merge this PR manually."
  COMMENT_BODY=$(printf '%s\n' \
    "## ${REPORT_TITLE}" \
    "" \
    "Patch-only update detected and no migration is needed." \
    "" \
    "${PARA}")
  gh pr comment "$PR_NUMBER" --repo "$REPO" --body "$COMMENT_BODY" || true

  {
    echo ""
    echo "No \`token\` input provided — manual review and merge are required."
  } >>"$GITHUB_STEP_SUMMARY"
  exit 0
fi

gh pr review --approve "$PR_URL"
gh pr merge --auto --merge "$PR_URL"
LABEL_NAME="$AUTO_MERGED_LABEL" \
  LABEL_COLOR="$AUTO_MERGED_LABEL_COLOR" \
  LABEL_DESCRIPTION="$AUTO_MERGED_LABEL_DESCRIPTION" \
  "${SCRIPT_DIR}/add-label.sh"
