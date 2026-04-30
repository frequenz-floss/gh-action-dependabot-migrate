# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Unit tests for run-migration.sh.

setup() {
  load test-helper/common
  _common_setup

  # Default environment — a simple v0.x minor bump with URL mode.
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"
  export UPDATED_DEPENDENCIES_JSON='[{"dependencyName":"example","prevVersion":"0.13.1","newVersion":"0.15.0","updateType":"version-update:semver-minor"}]'
  export SCRIPT_URL_TEMPLATE="https://example.com/migrate-{version}.py"
  export MIGRATION_TOKEN_INPUT=""
  unset ITERATE_V0_MINORS
  unset VERSION_ITERATION
  unset IF_NO_ITERATIONS
  unset MIGRATION_SCRIPT
}

teardown() {
  _common_teardown
}

# ── Version list construction (deprecated iterate-v0-minors) ───────
#
# These tests verify backward compatibility when VERSION_ITERATION is
# not set and the deprecated ITERATE_V0_MINORS input is used.

@test "v0.x bump with iterate builds intermediate versions" {
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"
  export ITERATE_V0_MINORS="true"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "::warning::\`iterate-v0-minors\` is deprecated."
  assert_output --partial "Migration versions: v0.14.0 v0.15.0"
}

@test "v0.x bump without iterate targets only new version" {
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"
  export ITERATE_V0_MINORS="false"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "::warning::\`iterate-v0-minors\` is deprecated."
  assert_output --partial "Migration versions: v0.15.0"
}

@test "v1+ bump targets only new version" {
  export OLD_VERSION="1.2.0"
  export NEW_VERSION="1.4.0"
  export ITERATE_V0_MINORS="true"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "::warning::\`iterate-v0-minors\` is deprecated."
  assert_output --partial "Migration versions: v1.4.0"
}

@test "cross-major bump targets only new version" {
  export OLD_VERSION="0.9.0"
  export NEW_VERSION="1.0.0"
  export ITERATE_V0_MINORS="true"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "::warning::\`iterate-v0-minors\` is deprecated."
  assert_output --partial "Migration versions: v1.0.0"
}

@test "single minor bump produces one version" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export ITERATE_V0_MINORS="true"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "::warning::\`iterate-v0-minors\` is deprecated."
  assert_output --partial "Migration versions: v0.6.0"
}

@test "same-minor v0.x bump passes as no-op (backward compat)" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.5.1"
  export ITERATE_V0_MINORS="true"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "::warning::\`iterate-v0-minors\` is deprecated."
  assert_output --partial "::notice::No versions to migrate."

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "migration_ran=true"
  assert_output --partial "overall_exit=0"
  assert_output --partial "No versions to migrate."
}

@test "same major version v1+ does not iterate minors" {
  export OLD_VERSION="2.1.0"
  export NEW_VERSION="2.5.0"
  export ITERATE_V0_MINORS="true"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "::warning::\`iterate-v0-minors\` is deprecated."
  assert_output --partial "Migration versions: v2.5.0"
}

# ── Backward compatibility: deprecated path defaults if-no-iterations ──

@test "deprecated v0.x path defaults to pass when if-no-iterations is empty" {
  # Simulates the action default (empty string).  The deprecated
  # fallback should default to "pass" so same-minor v0.x patch bumps
  # do not regress.
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.5.3"
  export ITERATE_V0_MINORS="true"
  export IF_NO_ITERATIONS=""

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "::warning::\`iterate-v0-minors\` is deprecated."
  assert_output --partial "::notice::No versions to migrate."

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "migration_ran=true"
  assert_output --partial "overall_exit=0"
}

@test "deprecated v0.x path respects explicit if-no-iterations=error" {
  # When the user explicitly sets if-no-iterations=error, the
  # deprecated fallback should NOT override it.
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.5.3"
  export ITERATE_V0_MINORS="true"
  export IF_NO_ITERATIONS="error"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_failure
  assert_output --partial "::warning::\`iterate-v0-minors\` is deprecated."
  assert_output --partial "::error::No versions to migrate."

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "migration_ran=false"
  assert_output --partial "overall_exit=1"
}

@test "version-iteration and iterate-v0-minors together is an error" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.5.3"
  export ITERATE_V0_MINORS="true"
  export VERSION_ITERATION="minor"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_failure
  assert_output --partial "::error::\`version-iteration\` and \`iterate-v0-minors\` are mutually exclusive"
}

@test "implicit default emits deprecation warning and iterates v0.x minors" {
  # Neither VERSION_ITERATION nor ITERATE_V0_MINORS is set — the
  # backward-compatible default iterates v0.x minors and warns.
  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "::warning::\`version-iteration\` is not set."
  assert_output --partial "Migration versions: v0.14.0 v0.15.0"
}

