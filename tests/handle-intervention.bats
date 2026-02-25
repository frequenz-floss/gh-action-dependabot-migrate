# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Unit tests for handle-intervention.sh.

setup() {
  load test-helper/common
  _common_setup

  export PR_NUMBER="42"
  export REPO="test-org/test-repo"
  export GH_TOKEN="test-token"
  export LABEL_PENDING="tool:migration:intervention-pending"
  export LABEL_PENDING_COLOR="#DE36AD"
  export LABEL_PENDING_DESCRIPTION="Migration requires manual intervention"
  export LABEL_DONE="tool:migration:intervention-done"
  export LABEL_DONE_COLOR="#0E8A16"
  export LABEL_DONE_DESCRIPTION="Manual migration intervention has been completed"
  export AUTO_MERGE_ON_CHANGES="false"
  export REPORT_TITLE="Dependabot Migration"

  GITHUB_STEP_SUMMARY="$(mktemp)"
  export GITHUB_STEP_SUMMARY

  cat >"${MOCK_DIR}/gh" <<'MOCK_GH'
#!/usr/bin/env bash

LOG_FILE="${MOCK_DIR}/gh_calls.log"
printf '%s\n' "$*" >>"$LOG_FILE"

if [ "$1" = "pr" ] && [ "$2" = "view" ]; then
  printf '%s\n' "${MOCK_GH_VIEW_LABELS:-}"
  exit "${MOCK_GH_PR_VIEW_EXIT:-0}"
fi

if [ "$1" = "label" ] && [ "$2" = "create" ]; then
  exit 0
fi

if [ "$1" = "pr" ] && [ "$2" = "edit" ]; then
  exit 0
fi

if [ "$1" = "pr" ] && [ "$2" = "comment" ]; then
  # Capture the comment body for assertion.
  for ARG in "$@"; do
    if [ "$PREV_ARG" = "--body" ]; then
      printf '%s\n' "$ARG" >"${MOCK_DIR}/comment_body.txt"
      break
    fi
    PREV_ARG="$ARG"
  done
  exit 0
fi

exit 0
MOCK_GH
  chmod +x "${MOCK_DIR}/gh"
}

teardown() {
  _common_teardown
  rm -f "${GITHUB_STEP_SUMMARY:-}"
}

# ── Done-label removal (undo intervention) ────────────────────────

@test "done-label removal re-adds pending label" {
  export EVENT_ACTION="unlabeled"
  export EVENT_LABEL="$LABEL_DONE"

  run bash "${REPO_ROOT}/scripts/handle-intervention.sh"
  assert_failure

  run cat "${MOCK_DIR}/gh_calls.log"
  assert_output --partial "label create ${LABEL_PENDING}"
  assert_output --partial "pr edit 42 --add-label ${LABEL_PENDING}"
}

@test "done-label removal posts comment about removed label" {
  export EVENT_ACTION="unlabeled"
  export EVENT_LABEL="$LABEL_DONE"

  run bash "${REPO_ROOT}/scripts/handle-intervention.sh"
  assert_failure

  run cat "${MOCK_DIR}/comment_body.txt"
  assert_output --partial "## Dependabot Migration"
  assert_output --partial "The \`${LABEL_DONE}\` label was removed"
}

@test "done-label removal comment renders labels as code" {
  export EVENT_ACTION="unlabeled"
  export EVENT_LABEL="$LABEL_DONE"

  run bash "${REPO_ROOT}/scripts/handle-intervention.sh"
  assert_failure

  run cat "${MOCK_DIR}/comment_body.txt"
  assert_output --partial "\`${LABEL_PENDING}\`"
  assert_output --partial "\`${LABEL_DONE}\`"
}

@test "done-label removal comment has no mid-paragraph newlines" {
  export EVENT_ACTION="unlabeled"
  export EVENT_LABEL="$LABEL_DONE"

  run bash "${REPO_ROOT}/scripts/handle-intervention.sh"
  assert_failure

  COMMENT=$(cat "${MOCK_DIR}/comment_body.txt")
  # The paragraph about re-adding the label should be a single line.
  LINE=$(echo "$COMMENT" | grep "Marking manual intervention")
  echo "$LINE" | grep -q "when manual resolution is done"
}

@test "done-label removal emits error annotation" {
  export EVENT_ACTION="unlabeled"
  export EVENT_LABEL="$LABEL_DONE"

  run bash "${REPO_ROOT}/scripts/handle-intervention.sh"
  assert_failure
  assert_output --partial "::error::"
  assert_output --partial "was removed"
}

@test "done-label removal exits with code 1" {
  export EVENT_ACTION="unlabeled"
  export EVENT_LABEL="$LABEL_DONE"

  run bash "${REPO_ROOT}/scripts/handle-intervention.sh"
  [ "$status" -eq 1 ]
}

