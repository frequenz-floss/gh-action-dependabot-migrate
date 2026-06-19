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
