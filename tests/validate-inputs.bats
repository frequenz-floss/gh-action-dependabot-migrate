# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Unit tests for validate-inputs.sh.

setup() {
  load test-helper/common
  _common_setup

  export TOKEN=""
  export AUTO_MERGE_ON_CHANGES="false"
  export SCRIPT_URL_TEMPLATE="https://example.com/migrate-{version}.py"
  export MIGRATION_SCRIPT=""
  export VERSION_ITERATION=""
  export IF_NO_ITERATIONS=""
  export ITERATE_V0_MINORS=""
}

teardown() {
  _common_teardown
}

@test "accepts script-url-template without migration-script" {
  run bash "${REPO_ROOT}/scripts/validate-inputs.sh"
  assert_success
}

@test "accepts migration-script without script-url-template" {
  export SCRIPT_URL_TEMPLATE=""
  export MIGRATION_SCRIPT='print("hello")'

  run bash "${REPO_ROOT}/scripts/validate-inputs.sh"
  assert_success
}

@test "rejects both script-url-template and migration-script" {
  export MIGRATION_SCRIPT='print("hello")'

  run bash "${REPO_ROOT}/scripts/validate-inputs.sh"
  assert_failure
  assert_output --partial "::error::\`script-url-template\` and \`migration-script\` are"
}

@test "rejects missing script-url-template and migration-script" {
  export SCRIPT_URL_TEMPLATE=""

  run bash "${REPO_ROOT}/scripts/validate-inputs.sh"
  assert_failure
  assert_output --partial "::error::Either \`script-url-template\` or \`migration-script\`"
}

@test "rejects auto-merge-on-changes without token" {
  export AUTO_MERGE_ON_CHANGES="true"

  run bash "${REPO_ROOT}/scripts/validate-inputs.sh"
  assert_failure
  assert_output --partial "::error::\`auto-merge-on-changes\` requires the \`token\` input."
}

@test "accepts auto-merge-on-changes with token" {
  export AUTO_MERGE_ON_CHANGES="true"
  export TOKEN="test-token"

  run bash "${REPO_ROOT}/scripts/validate-inputs.sh"
  assert_success
}

@test "accepts valid version-iteration values" {
  for VALUE in false major minor patch; do
    export VERSION_ITERATION="$VALUE"

    run bash "${REPO_ROOT}/scripts/validate-inputs.sh"
    assert_success
  done
}

@test "rejects invalid version-iteration value" {
  export VERSION_ITERATION="all"

  run bash "${REPO_ROOT}/scripts/validate-inputs.sh"
  assert_failure
  assert_output --partial "::error::\`version-iteration\` must be one of:"
}

@test "accepts valid deprecated iterate-v0-minors values" {
  export ITERATE_V0_MINORS="true"

  run bash "${REPO_ROOT}/scripts/validate-inputs.sh"
  assert_success

  export ITERATE_V0_MINORS="false"

  run bash "${REPO_ROOT}/scripts/validate-inputs.sh"
  assert_success
}

@test "rejects invalid iterate-v0-minors value" {
  export ITERATE_V0_MINORS="maybe"

  run bash "${REPO_ROOT}/scripts/validate-inputs.sh"
  assert_failure
  assert_output --partial "::error::\`iterate-v0-minors\` must be one of: true, false."
}

@test "rejects iterate-v0-minors with version-iteration" {
  export ITERATE_V0_MINORS="true"
  export VERSION_ITERATION="minor"

  run bash "${REPO_ROOT}/scripts/validate-inputs.sh"
  assert_failure
  assert_output --partial "::error::\`version-iteration\` and \`iterate-v0-minors\` are mutually exclusive"
}

@test "accepts valid if-no-iterations values" {
  for VALUE in "" error pass; do
    export IF_NO_ITERATIONS="$VALUE"

    run bash "${REPO_ROOT}/scripts/validate-inputs.sh"
    assert_success
  done
}

@test "rejects invalid if-no-iterations value" {
  export IF_NO_ITERATIONS="skip"

  run bash "${REPO_ROOT}/scripts/validate-inputs.sh"
  assert_failure
  assert_output --partial "::error::\`if-no-iterations\` must be one of: error, pass."
}
