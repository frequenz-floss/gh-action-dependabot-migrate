# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Unit tests for check-status.sh.

setup() {
  load test-helper/common
  _common_setup

  export PR_NUMBER="42"
  export REPO="test-org/test-repo"
  export GH_TOKEN="test-token"
  export LABEL_MIGRATED="migrated"
  export LABEL_PENDING="intervention-pending"
  export LABEL_DONE="intervention-done"
  export MIGRATION_MARKER="Applied-by: frequenz-floss/gh-action-dependabot-migrate"
  export ACTION_PATH="${REPO_ROOT}"

  # Mock gh:
  #   `pr view` reads a simple label state file (one label per line);
  #   `api --paginate /repos/.../pulls/.../commits --jq ...` echoes
  #      MOCK_GH_COMMIT_MESSAGES (jq extracts .commit.message so we just
  #      emit that verbatim);
  #   `pr edit --remove-label` updates the label state file.
  cat >"${MOCK_DIR}/gh" <<'MOCK_GH'
#!/usr/bin/env bash

LOG_FILE="${MOCK_DIR}/gh_calls.log"
STATE_FILE="${MOCK_DIR}/gh_labels"
printf '%s\n' "$*" >>"$LOG_FILE"

_init_labels() {
  if [ ! -f "$STATE_FILE" ]; then
    printf '%s\n' "${MOCK_GH_VIEW_LABELS:-}" >"$STATE_FILE"
  fi
}

if [ "$1" = "pr" ] && [ "$2" = "view" ]; then
  if [ "$#" -ne 9 ] || [ "$3" != "$PR_NUMBER" ] || \
    [ "$4" != "--repo" ] || [ "$5" != "$REPO" ] || \
    [ "$6" != "--json" ] || [ "$7" != "labels" ] || \
    [ "$8" != "-q" ] || [ "$9" != ".labels[].name" ]; then
    printf 'unexpected gh pr view args: %s\n' "$*" >&2
    exit 1
  fi

  _init_labels
  while IFS= read -r LABEL; do
    printf '%s\n' "$LABEL"
  done <"$STATE_FILE"
  exit 0
fi

if [ "$1" = "api" ]; then
  # Emulate `gh api --paginate /repos/.../commits --jq '.[].commit.message'`
  # by echoing MOCK_GH_COMMIT_MESSAGES verbatim.
  EXPECTED_ENDPOINT="/repos/${REPO}/pulls/${PR_NUMBER}/commits"
  if [ "$#" -ne 5 ] || [ "$2" != "--paginate" ] || \
    [ "$3" != "$EXPECTED_ENDPOINT" ] || [ "$4" != "--jq" ] || \
    [ "$5" != ".[].commit.message" ]; then
    printf 'unexpected gh api args: %s\n' "$*" >&2
    exit 1
  fi

  printf '%s\n' "${MOCK_GH_COMMIT_MESSAGES:-}"
  exit 0
fi

if [ "$1" = "pr" ] && [ "$2" = "edit" ]; then
  if [ "$#" -ne 7 ] || [ "$3" != "$PR_NUMBER" ] || \
    [ "$4" != "--remove-label" ] || [ "$6" != "--repo" ] || \
    [ "$7" != "$REPO" ]; then
    printf 'unexpected gh pr edit args: %s\n' "$*" >&2
    exit 1
  fi

  _init_labels
  REMOVE_LABEL="$5"
  TMP_FILE="${STATE_FILE}.tmp"
  while IFS= read -r LABEL; do
    if [ "$LABEL" = "$REMOVE_LABEL" ]; then
      continue
    fi
    printf '%s\n' "$LABEL"
  done <"$STATE_FILE" >"$TMP_FILE"
  mv "$TMP_FILE" "$STATE_FILE"
  exit 0
fi

exit 0
MOCK_GH
  chmod +x "${MOCK_DIR}/gh"
}

teardown() {
  _common_teardown
}

# ── Migrated label absent ────────────────────────────────────────

@test "no migrated label sets already_migrated=false" {
  export MOCK_GH_VIEW_LABELS=""

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "already_migrated=false"
}

@test "no migrated label skips the commit history check" {
  export MOCK_GH_VIEW_LABELS=""

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  # No `gh api` call for commits when the label is absent.
  run cat "${MOCK_DIR}/gh_calls.log"
  refute_output --partial "api "
  refute_output --partial "/pulls/"
}

@test "unrelated labels do not set already_migrated" {
  export MOCK_GH_VIEW_LABELS="some-other-label"

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "already_migrated=false"
}

# ── Migrated label present, marker in history ────────────────────

@test "migrated label + marker in history sets already_migrated=true" {
  export MOCK_GH_VIEW_LABELS="$LABEL_MIGRATED"
  MOCK_GH_COMMIT_MESSAGES="$(printf '%s\n' \
    "Apply migration from 0.5.0 to 0.6.0" \
    "" \
    "Applied-by: frequenz-floss/gh-action-dependabot-migrate")"
  export MOCK_GH_COMMIT_MESSAGES

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "already_migrated=true"
}

@test "migrated label + marker in history does not remove labels" {
  export MOCK_GH_VIEW_LABELS="$LABEL_MIGRATED"
  export MOCK_GH_COMMIT_MESSAGES="Applied-by: frequenz-floss/gh-action-dependabot-migrate"

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  run cat "${MOCK_DIR}/gh_calls.log"
  refute_output --partial "--remove-label"
}

