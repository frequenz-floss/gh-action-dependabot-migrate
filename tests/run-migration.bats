# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Unit tests for run-migration.sh.

setup() {
  load test-helper/common
  _common_setup

  # Default environment — a simple v0.x minor bump.
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"
  export SCRIPT_URL_TEMPLATE="https://example.com/migrate-{version}.py"
  export ITERATE_V0_MINORS="true"
  export MIGRATION_TOKEN_INPUT=""
}

teardown() {
  _common_teardown
}

# ── Version list construction ──────────────────────────────────────

@test "v0.x bump with iterate builds intermediate versions" {
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"
  export ITERATE_V0_MINORS="true"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v0.14.0 v0.15.0"
}

@test "v0.x bump without iterate targets only new version" {
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"
  export ITERATE_V0_MINORS="false"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v0.15.0"
}

@test "v1+ bump targets only new version" {
  export OLD_VERSION="1.2.0"
  export NEW_VERSION="1.4.0"
  export ITERATE_V0_MINORS="true"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v1.4.0"
}

@test "cross-major bump targets only new version" {
  export OLD_VERSION="0.9.0"
  export NEW_VERSION="1.0.0"
  export ITERATE_V0_MINORS="true"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v1.0.0"
}

@test "single minor bump produces one version" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export ITERATE_V0_MINORS="true"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v0.6.0"
}

@test "same-minor v0.x bump produces no versions and exits early" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.5.1"
  export ITERATE_V0_MINORS="true"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "No versions to migrate"

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "migration_ran=false"
  assert_output --partial "overall_exit=0"
  assert_output --partial "No versions to migrate."
}

@test "same major version v1+ does not iterate minors" {
  export OLD_VERSION="2.1.0"
  export NEW_VERSION="2.5.0"
  export ITERATE_V0_MINORS="true"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v2.5.0"
}

# ── URL template expansion ─────────────────────────────────────────

@test "URL template replaces {version} placeholder" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export SCRIPT_URL_TEMPLATE="https://example.com/repo/migrate-{version}.py"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "<https://example.com/repo/migrate-v0.6.0.py>"
}

@test "URL template with multiple {version} placeholders" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export SCRIPT_URL_TEMPLATE="https://example.com/{version}/migrate-{version}.py"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "<https://example.com/v0.6.0/migrate-v0.6.0.py>"
}

# ── Successful migration ──────────────────────────────────────────

@test "successful migration sets overall_exit=0" {
  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "overall_exit=0"
  assert_output --partial "migration_ran=true"
}

@test "successful migration includes script output in report" {
  export MOCK_CURL_SCRIPT_BODY='print("All changes applied successfully")'

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "All changes applied successfully"
}

# ── Failed migration ──────────────────────────────────────────────

@test "failed migration script sets overall_exit=1" {
  export MOCK_CURL_SCRIPT_BODY='import sys; print("Migration failed"); sys.exit(1)'

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  # The script itself does not exit non-zero — it captures failures.
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "overall_exit=1"
  assert_output --partial "migration_ran=true"
}

@test "failed migration includes error output in report" {
  export MOCK_CURL_SCRIPT_BODY='import sys; print("Error: missing dependency"); sys.exit(1)'

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "Error: missing dependency"
}

# ── HTTP errors ───────────────────────────────────────────────────

@test "HTTP 404 sets overall_exit=1 and emits error annotation" {
  export MOCK_CURL_HTTP_CODE="404"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  assert_output --partial "::error::Migration script not found"
  assert_output --partial "HTTP 404"

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "overall_exit=1"
}

@test "HTTP 404 includes error in report" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export MOCK_CURL_HTTP_CODE="404"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "Migration script not found (HTTP 404)"
}

@test "HTTP 500 is handled the same as 404" {
  export MOCK_CURL_HTTP_CODE="500"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  assert_output --partial "::error::Migration script not found"
  assert_output --partial "HTTP 500"

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "overall_exit=1"
}

# ── Migration token handling ──────────────────────────────────────

@test "migration token is passed to script as GITHUB_TOKEN" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export MIGRATION_TOKEN_INPUT="test-token-12345"
  export MOCK_CURL_SCRIPT_BODY='import os; print("TOKEN=" + os.environ.get("GITHUB_TOKEN", "UNSET"))'

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "TOKEN=test-token-12345"
}

@test "migration token is also passed as GH_TOKEN" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export MIGRATION_TOKEN_INPUT="test-token-12345"
  export MOCK_CURL_SCRIPT_BODY='import os; print("GH=" + os.environ.get("GH_TOKEN", "UNSET"))'

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "GH=test-token-12345"
}

@test "without migration token GITHUB_TOKEN is unset" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export MIGRATION_TOKEN_INPUT=""
  # Set these in the environment to verify they get explicitly unset.
  export GITHUB_TOKEN="should-be-unset"
  export GH_TOKEN="should-be-unset"
  export MOCK_CURL_SCRIPT_BODY='import os; print("TOKEN=" + os.environ.get("GITHUB_TOKEN", "UNSET"))'

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "TOKEN=UNSET"
}

# ── ANSI stripping ────────────────────────────────────────────────

@test "ANSI codes are stripped from report but preserved in logs" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export MOCK_CURL_SCRIPT_BODY=$'print("\\033[31mRed text\\033[0m")'

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  # The report in GITHUB_OUTPUT should have ANSI codes stripped.
  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "Red text"
  refute_output --partial $'\033[31m'
}

# ── Multiple versions with mixed results ──────────────────────────

@test "mixed results across versions sets overall_exit=1" {
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"
  export ITERATE_V0_MINORS="true"
  # First call (v0.14.0) succeeds, second call (v0.15.0) fails.
  export MOCK_CURL_SCRIPT_BODY_1='print("v0.14.0 OK")'
  export MOCK_CURL_SCRIPT_BODY_2='import sys; print("v0.15.0 FAIL"); sys.exit(1)'

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  assert_output --partial "v0.14.0 OK"
  assert_output --partial "v0.15.0 FAIL"

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "overall_exit=1"
}

@test "all versions succeeding sets overall_exit=0" {
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"
  export ITERATE_V0_MINORS="true"
  export MOCK_CURL_SCRIPT_BODY_1='print("v0.14.0 OK")'
  export MOCK_CURL_SCRIPT_BODY_2='print("v0.15.0 OK")'

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "overall_exit=0"
}

@test "HTTP error on first version does not stop second version" {
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"
  export ITERATE_V0_MINORS="true"
  # First call fails with 404, second succeeds.
  export MOCK_CURL_HTTP_CODE_1="404"
  export MOCK_CURL_SCRIPT_BODY_2='print("v0.15.0 OK")'

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  assert_output --partial "::error::Migration script not found"
  assert_output --partial "v0.15.0 OK"

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "overall_exit=1"
}

# ── GITHUB_OUTPUT format ──────────────────────────────────────────

@test "GITHUB_OUTPUT contains all required keys" {
  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "overall_exit="
  assert_output --partial "report<<REPORT_EOF"
  assert_output --partial "REPORT_EOF"
  assert_output --partial "migration_ran=true"
}

@test "report includes version header and script URL line" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export SCRIPT_URL_TEMPLATE="https://example.com/migrate-{version}.py"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "=== v0.6.0 ========================================================="
  assert_output --partial "Script URL: https://example.com/migrate-v0.6.0.py"
}
