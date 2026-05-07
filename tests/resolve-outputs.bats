# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Unit tests for resolve-outputs.sh.

setup() {
  load test-helper/common
  _common_setup

  export VALIDATE_INPUTS_CONCLUSION="success"
  export CHECK_STATUS_CONCLUSION="success"
  export HANDLE_INTERVENTION_CONCLUSION="skipped"
  export DEPENDABOT_METADATA_CONCLUSION="skipped"
  export CHECK_UPDATE_CONCLUSION="skipped"
  export RUN_MIGRATION_CONCLUSION="skipped"
  export HANDLE_PATCH_UPDATE_CONCLUSION="skipped"
  export SCRIPT_MIGRATION_RAN=""
  export SCRIPT_OVERALL_EXIT=""
  export NEEDS_MIGRATION=""
  export SCRIPT_COMMIT_MADE=""
  export ALREADY_MIGRATED="false"
  export INTERVENTION_PENDING="false"
}

teardown() {
  _common_teardown
}

@test "prefers run-migration outputs when present" {
  export SCRIPT_MIGRATION_RAN="true"
  export SCRIPT_OVERALL_EXIT="1"
  export NEEDS_MIGRATION="true"
  export SCRIPT_COMMIT_MADE="true"

  run bash "${REPO_ROOT}/scripts/resolve-outputs.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "migration_ran=true"
  assert_output --partial "overall_exit=1"
  assert_output --partial "needs_migration=true"
  assert_output --partial "commit_made=true"
}

@test "patch-only short-circuit resolves clean handled outputs" {
  export DEPENDABOT_METADATA_CONCLUSION="success"
  export CHECK_UPDATE_CONCLUSION="success"
  export NEEDS_MIGRATION="false"

  run bash "${REPO_ROOT}/scripts/resolve-outputs.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "migration_ran=true"
  assert_output --partial "overall_exit=0"
  assert_output --partial "needs_migration=false"
  assert_output --partial "commit_made=false"
}

@test "failed patch-only handling resolves failure output" {
  export DEPENDABOT_METADATA_CONCLUSION="success"
  export CHECK_UPDATE_CONCLUSION="success"
  export HANDLE_PATCH_UPDATE_CONCLUSION="failure"
  export NEEDS_MIGRATION="false"

  run bash "${REPO_ROOT}/scripts/resolve-outputs.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "migration_ran=true"
  assert_output --partial "overall_exit=1"
  assert_output --partial "needs_migration=false"
  assert_output --partial "commit_made=false"
}

@test "already-migrated pending intervention resolves failure output" {
  export ALREADY_MIGRATED="true"
  export INTERVENTION_PENDING="true"

  run bash "${REPO_ROOT}/scripts/resolve-outputs.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "migration_ran=true"
  assert_output --partial "overall_exit=1"
  assert_output --partial "needs_migration=false"
  assert_output --partial "commit_made=false"
}

@test "successful intervention handling resolves clean re-trigger output" {
  export ALREADY_MIGRATED="true"
  export INTERVENTION_PENDING="true"
  export HANDLE_INTERVENTION_CONCLUSION="success"

  run bash "${REPO_ROOT}/scripts/resolve-outputs.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "migration_ran=true"
  assert_output --partial "overall_exit=0"
  assert_output --partial "needs_migration=false"
  assert_output --partial "commit_made=false"
}

@test "failed pre-check resolves failure without migration" {
  export VALIDATE_INPUTS_CONCLUSION="failure"

  run bash "${REPO_ROOT}/scripts/resolve-outputs.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "migration_ran=false"
  assert_output --partial "overall_exit=1"
  assert_output --partial "needs_migration=false"
  assert_output --partial "commit_made=false"
}