# ── Migrated label present, marker missing (self-heal) ───────────

@test "migrated label without marker sets already_migrated=false" {
  export MOCK_GH_VIEW_LABELS="$LABEL_MIGRATED"
  export MOCK_GH_COMMIT_MESSAGES="Bump some-dep from 1.0.0 to 1.1.0"

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "already_migrated=false"
}

@test "self-heal removes the migrated label" {
  export MOCK_GH_VIEW_LABELS="$LABEL_MIGRATED"
  export MOCK_GH_COMMIT_MESSAGES="Bump some-dep from 1.0.0 to 1.1.0"

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  run cat "${MOCK_DIR}/gh_calls.log"
  assert_output --partial "pr edit 42 --remove-label migrated"
}

@test "self-heal removes intervention-pending when present" {
  MOCK_GH_VIEW_LABELS="$(printf '%s\n%s' "$LABEL_MIGRATED" "$LABEL_PENDING")"
  export MOCK_GH_VIEW_LABELS
  export MOCK_GH_COMMIT_MESSAGES="Bump some-dep from 1.0.0 to 1.1.0"

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  run cat "${MOCK_DIR}/gh_calls.log"
  assert_output --partial "pr edit 42 --remove-label intervention-pending"
}

@test "self-heal removes intervention-done when present" {
  MOCK_GH_VIEW_LABELS="$(printf '%s\n%s' "$LABEL_MIGRATED" "$LABEL_DONE")"
  export MOCK_GH_VIEW_LABELS
  export MOCK_GH_COMMIT_MESSAGES="Bump some-dep from 1.0.0 to 1.1.0"

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  run cat "${MOCK_DIR}/gh_calls.log"
  assert_output --partial "pr edit 42 --remove-label intervention-done"
}

@test "self-heal emits an explanatory log line" {
  export MOCK_GH_VIEW_LABELS="$LABEL_MIGRATED"
  export MOCK_GH_COMMIT_MESSAGES="Bump some-dep from 1.0.0 to 1.1.0"

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success
  assert_output --partial "no migration commit on PR head"
}

@test "self-heal re-reads labels after removing them" {
  MOCK_GH_VIEW_LABELS="$(printf '%s\n%s' "$LABEL_MIGRATED" "$LABEL_PENDING")"
  export MOCK_GH_VIEW_LABELS
  export MOCK_GH_COMMIT_MESSAGES="Bump some-dep from 1.0.0 to 1.1.0"

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  # After the self-heal removals, check-status must re-read the labels
  # so the intervention_pending output reflects the post-heal state.
  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "intervention_pending=false"
}

# ── Intervention-pending output ──────────────────────────────────

@test "intervention-pending label present sets intervention_pending=true" {
  export MOCK_GH_VIEW_LABELS="$LABEL_PENDING"

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "intervention_pending=true"
}

@test "intervention-pending label absent sets intervention_pending=false" {
  export MOCK_GH_VIEW_LABELS=""

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "intervention_pending=false"
}

# ── Custom labels ────────────────────────────────────────────────

@test "custom label names are respected" {
  export LABEL_MIGRATED="tool:migration:migrated"
  export LABEL_PENDING="tool:migration:intervention-pending"
  export MOCK_GH_VIEW_LABELS="tool:migration:migrated"
  export MOCK_GH_COMMIT_MESSAGES="Applied-by: frequenz-floss/gh-action-dependabot-migrate"

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "already_migrated=true"
}

# ── Marker matching ──────────────────────────────────────────────

@test "marker match is literal (grep -F), not regex" {
  # Ensure a message containing "Applied-by:" but with a different
  # value does not falsely match.
  export MOCK_GH_VIEW_LABELS="$LABEL_MIGRATED"
  export MOCK_GH_COMMIT_MESSAGES="Applied-by: some-other-action"

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "already_migrated=false"
}

@test "marker match requires an exact line" {
  export MOCK_GH_VIEW_LABELS="$LABEL_MIGRATED"
  export MOCK_GH_COMMIT_MESSAGES="prefix Applied-by: frequenz-floss/gh-action-dependabot-migrate"

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "already_migrated=false"
}

@test "marker match handles large output after early marker" {
  export MOCK_GH_VIEW_LABELS="$LABEL_MIGRATED"
  LONG_OUTPUT=$(printf '%70000s' "")
  MOCK_GH_COMMIT_MESSAGES="$(printf '%s\n%s' \
    "$MIGRATION_MARKER" "$LONG_OUTPUT")"
  export MOCK_GH_COMMIT_MESSAGES

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "already_migrated=true"
}

@test "marker match survives extra commits in history" {
  export MOCK_GH_VIEW_LABELS="$LABEL_MIGRATED"
  MOCK_GH_COMMIT_MESSAGES="$(printf '%s\n%s\n%s' \
    "Bump some-dep from 1.0.0 to 2.0.0" \
    "Apply migration from 1.0.0 to 2.0.0" \
    "Applied-by: frequenz-floss/gh-action-dependabot-migrate")"
  export MOCK_GH_COMMIT_MESSAGES

  run bash "${REPO_ROOT}/scripts/check-status.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "already_migrated=true"
}
