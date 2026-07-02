#!/usr/bin/env bash
# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Build a Markdown summary of the migration results.
#
# Expected environment variables (set by the composite action):
#   OLD_VERSION   – version being upgraded from (e.g. 0.13.1)
#   NEW_VERSION   – version being upgraded to (e.g. 0.15.0)
#   OVERALL_EXIT  – 0 if all scripts succeeded, 1 otherwise
#   REPORT        – full migration script output
#   REPORT_TITLE  – heading for PR comments and job summaries
#   INTERVENTION_PENDING_LABEL  – full pending-intervention label name
#   INTERVENTION_DONE_LABEL     – full done-intervention label name
#   COMMIT_MADE             – "true" when migration committed changes
#   AUTO_MERGE_ON_CHANGES   – input controlling merge policy for commits
#   TOKEN_PROVIDED          – "true" when `token` input is non-empty

set -euo pipefail

RUN_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

BODY="## ${REPORT_TITLE}

**Update:** ${OLD_VERSION} → ${NEW_VERSION}"

if [ "$OVERALL_EXIT" != "0" ]; then
  INSTRUCTION="After completing the intervention, either remove the "
  INSTRUCTION="${INSTRUCTION}\`${INTERVENTION_PENDING_LABEL}\` label or add the "
  INSTRUCTION="${INSTRUCTION}\`${INTERVENTION_DONE_LABEL}\` label to signal resolution."

  BODY="${BODY}

### ⚠️ Manual Intervention Needed

The migration script exited with a non-zero status.  Please review the output above and perform any required manual steps.

${INSTRUCTION}

After intervention is marked as completed, this PR still requires manual review, approval, and merge.

#### Migration output

\`\`\`
${REPORT}
\`\`\`"
else
  BODY="${BODY}

✅ Migration completed successfully.

<details>
<summary>Migration output</summary>

\`\`\`
${REPORT}
\`\`\`

</details>"

  if [ "$TOKEN_PROVIDED" != "true" ]; then
    BODY="${BODY}

### Next step

No \`token\` input was provided, so this action cannot auto-approve or auto-merge this PR.  Please review and merge this PR manually."
  elif [ "$COMMIT_MADE" = "true" ] &&
    [ "$AUTO_MERGE_ON_CHANGES" != "true" ]; then
    BODY="${BODY}

### Next step

Migration changes were committed and \`auto-merge-on-changes\` is disabled.  Please review, approve, and merge this PR manually."
  fi
fi

BODY="${BODY}

> [!NOTE]
> If this PR needs rebasing later, comment \`@dependabot recreate\` on the PR.
> This discards any current PR changes.  Dependabot will regenerate the PR from the current base, and this action will detect that the migration commit is gone and re-run the migration on the recreated commit.

---
📋 [Full migration logs](${RUN_URL})"

# Write multi-line output using heredoc delimiter.
{
  echo "summary<<SUMMARY_EOF"
  echo "$BODY"
  echo "SUMMARY_EOF"
} >>"$GITHUB_OUTPUT"
