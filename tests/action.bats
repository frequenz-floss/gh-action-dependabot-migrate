# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Tests for composite action wiring that is not covered by helper scripts.

setup() {
  load test-helper/common
  _common_setup
}

teardown() {
  _common_teardown
}

_action_step_block() {
  STEP_NAME="$1"
  IN_STEP="false"

  while IFS= read -r LINE; do
    if [ "$LINE" = "    - name: ${STEP_NAME}" ]; then
      IN_STEP="true"
    elif [ "$IN_STEP" = "true" ]; then
      case "$LINE" in
        "    - name: "*) break ;;
      esac
    fi

    if [ "$IN_STEP" = "true" ]; then
      printf '%s\n' "$LINE"
    fi
  done <"${REPO_ROOT}/action.yml"
}

@test "add labels is gated on migration persistence failures" {
  run _action_step_block "Add labels"
  assert_success

  assert_output --partial "always()"
  assert_output --partial "steps.run-migration.outputs.migration_ran == 'true'"
  assert_output --partial "steps.setup-git.conclusion != 'failure'"
  assert_output --partial "steps.build-commit-message.conclusion != 'failure'"
  assert_output --partial "steps.commit-migration-local.conclusion != 'failure'"
  assert_output --partial "steps.commit-migration-graphql.conclusion != 'failure'"
  assert_output --partial "steps.commit-result.conclusion != 'failure'"
  assert_output --partial "steps.push-migration.conclusion != 'failure'"
}

@test "persistence steps expose ids used by the labels gate" {
  run _action_step_block "Set up Git"
  assert_success
  assert_output --partial "id: setup-git"

  run _action_step_block "Build commit message"
  assert_success
  assert_output --partial "id: build-commit-message"

  run _action_step_block "Commit migration changes (local git)"
  assert_success
  assert_output --partial "id: commit-migration-local"

  run _action_step_block "Commit migration changes (GraphQL)"
  assert_success
  assert_output --partial "id: commit-migration-graphql"

  run _action_step_block "Record commit result"
  assert_success
  assert_output --partial "id: commit-result"

  run _action_step_block "Push migration changes"
  assert_success
  assert_output --partial "id: push-migration"
}

@test "check-status is wired to check-status.sh with marker + label envs" {
  run _action_step_block "Check migration status"
  assert_success

  assert_output --partial "id: check-status"
  assert_output --partial "LABEL_MIGRATED: \${{ inputs.migrated-label }}"
  assert_output --partial "LABEL_PENDING: \${{ inputs.intervention-pending-label }}"
  assert_output --partial "LABEL_DONE: \${{ inputs.intervention-done-label }}"
  assert_output --partial "MIGRATION_MARKER: \"Applied-by: frequenz-floss/gh-action-dependabot-migrate\""
  assert_output --partial "scripts/check-status.sh"
}

@test "build commit message embeds the migration marker" {
  run _action_step_block "Build commit message"
  assert_success

  assert_output --partial "MIGRATION_MARKER: \"Applied-by: frequenz-floss/gh-action-dependabot-migrate\""
  assert_output --partial "\"\$MIGRATION_MARKER\""
}

@test "migration marker literal is consistent across steps" {
  # Both the writer (build-commit-message) and the reader (check-status)
  # MUST hold the same literal, or the self-heal detection breaks.
  MARKER_COUNT=$(grep -c \
    'MIGRATION_MARKER: "Applied-by: frequenz-floss/gh-action-dependabot-migrate"' \
    "${REPO_ROOT}/action.yml")
  [ "$MARKER_COUNT" -eq 2 ]
}

@test "action.yml has no dangling recreate-label references" {
  # Option A's command-label surface must be fully removed.
  run grep -F "recreate-label" "${REPO_ROOT}/action.yml"
  assert_failure

  run grep -F "handle-recreate" "${REPO_ROOT}/action.yml"
  assert_failure

  run grep -F "HANDLE_RECREATE_CONCLUSION" "${REPO_ROOT}/action.yml"
  assert_failure
}