@test "implicit default for v1+ targets only new version" {
  # Non-v0.x bumps default to only the target version.
  export OLD_VERSION="1.2.0"
  export NEW_VERSION="1.4.0"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "::warning::\`version-iteration\` is not set."
  assert_output --partial "Migration versions: v1.4.0"
}

@test "implicit default same-minor v0.x patch bump passes as no-op" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.5.1"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "::warning::\`version-iteration\` is not set."
  assert_output --partial "::notice::No versions to migrate."

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "migration_ran=true"
  assert_output --partial "overall_exit=0"
}

# ── Version iteration: false mode ──────────────────────────────────

@test "version-iteration=false targets only new version" {
  export OLD_VERSION="0.1.1"
  export NEW_VERSION="2.3.4"
  export VERSION_ITERATION="false"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v2.3.4"
}

@test "version-iteration=false and iterate-v0-minors together is an error" {
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"
  export ITERATE_V0_MINORS="true"
  export VERSION_ITERATION="false"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_failure
  assert_output --partial "::error::\`version-iteration\` and \`iterate-v0-minors\` are mutually exclusive"
}

@test "invalid version-iteration value fails fast" {
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"
  export VERSION_ITERATION="micro"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_failure
  assert_output --partial "::error::VERSION_ITERATION must be one of: false, major, minor, patch."
}

@test "invalid iterate-v0-minors value fails fast" {
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"
  export ITERATE_V0_MINORS="maybe"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_failure
  assert_output --partial "::error::ITERATE_V0_MINORS must be one of: true, false."
}

# ── Version iteration: major mode ─────────────────────────────────

@test "version-iteration=major with cross-major produces boundary versions" {
  export OLD_VERSION="0.1.1"
  export NEW_VERSION="2.3.4"
  export VERSION_ITERATION="major"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v1.0.0 v2.0.0"
}

@test "version-iteration=major with same-major produces no versions" {
  export OLD_VERSION="2.1.0"
  export NEW_VERSION="2.3.4"
  export VERSION_ITERATION="major"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_failure
  assert_output --partial "::error::No versions to migrate."

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "migration_ran=false"
  assert_output --partial "overall_exit=1"
}

@test "if-no-iterations=pass treats same-major major mode as migrated" {
  export OLD_VERSION="2.1.0"
  export NEW_VERSION="2.3.4"
  export VERSION_ITERATION="major"
  export IF_NO_ITERATIONS="pass"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "::notice::No versions to migrate."

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "migration_ran=true"
  assert_output --partial "overall_exit=0"
  assert_output --partial "No versions to migrate."
}

@test "version-iteration=major with single major jump" {
  export OLD_VERSION="1.5.3"
  export NEW_VERSION="2.0.0"
  export VERSION_ITERATION="major"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v2.0.0"
}

# ── Version iteration: minor mode ─────────────────────────────────

@test "version-iteration=minor with cross-major produces major and minor boundaries" {
  export OLD_VERSION="0.1.1"
  export NEW_VERSION="2.3.4"
  export VERSION_ITERATION="minor"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v1.0.0 v2.0.0 v2.1.0 v2.2.0 v2.3.0"
}

@test "version-iteration=minor with same-major iterates minors" {
  export OLD_VERSION="2.1.0"
  export NEW_VERSION="2.5.0"
  export VERSION_ITERATION="minor"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v2.2.0 v2.3.0 v2.4.0 v2.5.0"
}

@test "version-iteration=minor with same-minor produces no versions" {
  export OLD_VERSION="2.3.1"
  export NEW_VERSION="2.3.4"
  export VERSION_ITERATION="minor"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_failure
  assert_output --partial "::error::No versions to migrate."

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "migration_ran=false"
  assert_output --partial "overall_exit=1"
}

@test "if-no-iterations=pass treats same-minor minor mode as migrated" {
  export OLD_VERSION="2.3.1"
  export NEW_VERSION="2.3.4"
  export VERSION_ITERATION="minor"
  export IF_NO_ITERATIONS="pass"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "::notice::No versions to migrate."

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "migration_ran=true"
  assert_output --partial "overall_exit=0"
  assert_output --partial "No versions to migrate."
}

@test "invalid if-no-iterations value fails" {
  export OLD_VERSION="2.1.0"
  export NEW_VERSION="2.3.4"
  export VERSION_ITERATION="false"
  export IF_NO_ITERATIONS="force-run"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_failure
  assert_output --partial "::error::IF_NO_ITERATIONS must be one of: error, pass."
}

@test "version-iteration=minor with v0.x iterates like iterate-v0-minors" {
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"
  export VERSION_ITERATION="minor"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v0.14.0 v0.15.0"
}

@test "version-iteration=minor with cross-major and new-minor=0" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="2.0.0"
  export VERSION_ITERATION="minor"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v1.0.0 v2.0.0"
}

# ── Version iteration: patch mode ─────────────────────────────────

@test "version-iteration=patch with cross-major produces all boundaries" {
  export OLD_VERSION="0.1.1"
  export NEW_VERSION="2.3.4"
  export VERSION_ITERATION="patch"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v1.0.0 v2.0.0 v2.1.0 v2.2.0 v2.3.0 v2.3.1 v2.3.2 v2.3.3 v2.3.4"
}

@test "version-iteration=patch with same-major-minor iterates patches" {
  export OLD_VERSION="2.3.1"
  export NEW_VERSION="2.3.4"
  export VERSION_ITERATION="patch"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v2.3.2 v2.3.3 v2.3.4"
}

@test "version-iteration=patch with same-major different minor" {
  export OLD_VERSION="2.1.3"
  export NEW_VERSION="2.3.2"
  export VERSION_ITERATION="patch"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v2.2.0 v2.3.0 v2.3.1 v2.3.2"
}

@test "version-iteration=patch with major-only bump" {
  export OLD_VERSION="1.5.3"
  export NEW_VERSION="2.0.0"
  export VERSION_ITERATION="patch"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v2.0.0"
}

@test "version-iteration=patch with cross-major full three-level expansion" {
  export OLD_VERSION="0.5.3"
  export NEW_VERSION="2.1.2"
  export VERSION_ITERATION="patch"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Migration versions: v1.0.0 v2.0.0 v2.1.0 v2.1.1 v2.1.2"
}

@test "version-iteration=patch with same-version produces no versions" {
  export OLD_VERSION="2.3.0"
  export NEW_VERSION="2.3.0"
  export VERSION_ITERATION="patch"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_failure
  assert_output --partial "::error::No versions to migrate."

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "migration_ran=false"
  assert_output --partial "overall_exit=1"
}

# ── if-no-iterations defaults ─────────────────────────────────────

@test "if-no-iterations defaults to error when env var is unset" {
  export OLD_VERSION="2.1.0"
  export NEW_VERSION="2.3.4"
  export VERSION_ITERATION="major"
  unset IF_NO_ITERATIONS

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_failure
  assert_output --partial "::error::No versions to migrate."
}

@test "if-no-iterations defaults to error when env var is empty" {
  export OLD_VERSION="2.1.0"
  export NEW_VERSION="2.3.4"
  export VERSION_ITERATION="major"
  export IF_NO_ITERATIONS=""

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_failure
  assert_output --partial "::error::No versions to migrate."
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

  assert_output --partial "::warning::\`iterate-v0-minors\` is deprecated."
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
  assert_output --partial "::warning::\`iterate-v0-minors\` is deprecated."

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

  assert_output --partial "::warning::\`iterate-v0-minors\` is deprecated."
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

# ── Inline script mode ────────────────────────────────────────────

@test "inline script executes and sets overall_exit=0" {
  unset SCRIPT_URL_TEMPLATE
  export MIGRATION_SCRIPT='print("Inline migration ran")'
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  assert_output --partial "Inline migration ran"

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "overall_exit=0"
  assert_output --partial "migration_ran=true"
}

@test "inline script failure sets overall_exit=1" {
  unset SCRIPT_URL_TEMPLATE
  export MIGRATION_SCRIPT='import sys; print("Inline failed"); sys.exit(1)'
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  assert_output --partial "Inline failed"

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "overall_exit=1"
  assert_output --partial "migration_ran=true"
}

@test "inline script report includes source header" {
  unset SCRIPT_URL_TEMPLATE
  export MIGRATION_SCRIPT='print("OK")'
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "=== v0.6.0 ========================================================="
  assert_output --partial "Source: inline script"
  refute_output --partial "Script URL:"
}

@test "inline script logs say inline script" {
  unset SCRIPT_URL_TEMPLATE
  export MIGRATION_SCRIPT='print("OK")'
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "(inline script)"
}

@test "inline script runs once per version in v0.x iteration" {
  unset SCRIPT_URL_TEMPLATE
  export MIGRATION_SCRIPT='import os; print("migrating " + os.environ["MIGRATION_VERSION"])'
  export OLD_VERSION="0.13.1"
  export NEW_VERSION="0.15.0"
  export ITERATE_V0_MINORS="true"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  assert_output --partial "::warning::\`iterate-v0-minors\` is deprecated."
  assert_output --partial "migrating v0.14.0"
  assert_output --partial "migrating v0.15.0"

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "overall_exit=0"
}

@test "inline script receives MIGRATION_VERSION env var" {
  unset SCRIPT_URL_TEMPLATE
  export MIGRATION_SCRIPT='import os; print("VER=" + os.environ.get("MIGRATION_VERSION", "UNSET"))'
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "VER=v0.6.0"
}

@test "inline script with migration token gets GITHUB_TOKEN" {
  unset SCRIPT_URL_TEMPLATE
  export MIGRATION_SCRIPT='import os; print("TOKEN=" + os.environ.get("GITHUB_TOKEN", "UNSET"))'
  export MIGRATION_TOKEN_INPUT="inline-test-token"
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "TOKEN=inline-test-token"
}

@test "inline script without migration token has no GITHUB_TOKEN" {
  unset SCRIPT_URL_TEMPLATE
  export MIGRATION_SCRIPT='import os; print("TOKEN=" + os.environ.get("GITHUB_TOKEN", "UNSET"))'
  export MIGRATION_TOKEN_INPUT=""
  export GITHUB_TOKEN="should-be-unset"
  export GH_TOKEN="should-be-unset"
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "TOKEN=UNSET"
}

@test "inline script with ANSI codes strips them from report" {
  unset SCRIPT_URL_TEMPLATE
  export MIGRATION_SCRIPT=$'print("\\033[31mRed inline\\033[0m")'
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success

  run cat "${GITHUB_OUTPUT}"
  assert_output --partial "Red inline"
  refute_output --partial $'\033[31m'
}

# ── MIGRATION_VERSION in URL mode ─────────────────────────────────

@test "URL mode also exposes MIGRATION_VERSION" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export MOCK_CURL_SCRIPT_BODY='import os; print("VER=" + os.environ.get("MIGRATION_VERSION", "UNSET"))'

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "VER=v0.6.0"
}

# ── UPDATED_DEPENDENCIES_JSON passthrough ─────────────────────────

@test "UPDATED_DEPENDENCIES_JSON is logged" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export UPDATED_DEPENDENCIES_JSON='[{"dependencyName":"foo","prevVersion":"0.5.0","newVersion":"0.6.0"}]'

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "Updated dependencies JSON:"
  assert_output --partial "dependencyName"
}

@test "URL mode exposes UPDATED_DEPENDENCIES_JSON to migration script" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export UPDATED_DEPENDENCIES_JSON='[{"dependencyName":"foo"}]'
  export MOCK_CURL_SCRIPT_BODY='import os, json; d = json.loads(os.environ["UPDATED_DEPENDENCIES_JSON"]); print("DEP=" + d[0]["dependencyName"])'

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "DEP=foo"
}

@test "inline script receives UPDATED_DEPENDENCIES_JSON" {
  unset SCRIPT_URL_TEMPLATE
  export MIGRATION_SCRIPT='import os, json; d = json.loads(os.environ["UPDATED_DEPENDENCIES_JSON"]); print("DEP=" + d[0]["dependencyName"])'
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export UPDATED_DEPENDENCIES_JSON='[{"dependencyName":"bar"}]'

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "DEP=bar"
}

@test "UPDATED_DEPENDENCIES_JSON is available with migration token" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export MIGRATION_TOKEN_INPUT="test-token"
  export UPDATED_DEPENDENCIES_JSON='[{"dependencyName":"tokenised"}]'
  export MOCK_CURL_SCRIPT_BODY='import os, json; d = json.loads(os.environ["UPDATED_DEPENDENCIES_JSON"]); print("DEP=" + d[0]["dependencyName"])'

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "DEP=tokenised"
}

@test "jq failure falls back to raw JSON output" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export UPDATED_DEPENDENCIES_JSON='[{"dependencyName":"fallback"}]'

  # Shadow jq with a script that always fails.
  cat >"${MOCK_DIR}/jq" <<'MOCK_JQ'
#!/usr/bin/env bash
exit 1
MOCK_JQ
  chmod +x "${MOCK_DIR}/jq"

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial '[{"dependencyName":"fallback"}]'
}

@test "malformed JSON falls back to raw output" {
  export OLD_VERSION="0.5.0"
  export NEW_VERSION="0.6.0"
  export UPDATED_DEPENDENCIES_JSON='not valid json'

  run bash "${REPO_ROOT}/scripts/run-migration.sh"
  assert_success
  assert_output --partial "not valid json"
}
