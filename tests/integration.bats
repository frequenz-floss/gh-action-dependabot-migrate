# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Integration tests — exercise the helper scripts end-to-end.
#
# These tests verify that the output of run-migration.sh can be
# correctly consumed by build-report.sh, simulating the data flow
# through the composite action's steps 9 and 13.

setup() {
  load test-helper/common
  _common_setup

  export GITHUB_SERVER_URL="https://github.com"
  export GITHUB_REPOSITORY="test-org/test-repo"
  export GITHUB_RUN_ID="12345"
  export UPDATED_DEPENDENCIES_JSON='[{"dependencyName":"example","prevVersion":"0.5.0","newVersion":"0.6.0","updateType":"version-update:semver-minor"}]'
  export COMMIT_MADE="false"
  export AUTO_MERGE_ON_CHANGES="false"
  export TOKEN_PROVIDED="true"
  export REPORT_TITLE="Dependabot Migration"
  export INTERVENTION_PENDING_LABEL="intervention-pending"
  export INTERVENTION_DONE_LABEL="intervention-done"
  export INTERVENTION_PENDING_LABEL_COLOR="#DE36AD"
  export INTERVENTION_DONE_LABEL_COLOR="#0E8A16"
  unset MIGRATION_SCRIPT
}

teardown() {
  _common_teardown
  rm -f "${REPORT_OUTPUT:-}"
}

# Helper: parse a key=value line from a GitHub Actions output file.
_parse_output_value() {
  grep "^${1}=" "$2" | cut -d= -f2-
}

# Helper: parse a multi-line heredoc value from a GitHub Actions
# output file.  The format is:
#   key<<DELIMITER
#   ...value...
#   DELIMITER
_parse_output_heredoc() {
  KEY="$1"
  FILE="$2"
  DELIM=$(sed -n "s/^${KEY}<<//p" "$FILE" | head -1)
  sed -n "/^${KEY}<<${DELIM}$/,/^${DELIM}$/p" "$FILE" \
    | sed '1d;$d'
}

# ── Successful migration pipeline ─────────────────────────────────

@test "end-to-end: successful migration feeds into success report" {
  # ── 1. Run migration ────────────────────────────────────────────
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export ITERATE_V0_MINORS="true"
  export MIGRATION_TOKEN_INPUT=""
  export SCRIPT_URL_TEMPLATE="https://example.com/migrate-{version}.py"
  export MOCK_CURL_SCRIPT_BODY='print("Applied config changes")'

  bash "${REPO_ROOT}/scripts/run-migration.sh"

  # Parse outputs (simulates what GitHub Actions does between steps).
  OVERALL_EXIT=$(_parse_output_value "overall_exit" "${GITHUB_OUTPUT}")
  REPORT=$(_parse_output_heredoc "report" "${GITHUB_OUTPUT}")

  [ "$OVERALL_EXIT" = "0" ]
  [ -n "$REPORT" ]

  # ── 2. Build report ─────────────────────────────────────────────
  REPORT_OUTPUT="$(mktemp)"

  OLD_VERSION="0.5.0" \
  NEW_VERSION="0.6.0" \
  OVERALL_EXIT="${OVERALL_EXIT}" \
  REPORT="${REPORT}" \
  INTERVENTION_PENDING_LABEL="${INTERVENTION_PENDING_LABEL}" \
  INTERVENTION_DONE_LABEL="${INTERVENTION_DONE_LABEL}" \
  GITHUB_SERVER_URL="${GITHUB_SERVER_URL}" \
  GITHUB_REPOSITORY="${GITHUB_REPOSITORY}" \
  GITHUB_RUN_ID="${GITHUB_RUN_ID}" \
  GITHUB_OUTPUT="${REPORT_OUTPUT}" \
    bash "${REPO_ROOT}/scripts/build-report.sh"

  run cat "${REPORT_OUTPUT}"
  assert_output --partial "Migration completed successfully"
  assert_output --partial "Applied config changes"
  assert_output --partial "0.5.0"
  assert_output --partial "0.6.0"
  assert_output --partial "https://github.com/test-org/test-repo/actions/runs/12345"
}

# ── Failed migration pipeline ─────────────────────────────────────

