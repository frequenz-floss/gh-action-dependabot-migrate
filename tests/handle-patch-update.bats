# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Unit tests for handle-patch-update.sh.

setup() {
  load test-helper/common
  _common_setup

  export PR_URL="https://github.com/test-org/test-repo/pull/42"
  export PR_NUMBER="42"
  export REPO="test-org/test-repo"
  export GH_TOKEN="test-token"
  export TOKEN="test-token"
  export AUTO_MERGED_LABEL="tool:migration:auto-merged"
  export AUTO_MERGED_LABEL_COLOR="#0E8A16"
  export AUTO_MERGED_LABEL_DESCRIPTION="PR was auto-merged by automation"
  export REPORT_TITLE="Dependabot Migration"

  GITHUB_STEP_SUMMARY="$(mktemp)"
  export GITHUB_STEP_SUMMARY

  cat >"${MOCK_DIR}/gh" <<'MOCK_GH'
#!/usr/bin/env bash

LOG_FILE="${MOCK_DIR}/gh_calls.log"
printf '%s\n' "$*" >>"$LOG_FILE"

if [ "$1" = "label" ] && [ "$2" = "create" ]; then
  exit 0
fi

if [ "$1" = "pr" ] && [ "$2" = "edit" ]; then
  exit 0
fi

if [ "$1" = "pr" ] && [ "$2" = "review" ]; then
  exit 0
fi

if [ "$1" = "pr" ] && [ "$2" = "merge" ]; then
  exit 0
fi

if [ "$1" = "pr" ] && [ "$2" = "comment" ]; then
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

# ── Job summary ───────────────────────────────────────────────────

@test "always writes patch-only job summary" {
  run bash "${REPO_ROOT}/scripts/handle-patch-update.sh"
  assert_success

  run cat "${GITHUB_STEP_SUMMARY}"
  assert_output --partial "## Dependabot Migration"
  assert_output --partial "Patch-only update"
  assert_output --partial "no migration needed"
}

@test "uses custom report title in patch-only outputs" {
  export TOKEN=""
  export REPORT_TITLE="Repo Config Migration"

  run bash "${REPO_ROOT}/scripts/handle-patch-update.sh"
  assert_success

  run cat "${GITHUB_STEP_SUMMARY}"
  assert_output --partial "## Repo Config Migration"

  run cat "${MOCK_DIR}/comment_body.txt"
  assert_output --partial "## Repo Config Migration"
}

# ── Token provided: auto-merge path ──────────────────────────────

@test "approves and merges PR when token is provided" {
  run bash "${REPO_ROOT}/scripts/handle-patch-update.sh"
  assert_success

  run cat "${MOCK_DIR}/gh_calls.log"
  assert_output --partial "pr review --approve"
  assert_output --partial "pr merge --auto --merge"
}

@test "adds auto-merged label when token is provided" {
  run bash "${REPO_ROOT}/scripts/handle-patch-update.sh"
  assert_success

  run cat "${MOCK_DIR}/gh_calls.log"
  assert_output --partial "label create ${AUTO_MERGED_LABEL}"
  assert_output --partial "pr edit 42 --add-label ${AUTO_MERGED_LABEL}"
}

@test "does not post comment when token is provided" {
  run bash "${REPO_ROOT}/scripts/handle-patch-update.sh"
  assert_success

  [ ! -f "${MOCK_DIR}/comment_body.txt" ]
}

# ── No token: manual review path ─────────────────────────────────

@test "posts comment when no token is provided" {
  export TOKEN=""

  run bash "${REPO_ROOT}/scripts/handle-patch-update.sh"
  assert_success

  run cat "${MOCK_DIR}/comment_body.txt"
  assert_output --partial "## Dependabot Migration"
  assert_output --partial "Patch-only update detected"
  assert_output --partial "no migration is needed"
}

@test "no-token comment has no mid-paragraph newlines" {
  export TOKEN=""

  run bash "${REPO_ROOT}/scripts/handle-patch-update.sh"
  assert_success

  COMMENT=$(cat "${MOCK_DIR}/comment_body.txt")
  # The paragraph about manual review should be a single line.
  LINE=$(echo "$COMMENT" | grep "No \`token\` input was provided")
  echo "$LINE" | grep -q "merge this PR manually"
}

@test "appends no-token note to job summary" {
  export TOKEN=""

  run bash "${REPO_ROOT}/scripts/handle-patch-update.sh"
  assert_success

  run cat "${GITHUB_STEP_SUMMARY}"
  assert_output --partial "No \`token\` input provided"
  assert_output --partial "manual review and merge"
}

@test "does not approve or merge when no token" {
  export TOKEN=""

  run bash "${REPO_ROOT}/scripts/handle-patch-update.sh"
  assert_success

  run cat "${MOCK_DIR}/gh_calls.log"
  refute_output --partial "pr review"
  refute_output --partial "pr merge"
}

@test "does not add auto-merged label when no token" {
  export TOKEN=""

  run bash "${REPO_ROOT}/scripts/handle-patch-update.sh"
  assert_success

  run cat "${MOCK_DIR}/gh_calls.log"
  refute_output --partial "label create"
  refute_output --partial "--add-label"
}
