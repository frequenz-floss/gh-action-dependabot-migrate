# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Unit tests for create-label.sh, add-label.sh, and remove-label.sh.

setup() {
  load test-helper/common
  _common_setup

  export PR_NUMBER="42"
  export REPO="test-org/test-repo"
  export GH_TOKEN="test-token"

  export LABEL_NAME="migrated"
  export LABEL_COLOR="#2B8383"
  export LABEL_DESCRIPTION="Migration script has been run"

  cat >"${MOCK_DIR}/gh" <<'MOCK_GH'
#!/usr/bin/env bash

LOG_FILE="${MOCK_DIR}/gh_calls.log"
printf '%s\n' "$*" >>"$LOG_FILE"

if [ "$1" = "pr" ] && [ "$2" = "view" ]; then
  printf '%s\n' "${MOCK_GH_VIEW_LABELS:-}"
  exit "${MOCK_GH_PR_VIEW_EXIT:-0}"
fi

if [ "$1" = "label" ] && [ "$2" = "create" ]; then
  if [ "${MOCK_GH_FAIL_LABEL_CREATE:-false}" = "true" ]; then
    exit 1
  fi
  exit 0
fi

if [ "$1" = "pr" ] && [ "$2" = "edit" ]; then
  if [ "${MOCK_GH_FAIL_PR_EDIT:-false}" = "true" ]; then
    exit 1
  fi
  exit 0
fi

exit 0
MOCK_GH
  chmod +x "${MOCK_DIR}/gh"
}

teardown() {
  _common_teardown
}

# ── create-label.sh ────────────────────────────────────────────────

@test "create-label ensures label exists" {
  run bash "${REPO_ROOT}/scripts/create-label.sh"
  assert_success

  run cat "${MOCK_DIR}/gh_calls.log"
  assert_output --partial "label create migrated"
  assert_output --partial "--color #2B8383"
  assert_output --partial "--description Migration script has been run"
}

@test "create-label requires leading hash" {
  export LABEL_COLOR="2B8383"

  run bash "${REPO_ROOT}/scripts/create-label.sh"
  assert_failure
  assert_output --partial "LABEL_COLOR must be in #RRGGBB format"
}

@test "create-label fails for invalid colour" {
  export LABEL_COLOR="#GGGGGG"

  run bash "${REPO_ROOT}/scripts/create-label.sh"
  assert_failure
  assert_output --partial "LABEL_COLOR must be in #RRGGBB format"
}

@test "create-label fails when label creation fails" {
  export MOCK_GH_FAIL_LABEL_CREATE="true"

  run bash "${REPO_ROOT}/scripts/create-label.sh"
  assert_failure
  assert_output --partial "Could not ensure label"
}

# ── add-label.sh ───────────────────────────────────────────────────

@test "add-label ensures label exists and adds it to PR" {
  run bash "${REPO_ROOT}/scripts/add-label.sh"
  assert_success

  run cat "${MOCK_DIR}/gh_calls.log"
  assert_output --partial "label create migrated"
  assert_output --partial "--color #2B8383"
  assert_output --partial "--description Migration script has been run"
  assert_output --partial "pr edit 42 --add-label migrated"
}

@test "add-label fails when create-label fails" {
  export MOCK_GH_FAIL_LABEL_CREATE="true"

  run bash "${REPO_ROOT}/scripts/add-label.sh"
  assert_failure
  assert_output --partial "Could not ensure label"
}

@test "add-label fails when PR number is missing" {
  unset PR_NUMBER

  run bash "${REPO_ROOT}/scripts/add-label.sh"
  assert_failure
  assert_output --partial "PR_NUMBER is required"
}

@test "add-label fails when PR number is empty" {
  export PR_NUMBER=""

  run bash "${REPO_ROOT}/scripts/add-label.sh"
  assert_failure
  assert_output --partial "PR_NUMBER is required"
}

@test "add-label fails when gh pr edit fails" {
  export MOCK_GH_FAIL_PR_EDIT="true"

  run bash "${REPO_ROOT}/scripts/add-label.sh"
  assert_failure
  assert_output --partial "Could not add label"
}

# ── remove-label.sh ────────────────────────────────────────────────

@test "remove-label removes label when present" {
  export LABEL_NAME="intervention-pending"
  export MOCK_GH_VIEW_LABELS="intervention-pending"

  run bash "${REPO_ROOT}/scripts/remove-label.sh"
  assert_success

  run cat "${MOCK_DIR}/gh_calls.log"
  assert_output --partial "pr edit 42 --remove-label intervention-pending"
}

@test "remove-label skips removal when label is absent" {
  export LABEL_NAME="intervention-pending"
  export MOCK_GH_VIEW_LABELS="migrated"

  run bash "${REPO_ROOT}/scripts/remove-label.sh"
  assert_success
  assert_output --partial "nothing to remove"

  run cat "${MOCK_DIR}/gh_calls.log"
  refute_output --partial "--remove-label intervention-pending"
}

@test "remove-label removes label among multiple labels" {
  export LABEL_NAME="intervention-pending"
  MOCK_GH_VIEW_LABELS="$(printf '%s\n%s\n%s' "migrated" "intervention-pending" "auto-merged")"
  export MOCK_GH_VIEW_LABELS

  run bash "${REPO_ROOT}/scripts/remove-label.sh"
  assert_success

  run cat "${MOCK_DIR}/gh_calls.log"
  assert_output --partial "pr edit 42 --remove-label intervention-pending"
}

@test "remove-label does not match substring labels" {
  export LABEL_NAME="pending"
  export MOCK_GH_VIEW_LABELS="intervention-pending"

  run bash "${REPO_ROOT}/scripts/remove-label.sh"
  assert_success
  assert_output --partial "nothing to remove"

  run cat "${MOCK_DIR}/gh_calls.log"
  refute_output --partial "--remove-label pending"
}

@test "remove-label fails when gh pr view fails" {
  export LABEL_NAME="intervention-pending"
  export MOCK_GH_PR_VIEW_EXIT="1"

  run bash "${REPO_ROOT}/scripts/remove-label.sh"
  assert_failure
}

@test "remove-label fails when removal call fails" {
  export LABEL_NAME="intervention-pending"
  export MOCK_GH_VIEW_LABELS="intervention-pending"
  export MOCK_GH_FAIL_PR_EDIT="true"

  run bash "${REPO_ROOT}/scripts/remove-label.sh"
  assert_failure
  assert_output --partial "Could not remove label"
}