@test "end-to-end: failed migration produces intervention report" {
  # ── 1. Run migration (fails) ────────────────────────────────────
  export OLD_VERSION="1.0.0"
  export NEW_VERSION="2.0.0"
  export ITERATE_V0_MINORS="true"
  export MIGRATION_TOKEN_INPUT=""
  export SCRIPT_URL_TEMPLATE="https://example.com/migrate-{version}.py"
  export MOCK_CURL_SCRIPT_BODY='import sys; print("Error: missing dependency"); sys.exit(1)'

  bash "${REPO_ROOT}/scripts/run-migration.sh"

  OVERALL_EXIT=$(_parse_output_value "overall_exit" "${GITHUB_OUTPUT}")
  REPORT=$(_parse_output_heredoc "report" "${GITHUB_OUTPUT}")

  [ "$OVERALL_EXIT" = "1" ]

  # ── 2. Build report ─────────────────────────────────────────────
  REPORT_OUTPUT="$(mktemp)"

  OLD_VERSION="1.0.0" \
  NEW_VERSION="2.0.0" \
  OVERALL_EXIT="${OVERALL_EXIT}" \
  REPORT="${REPORT}" \
  INTERVENTION_PENDING_LABEL="${INTERVENTION_PENDING_LABEL}" \
  INTERVENTION_DONE_LABEL="${INTERVENTION_DONE_LABEL}" \
  GITHUB_SERVER_URL="${GITHUB_SERVER_URL}" \
  GITHUB_REPOSITORY="${GITHUB_REPOSITORY}" \
  GITHUB_RUN_ID="${GITHUB_RUN_ID}" \
  GITHUB_OUTPUT="${REPORT_OUTPUT}" \
    bash "${REPO_ROOT}/scripts/build-report.sh"

  run cat "${REPORT_OUTPUT}"
  assert_output --partial "Manual Intervention Needed"
  assert_output --partial "Error: missing dependency"
}

# ── Multi-version migration pipeline ──────────────────────────────

@test "end-to-end: multi-version migration with mixed results" {
  # ── 1. Run migration (first succeeds, second fails) ─────────────
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"
  export ITERATE_V0_MINORS="true"
  export MIGRATION_TOKEN_INPUT=""
  export SCRIPT_URL_TEMPLATE="https://example.com/migrate-{version}.py"
  export MOCK_CURL_SCRIPT_BODY_1='print("v0.14.0: config updated")'
  export MOCK_CURL_SCRIPT_BODY_2='import sys; print("v0.15.0: schema error"); sys.exit(1)'

  bash "${REPO_ROOT}/scripts/run-migration.sh"

  OVERALL_EXIT=$(_parse_output_value "overall_exit" "${GITHUB_OUTPUT}")
  REPORT=$(_parse_output_heredoc "report" "${GITHUB_OUTPUT}")

  [ "$OVERALL_EXIT" = "1" ]

  # ── 2. Build report ─────────────────────────────────────────────
  REPORT_OUTPUT="$(mktemp)"

  OLD_VERSION="0.13.1" \
  NEW_VERSION="0.15.0" \
  OVERALL_EXIT="${OVERALL_EXIT}" \
  REPORT="${REPORT}" \
  INTERVENTION_PENDING_LABEL="${INTERVENTION_PENDING_LABEL}" \
  INTERVENTION_DONE_LABEL="${INTERVENTION_DONE_LABEL}" \
  GITHUB_SERVER_URL="${GITHUB_SERVER_URL}" \
  GITHUB_REPOSITORY="${GITHUB_REPOSITORY}" \
  GITHUB_RUN_ID="${GITHUB_RUN_ID}" \
  GITHUB_OUTPUT="${REPORT_OUTPUT}" \
    bash "${REPO_ROOT}/scripts/build-report.sh"

  run cat "${REPORT_OUTPUT}"
  assert_output --partial "Manual Intervention Needed"
  assert_output --partial "v0.14.0: config updated"
  assert_output --partial "v0.15.0: schema error"
}

# ── HTTP failure pipeline ──────────────────────────────────────────

@test "end-to-end: HTTP failure produces intervention report" {
  # ── 1. Run migration (script not found) ─────────────────────────
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export ITERATE_V0_MINORS="true"
  export MIGRATION_TOKEN_INPUT=""
  export SCRIPT_URL_TEMPLATE="https://example.com/migrate-{version}.py"
  export MOCK_CURL_HTTP_CODE="404"

  bash "${REPO_ROOT}/scripts/run-migration.sh"

  OVERALL_EXIT=$(_parse_output_value "overall_exit" "${GITHUB_OUTPUT}")
  REPORT=$(_parse_output_heredoc "report" "${GITHUB_OUTPUT}")

  [ "$OVERALL_EXIT" = "1" ]

  # ── 2. Build report ─────────────────────────────────────────────
  REPORT_OUTPUT="$(mktemp)"

  OLD_VERSION="0.5.0" \
  NEW_VERSION="0.6.0" \
  OVERALL_EXIT="${OVERALL_EXIT}" \
  REPORT="${REPORT}" \
  INTERVENTION_PENDING_LABEL="${INTERVENTION_PENDING_LABEL}" \
  INTERVENTION_DONE_LABEL="${INTERVENTION_DONE_LABEL}" \
  GITHUB_SERVER_URL="${GITHUB_SERVER_URL}" \
  GITHUB_REPOSITORY="${GITHUB_REPOSITORY}" \
  GITHUB_RUN_ID="${GITHUB_RUN_ID}" \
  GITHUB_OUTPUT="${REPORT_OUTPUT}" \
    bash "${REPO_ROOT}/scripts/build-report.sh"

  run cat "${REPORT_OUTPUT}"
  assert_output --partial "Manual Intervention Needed"
  assert_output --partial "Migration script not found"
}

