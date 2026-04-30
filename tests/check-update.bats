# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Unit tests for check-update.sh.

setup() {
  load test-helper/common
  _common_setup

  # Sensible defaults — tests override as needed.
  export UPDATE_TYPE="version-update:semver-minor"
  export VERSION_ITERATION=""
  export DEPS_JSON='[{"prevVersion":"1.2.0","newVersion":"1.3.0","updateType":"version-update:semver-minor"}]'
}

teardown() {
  _common_teardown
}

# ── Version resolution ────────────────────────────────────────────────

@test "resolves old/new versions from single dependency" {
  export DEPS_JSON='[{"prevVersion":"2.0.0","newVersion":"3.0.0","updateType":"version-update:semver-major"}]'
  export UPDATE_TYPE="version-update:semver-major"

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  assert_line "Resolved update range: 2.0.0 → 3.0.0"
  grep -q "^old_version=2.0.0$" "$GITHUB_OUTPUT"
  grep -q "^new_version=3.0.0$" "$GITHUB_OUTPUT"
}

@test "resolves old/new versions from grouped dependencies" {
  export DEPS_JSON='[
    {"prevVersion":"1.0.0","newVersion":"1.1.0","updateType":"version-update:semver-minor"},
    {"prevVersion":"1.2.0","newVersion":"1.3.0","updateType":"version-update:semver-minor"}
  ]'
  export UPDATE_TYPE="version-update:semver-minor"

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  # Oldest prevVersion = 1.0.0, newest newVersion = 1.3.0
  assert_line "Resolved update range: 1.0.0 → 1.3.0"
  grep -q "^old_version=1.0.0$" "$GITHUB_OUTPUT"
  grep -q "^new_version=1.3.0$" "$GITHUB_OUTPUT"
}

@test "fails when prevVersion is missing from all dependencies" {
  export DEPS_JSON='[{"prevVersion":"","newVersion":"1.3.0","updateType":"version-update:semver-minor"}]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_failure
  assert_output --partial "Could not resolve versions"
}

@test "fails when newVersion is missing from all dependencies" {
  export DEPS_JSON='[{"prevVersion":"1.2.0","newVersion":"","updateType":"version-update:semver-minor"}]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_failure
  assert_output --partial "Could not resolve versions"
}

@test "fails when prevVersion is null" {
  export DEPS_JSON='[{"prevVersion":null,"newVersion":"1.3.0","updateType":"version-update:semver-minor"}]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_failure
  assert_output --partial "Could not resolve versions"
}

# ── UPDATE_TYPE inference from DEPS_JSON ──────────────────────────────

@test "infers major update type from DEPS_JSON when UPDATE_TYPE is empty" {
  export UPDATE_TYPE=""
  export DEPS_JSON='[
    {"prevVersion":"1.0.0","newVersion":"2.0.0","updateType":"version-update:semver-major"},
    {"prevVersion":"1.1.0","newVersion":"1.2.0","updateType":"version-update:semver-minor"}
  ]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  grep -q "^update_type=version-update:semver-major$" "$GITHUB_OUTPUT"
}

@test "infers minor update type from DEPS_JSON when UPDATE_TYPE is empty" {
  export UPDATE_TYPE=""
  export DEPS_JSON='[
    {"prevVersion":"1.0.0","newVersion":"1.1.0","updateType":"version-update:semver-minor"},
    {"prevVersion":"1.2.0","newVersion":"1.2.1","updateType":"version-update:semver-patch"}
  ]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  grep -q "^update_type=version-update:semver-minor$" "$GITHUB_OUTPUT"
}

@test "infers patch update type from DEPS_JSON when UPDATE_TYPE is empty" {
  export UPDATE_TYPE=""
  export DEPS_JSON='[{"prevVersion":"1.0.0","newVersion":"1.0.1","updateType":"version-update:semver-patch"}]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  grep -q "^update_type=version-update:semver-patch$" "$GITHUB_OUTPUT"
}

@test "uses provided UPDATE_TYPE when set" {
  export UPDATE_TYPE="version-update:semver-major"
  export DEPS_JSON='[{"prevVersion":"1.0.0","newVersion":"1.0.1","updateType":"version-update:semver-patch"}]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  grep -q "^update_type=version-update:semver-major$" "$GITHUB_OUTPUT"
}

# ── Patch short-circuit (backward-compat path) ───────────────────────

@test "patch update without version-iteration sets needs_migration=false" {
  export UPDATE_TYPE="version-update:semver-patch"
  export VERSION_ITERATION=""
  export DEPS_JSON='[{"prevVersion":"1.0.0","newVersion":"1.0.1","updateType":"version-update:semver-patch"}]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  assert_output --partial "Patch update only — no migration needed."
  grep -q "^needs_migration=false$" "$GITHUB_OUTPUT"
}