# ── Intervention completed (pending removed) ──────────────────────

@test "pending removal normalises labels" {
  export EVENT_ACTION="unlabeled"
  export EVENT_LABEL="$LABEL_PENDING"
  export MOCK_GH_VIEW_LABELS="$LABEL_PENDING"

  run bash "${REPO_ROOT}/scripts/handle-intervention.sh"
  assert_success

  run cat "${MOCK_DIR}/gh_calls.log"
  # Removes pending.
  assert_output --partial "pr edit 42 --remove-label ${LABEL_PENDING}"
  # Adds done.
  assert_output --partial "label create ${LABEL_DONE}"
  assert_output --partial "pr edit 42 --add-label ${LABEL_DONE}"
}

@test "pending removal posts completion comment" {
  export EVENT_ACTION="unlabeled"
  export EVENT_LABEL="$LABEL_PENDING"
  export MOCK_GH_VIEW_LABELS="$LABEL_PENDING"

  run bash "${REPO_ROOT}/scripts/handle-intervention.sh"
  assert_success

  run cat "${MOCK_DIR}/comment_body.txt"
  assert_output --partial "Manual intervention has been marked as completed"
}

@test "pending removal uses custom report title in comment and summary" {
  export EVENT_ACTION="unlabeled"
  export EVENT_LABEL="$LABEL_PENDING"
  export MOCK_GH_VIEW_LABELS="$LABEL_PENDING"
  export REPORT_TITLE="Repo Config Migration"

  run bash "${REPO_ROOT}/scripts/handle-intervention.sh"
  assert_success

  run cat "${MOCK_DIR}/comment_body.txt"
  assert_output --partial "## Repo Config Migration"

  run cat "${GITHUB_STEP_SUMMARY}"
  assert_output --partial "## Repo Config Migration"
}

@test "completion comment has no mid-paragraph newlines" {
  export EVENT_ACTION="unlabeled"
  export EVENT_LABEL="$LABEL_PENDING"
  export MOCK_GH_VIEW_LABELS="$LABEL_PENDING"

  run bash "${REPO_ROOT}/scripts/handle-intervention.sh"
  assert_success

  COMMENT=$(cat "${MOCK_DIR}/comment_body.txt")
  # The paragraph about manual merge should be a single line.
  LINE=$(echo "$COMMENT" | grep "Because this PR required")
  echo "$LINE" | grep -q "merge this PR manually"
}

@test "completion comment includes auto-merge note when enabled" {
  export EVENT_ACTION="unlabeled"
  export EVENT_LABEL="$LABEL_PENDING"
  export MOCK_GH_VIEW_LABELS="$LABEL_PENDING"
  export AUTO_MERGE_ON_CHANGES="true"

  run bash "${REPO_ROOT}/scripts/handle-intervention.sh"
  assert_success

  run cat "${MOCK_DIR}/comment_body.txt"
  assert_output --partial "\`auto-merge-on-changes\` is enabled"
  assert_output --partial "did not require manual intervention"
}

@test "completion comment omits auto-merge note when disabled" {
  export EVENT_ACTION="unlabeled"
  export EVENT_LABEL="$LABEL_PENDING"
  export MOCK_GH_VIEW_LABELS="$LABEL_PENDING"
  export AUTO_MERGE_ON_CHANGES="false"

  run bash "${REPO_ROOT}/scripts/handle-intervention.sh"
  assert_success

  run cat "${MOCK_DIR}/comment_body.txt"
  refute_output --partial "\`auto-merge-on-changes\` is enabled"
}

@test "completion writes job summary" {
  export EVENT_ACTION="unlabeled"
  export EVENT_LABEL="$LABEL_PENDING"
  export MOCK_GH_VIEW_LABELS="$LABEL_PENDING"

  run bash "${REPO_ROOT}/scripts/handle-intervention.sh"
  assert_success

  run cat "${GITHUB_STEP_SUMMARY}"
  assert_output --partial "## Dependabot Migration"
  assert_output --partial "Manual intervention has been marked as completed"
  assert_output --partial "manual review, approval, and merge"
}

# ── Done-label added ──────────────────────────────────────────────

@test "done-label added normalises labels" {
  export EVENT_ACTION="labeled"
  export EVENT_LABEL="$LABEL_DONE"
  export MOCK_GH_VIEW_LABELS=""

  run bash "${REPO_ROOT}/scripts/handle-intervention.sh"
  assert_success

  run cat "${MOCK_DIR}/gh_calls.log"
  assert_output --partial "label create ${LABEL_DONE}"
  assert_output --partial "pr edit 42 --add-label ${LABEL_DONE}"
}
