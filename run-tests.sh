#!/usr/bin/env bash
# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Run all lints and tests locally.
#
# Usage:
#   ./run-tests.sh              Run all checks
#   ./run-tests.sh --lint       Run lints only
#   ./run-tests.sh --test       Run tests only
#
# Prerequisites: shellcheck, ~/bin/actionlint, yamllint, python3.
# Initialise bats submodules with:
#   git submodule update --init --recursive

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS_LIB_DIR="${REPO_ROOT}/tests/lib"
BATS="${BATS_LIB_DIR}/bats-core/bin/bats"
YAMLLINT_CONFIG="${REPO_ROOT}/.yamllint.yaml"

# ── Check prerequisites ───────────────────────────────────────────
check_prerequisites() {
  MISSING=()
  command -v shellcheck >/dev/null 2>&1 || MISSING+=("shellcheck")
  command -v yamllint >/dev/null 2>&1 || MISSING+=("yamllint")
  command -v python3 >/dev/null 2>&1 || MISSING+=("python3")

  if ! command -v actionlint >/dev/null 2>&1; then
    MISSING+=("actionlint")
  fi

  if [ ! -x "${BATS}" ]; then
    MISSING+=("bats test libraries (see DEVELOPMENT.md)")
  fi

  if [ ${#MISSING[@]} -gt 0 ]; then
    echo "Missing tools: ${MISSING[*]}"
    echo "Install them before running checks."
    exit 1
  fi
}

# ── Run lints ─────────────────────────────────────────────────────
run_lints() {
  LINT_FAILED=0

  echo "══════════════════════════════════════════════════════════════"
  echo "Running ShellCheck..."
  echo "══════════════════════════════════════════════════════════════"
  if ! shellcheck "${REPO_ROOT}"/scripts/*.sh "${REPO_ROOT}/run-tests.sh"; then
    LINT_FAILED=1
  fi

  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "Running actionlint..."
  echo "══════════════════════════════════════════════════════════════"
  # actionlint checks workflow files only.
  # action.yml is linted by yamllint via .yamllint.yaml.
  if ! actionlint "${REPO_ROOT}"/.github/workflows/*.yaml; then
    LINT_FAILED=1
  fi

  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "Running yamllint..."
  echo "══════════════════════════════════════════════════════════════"
  YAML_FILES=(
    "${REPO_ROOT}"/.github/workflows/*.yaml
    "${REPO_ROOT}/.github/dependabot.yml"
    "${REPO_ROOT}/.yamllint.yaml"
    "${REPO_ROOT}/action.yml"
  )
  if ! yamllint \
    -c "${YAMLLINT_CONFIG}" \
    "${YAML_FILES[@]}"; then
    LINT_FAILED=1
  fi

  return "${LINT_FAILED}"
}

# ── Run tests ─────────────────────────────────────────────────────
run_tests() {
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "Running bats tests..."
  echo "══════════════════════════════════════════════════════════════"
  "${BATS}" "${REPO_ROOT}/tests/" --print-output-on-failure
}

# ── Main ──────────────────────────────────────────────────────────
case "${1:-}" in
--lint)
  check_prerequisites
  run_lints
  exit $?
  ;;
--test)
  check_prerequisites
  run_tests
  exit $?
  ;;
"")
  check_prerequisites
  FAILED=0
  run_lints || FAILED=1
  run_tests || FAILED=1
  echo ""
  if [ "${FAILED}" -ne 0 ]; then
    echo "Some checks failed."
    exit 1
  fi
  echo "All checks passed."
  ;;
*)
  echo "Usage: $0 [--lint|--test]"
  exit 1
  ;;
esac