@test "patch update inferred from DEPS_JSON without version-iteration sets needs_migration=false" {
  export UPDATE_TYPE=""
  export VERSION_ITERATION=""
  export DEPS_JSON='[{"prevVersion":"1.0.0","newVersion":"1.0.1","updateType":"version-update:semver-patch"}]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  grep -q "^needs_migration=false$" "$GITHUB_OUTPUT"
}

# ── Patch with version-iteration (new path) ──────────────────────────

@test "patch update with version-iteration=patch sets needs_migration=true" {
  export UPDATE_TYPE="version-update:semver-patch"
  export VERSION_ITERATION="patch"
  export DEPS_JSON='[{"prevVersion":"1.0.0","newVersion":"1.0.1","updateType":"version-update:semver-patch"}]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  refute_output --partial "no migration needed"
  grep -q "^needs_migration=true$" "$GITHUB_OUTPUT"
}

@test "patch update with version-iteration=minor sets needs_migration=true" {
  export UPDATE_TYPE="version-update:semver-patch"
  export VERSION_ITERATION="minor"
  export DEPS_JSON='[{"prevVersion":"1.0.0","newVersion":"1.0.1","updateType":"version-update:semver-patch"}]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  grep -q "^needs_migration=true$" "$GITHUB_OUTPUT"
}

@test "patch update with version-iteration=major sets needs_migration=true" {
  export UPDATE_TYPE="version-update:semver-patch"
  export VERSION_ITERATION="major"
  export DEPS_JSON='[{"prevVersion":"1.0.0","newVersion":"1.0.1","updateType":"version-update:semver-patch"}]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  grep -q "^needs_migration=true$" "$GITHUB_OUTPUT"
}

@test "patch update with version-iteration=false sets needs_migration=true" {
  export UPDATE_TYPE="version-update:semver-patch"
  export VERSION_ITERATION="false"
  export DEPS_JSON='[{"prevVersion":"1.0.0","newVersion":"1.0.1","updateType":"version-update:semver-patch"}]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  grep -q "^needs_migration=true$" "$GITHUB_OUTPUT"
}

# ── Non-patch updates always need migration ──────────────────────────

@test "minor update sets needs_migration=true" {
  export UPDATE_TYPE="version-update:semver-minor"
  export VERSION_ITERATION=""
  export DEPS_JSON='[{"prevVersion":"1.0.0","newVersion":"1.1.0","updateType":"version-update:semver-minor"}]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  grep -q "^needs_migration=true$" "$GITHUB_OUTPUT"
}

@test "major update sets needs_migration=true" {
  export UPDATE_TYPE="version-update:semver-major"
  export VERSION_ITERATION=""
  export DEPS_JSON='[{"prevVersion":"1.0.0","newVersion":"2.0.0","updateType":"version-update:semver-major"}]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  grep -q "^needs_migration=true$" "$GITHUB_OUTPUT"
}

@test "minor update with version-iteration=minor sets needs_migration=true" {
  export UPDATE_TYPE="version-update:semver-minor"
  export VERSION_ITERATION="minor"
  export DEPS_JSON='[{"prevVersion":"1.0.0","newVersion":"1.1.0","updateType":"version-update:semver-minor"}]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  grep -q "^needs_migration=true$" "$GITHUB_OUTPUT"
}

# ── All outputs are written correctly ─────────────────────────────────

@test "writes all expected outputs for a minor update" {
  export UPDATE_TYPE="version-update:semver-minor"
  export VERSION_ITERATION=""
  export DEPS_JSON='[{"prevVersion":"1.2.0","newVersion":"1.3.0","updateType":"version-update:semver-minor"}]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  grep -q "^update_type=version-update:semver-minor$" "$GITHUB_OUTPUT"
  grep -q "^old_version=1.2.0$" "$GITHUB_OUTPUT"
  grep -q "^new_version=1.3.0$" "$GITHUB_OUTPUT"
  grep -q "^needs_migration=true$" "$GITHUB_OUTPUT"
}

@test "writes all expected outputs for a patch short-circuit" {
  export UPDATE_TYPE="version-update:semver-patch"
  export VERSION_ITERATION=""
  export DEPS_JSON='[{"prevVersion":"1.2.0","newVersion":"1.2.1","updateType":"version-update:semver-patch"}]'

  run bash "${REPO_ROOT}/scripts/check-update.sh"
  assert_success
  grep -q "^update_type=version-update:semver-patch$" "$GITHUB_OUTPUT"
  grep -q "^old_version=1.2.0$" "$GITHUB_OUTPUT"
  grep -q "^new_version=1.2.1$" "$GITHUB_OUTPUT"
  grep -q "^needs_migration=false$" "$GITHUB_OUTPUT"
}
