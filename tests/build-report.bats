# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Unit tests for build-report.sh.

setup() {
  load test-helper/common
  _common_setup

  # Default environment for build-report.sh.
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"
  export OVERALL_EXIT="0"
  export REPORT="Migration completed without errors."
  export REPORT_TITLE="Dependabot Migration"
  export INTERVENTION_PENDING_LABEL="intervention-pending"
  export INTERVENTION_DONE_LABEL="intervention-done"
  export GITHUB_SERVER_URL="https://github.com"
  export GITHUB_REPOSITORY="test-org/test-repo"
  export GITHUB_RUN_ID="12345"
  export COMMIT_MADE="false"
  export AUTO_MERGE_ON_CHANGES="false"
  export TOKEN_PROVIDED="true"
}

teardown() {
  _common_teardown
}

# ── Success report ────────────────────────────────────────────────

@test "success report contains completion message" {
  export OVERALL_EXIT="0"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "Migration completed successfully"
}

@test "missing required env variable fails" {
  unset TOKEN_PROVIDED

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_failure
  assert_output --partial "TOKEN_PROVIDED"
}

@test "success report wraps output in details block" {
  export OVERALL_EXIT="0"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "<details>"
  assert_output --partial "<summary>Migration output</summary>"
  assert_output --partial "</details>"
}

@test "success report includes migration output" {
  export OVERALL_EXIT="0"
  export REPORT="All changes applied cleanly."

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "All changes applied cleanly."
}

@test "success report does not contain intervention warning" {
  export OVERALL_EXIT="0"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  refute_output --partial "Manual Intervention Needed"
}

@test "success report includes manual next step when token is missing" {
  export OVERALL_EXIT="0"
  export TOKEN_PROVIDED="false"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "### Next step"
  assert_output --partial "No \`token\` input was provided"
  assert_output --partial "Please review and merge this PR manually"
}

@test "success report includes manual next step when commits are present and auto-merge-on-changes is disabled" {
  export OVERALL_EXIT="0"
  export TOKEN_PROVIDED="true"
  export COMMIT_MADE="true"
  export AUTO_MERGE_ON_CHANGES="false"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "### Next step"
  assert_output --partial "\`auto-merge-on-changes\` is"
  assert_output --partial "disabled"
  assert_output --partial "Please review, approve, and merge this PR manually"
}

@test "success report omits manual next step when auto-merge can proceed" {
  export OVERALL_EXIT="0"
  export TOKEN_PROVIDED="true"
  export COMMIT_MADE="true"
  export AUTO_MERGE_ON_CHANGES="true"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  refute_output --partial "### Next step"
}

# ── Failure report ────────────────────────────────────────────────

@test "failure report contains intervention warning" {
  export OVERALL_EXIT="1"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "Manual Intervention Needed"
}

@test "failure report does not use details block" {
  export OVERALL_EXIT="1"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  refute_output --partial "<details>"
}

@test "failure report shows migration output in code block" {
  export OVERALL_EXIT="1"
  export REPORT="Error: config validation failed"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "Error: config validation failed"
}

@test "failure report does not contain success message" {
  export OVERALL_EXIT="1"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  refute_output --partial "Migration completed successfully"
}

@test "failure report explains that merge stays manual after intervention" {
  export OVERALL_EXIT="1"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "After intervention is marked as completed"
  assert_output --partial "manual review, approval, and merge"
}

# ── Version display ───────────────────────────────────────────────

@test "report shows version update range" {
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "0.13.1"
  assert_output --partial "0.15.0"
}

# ── Run URL ───────────────────────────────────────────────────────

@test "report includes correct run URL" {
  export GITHUB_SERVER_URL="https://github.com"
  export GITHUB_REPOSITORY="test-org/test-repo"
  export GITHUB_RUN_ID="12345"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "https://github.com/test-org/test-repo/actions/runs/12345"
}

@test "run URL uses custom server URL" {
  export GITHUB_SERVER_URL="https://github.example.com"
  export GITHUB_REPOSITORY="my-org/my-repo"
  export GITHUB_RUN_ID="99999"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "https://github.example.com/my-org/my-repo/actions/runs/99999"
}

# ── Label references ──────────────────────────────────────────────

@test "failure report includes intervention labels in backticks" {
  export OVERALL_EXIT="1"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "\`intervention-pending\`"
  assert_output --partial "\`intervention-done\`"
}

@test "failure report does not use shields.io badge URLs" {
  export OVERALL_EXIT="1"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  refute_output --partial "https://img.shields.io/static/v1"
}

# ── GITHUB_OUTPUT format ──────────────────────────────────────────

@test "output uses heredoc delimiter for multi-line summary" {
  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "summary<<SUMMARY_EOF"
  assert_output --partial "SUMMARY_EOF"
}

# ── Custom labels ────────────────────────────────────────────────

@test "custom labels are reflected in backticks" {
  export INTERVENTION_PENDING_LABEL="custom:prefix:pending"
  export INTERVENTION_DONE_LABEL="custom:prefix:done"
  export OVERALL_EXIT="1"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "\`custom:prefix:pending\`"
  assert_output --partial "\`custom:prefix:done\`"
}

@test "custom labels are used for label names" {
  export INTERVENTION_PENDING_LABEL="my-tool:migrate:pending"
  export INTERVENTION_DONE_LABEL="my-tool:migrate:done"
  export OVERALL_EXIT="1"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "my-tool:migrate:pending"
  assert_output --partial "my-tool:migrate:done"
}

# ── Report header ─────────────────────────────────────────────────

@test "report starts with Dependabot Migration heading" {
  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "## Dependabot Migration"
}

@test "report uses custom heading when provided" {
  export REPORT_TITLE="Repo Config Migration"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "## Repo Config Migration"
}

@test "report includes full run logs link" {
  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "Full migration logs"
}

# ── Rebase instructions ──────────────────────────────────────────

@test "success report includes rebase instructions" {
  export OVERALL_EXIT="0"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "[!NOTE]"
  assert_output --partial "If this PR needs rebasing later"
  assert_output --partial "comment \`@dependabot recreate\`"
}

@test "failure report includes rebase instructions" {
  export OVERALL_EXIT="1"

  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "[!NOTE]"
  assert_output --partial "If this PR needs rebasing later"
  assert_output --partial "comment \`@dependabot recreate\`"
}

@test "rebase instructions mention that the action detects the missing commit" {
  run bash "${REPO_ROOT}/scripts/build-report.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "discards any current PR changes"
  assert_output --partial "the migration commit is gone"
  assert_output --partial "re-run the migration on the recreated commit"
}