# ── Inline script pipeline ─────────────────────────────────────────

@test "end-to-end: inline script success feeds into success report" {
  # ── 1. Run migration ────────────────────────────────────────────
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export ITERATE_V0_MINORS="true"
  export MIGRATION_TOKEN_INPUT=""
  unset SCRIPT_URL_TEMPLATE
  export MIGRATION_SCRIPT='import os; print("Inline applied for " + os.environ["MIGRATION_VERSION"])'

  bash "${REPO_ROOT}/scripts/run-migration.sh"

  OVERALL_EXIT=$(_parse_output_value "overall_exit" "${GITHUB_OUTPUT}")
  REPORT=$(_parse_output_heredoc "report" "${GITHUB_OUTPUT}")

  [ "$OVERALL_EXIT" = "0" ]
  [ -n "$REPORT" ]

  # ── 2. Build report ─────────────────────────────────────────────
  REPORT_OUTPUT="$(mktemp)"

  OLD_VERSION="0.5.0" \
  NEW_VERSION="0.6.0" \
  OVERALL_EXIT="${OVERALL_EXIT}" \
  REPORT="${REPORT}" \
  INTERVENTION_PENDING_LABEL="${INTERVENTION_PENDING_LABEL}" \
  INTERVENTION_DONE_LABEL="${INTERVENTION_DONE_LABEL}" \
  GITHUB_SERVER_URL="${GITHUB_SERVER_URL}" \
  GITHUB_REPOSITORY="${GITHUB_REPOSITORY}" \
  GITHUB_RUN_ID="${GITHUB_RUN_ID}" \
  GITHUB_OUTPUT="${REPORT_OUTPUT}" \
    bash "${REPO_ROOT}/scripts/build-report.sh"

  run cat "${REPORT_OUTPUT}"
  assert_output --partial "Migration completed successfully"
  assert_output --partial "Inline applied for v0.6.0"
  assert_output --partial "0.5.0"
  assert_output --partial "0.6.0"
}

@test "end-to-end: inline script failure produces intervention report" {
  # ── 1. Run migration (fails) ────────────────────────────────────
  export OLD_VERSION="1.0.0"
  export NEW_VERSION="2.0.0"
  export ITERATE_V0_MINORS="true"
  export MIGRATION_TOKEN_INPUT=""
  unset SCRIPT_URL_TEMPLATE
  export MIGRATION_SCRIPT='import sys; print("Inline error: missing dep"); sys.exit(1)'

  bash "${REPO_ROOT}/scripts/run-migration.sh"

  OVERALL_EXIT=$(_parse_output_value "overall_exit" "${GITHUB_OUTPUT}")
  REPORT=$(_parse_output_heredoc "report" "${GITHUB_OUTPUT}")

  [ "$OVERALL_EXIT" = "1" ]

  # ── 2. Build report ─────────────────────────────────────────────
  REPORT_OUTPUT="$(mktemp)"

  OLD_VERSION="1.0.0" \
  NEW_VERSION="2.0.0" \
  OVERALL_EXIT="${OVERALL_EXIT}" \
  REPORT="${REPORT}" \
  INTERVENTION_PENDING_LABEL="${INTERVENTION_PENDING_LABEL}" \
  INTERVENTION_DONE_LABEL="${INTERVENTION_DONE_LABEL}" \
  GITHUB_SERVER_URL="${GITHUB_SERVER_URL}" \
  GITHUB_REPOSITORY="${GITHUB_REPOSITORY}" \
  GITHUB_RUN_ID="${GITHUB_RUN_ID}" \
  GITHUB_OUTPUT="${REPORT_OUTPUT}" \
    bash "${REPO_ROOT}/scripts/build-report.sh"

  run cat "${REPORT_OUTPUT}"
  assert_output --partial "Manual Intervention Needed"
  assert_output --partial "Inline error: missing dep"
}
