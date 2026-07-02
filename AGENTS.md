# AGENTS.md

Guidelines for AI coding agents working in this repository.

## Project overview

A composite GitHub Action that runs migration scripts on Dependabot PRs.
The codebase is small: a composite action definition (`action.yml`), helper
shell scripts, a bats test suite, configs, and documentation.  There is no
application code, no package manager, and no compiled artefacts.

## Build / lint / test

There is no build step.  Linting and tests run in CI via
`.github/workflows/ci.yaml`.  Run the same checks locally with:

```sh
# One-time setup for bats-core and helper libraries
git submodule update --init --recursive

# Run all lints and tests (recommended)
./run-tests.sh

# Lints only / tests only
./run-tests.sh --lint
./run-tests.sh --test
```

Individual tools:

```sh
shellcheck scripts/*.sh run-tests.sh                      # Lint shell scripts
actionlint .github/workflows/*.yaml                       # Lint workflows
yamllint -c .yamllint.yaml \
  .github/workflows/*.yaml .github/dependabot.yml \
  .yamllint.yaml action.yml                                # Lint YAML files
tests/lib/bats-core/bin/bats tests/ --print-output-on-failure  # All tests
```

Run a **single test file**:

```sh
tests/lib/bats-core/bin/bats tests/run-migration.bats --print-output-on-failure
```

Run a **single test by name** (regex filter):

```sh
tests/lib/bats-core/bin/bats tests/run-migration.bats \
  --filter "constructs correct version list" --print-output-on-failure
```

When changing `action.yml`, review step numbering and confirm that `if:`
conditions, output references, and step IDs are consistent.

## Repository layout

```
action.yml                  # Composite action definition
scripts/run-migration.sh    # Helper: run migration scripts
scripts/build-report.sh     # Helper: build Markdown summary
scripts/check-update.sh     # Helper: decide if migration is needed
scripts/validate-inputs.sh  # Helper: validate composite action inputs
scripts/resolve-outputs.sh  # Helper: consolidate public outputs
scripts/create-label.sh     # Helper: ensure label exists/updated
scripts/add-label.sh        # Helper: ensure/add PR labels
scripts/remove-label.sh     # Helper: remove PR labels safely
scripts/handle-intervention.sh  # Helper: intervention completion logic
scripts/handle-patch-update.sh  # Helper: patch-only auto-merge logic
scripts/check-status.sh         # Helper: read labels + commit history,
                                # self-heal migrated label if the
                                # migration commit is gone
run-tests.sh                # Local lint/test entrypoint
.yamllint.yaml              # yamllint configuration
tests/*.bats                # Unit and integration tests
tests/test-helper/common.bash  # Shared bats helpers and mocks
.github/workflows/ci.yaml  # CI workflow
```

## Helper script pattern

The composite action executes helper scripts via `github.action_path`.
Inputs are passed via `env:` (never inline `${{ }}` inside `run:` blocks).
Expected env vars are documented in each script's header.  Outputs are
written to `$GITHUB_OUTPUT`.

## Test patterns

Tests use bats-core with bats-assert.  Each `.bats` file loads
`test-helper/common` which provides `_common_setup` and `_common_teardown`.
Setup creates a temp `GITHUB_OUTPUT` file and a `MOCK_DIR` with a mock
`curl` prepended to `PATH`.  The mock curl is configurable per-call via
`MOCK_CURL_HTTP_CODE_N` and `MOCK_CURL_SCRIPT_BODY_N` env vars.  Tests
invoke scripts with `run bash "${REPO_ROOT}/scripts/script.sh"` and assert on
stdout/stderr and on the contents of `$GITHUB_OUTPUT`.

## Code style — shell scripts

### Header

```bash
#!/usr/bin/env bash
# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# One-line description of the script.
#
# Expected environment variables (set by the composite action):
#   VAR_NAME  – description
```

### Error handling

- Default to `set -euo pipefail`.
- If errors must be handled explicitly, use `set -uo pipefail` (omit `-e`)
  and add a comment explaining why.
- Use `echo "::error::message"` / `echo "::warning::message"` for GitHub
  Actions annotations.
- Use `|| true` only for non-critical operations.
- Default values are not used for expected environment variables, the caller
  should ensure they are set correctly.

### Variables and expressions

- `UPPER_SNAKE_CASE` for all variables — no local/env distinction.
- Always double-quote expansions: `"$VAR"`, `"${ARRAY[@]}"`.
- Use single brackets `[ ... ]` for tests, not `[[ ]]`.

### GitHub Actions outputs

```bash
echo "key=value" >>"$GITHUB_OUTPUT"           # single-line
{
  echo "key<<KEY_EOF"
  echo "$VALUE"
  echo "KEY_EOF"
} >>"$GITHUB_OUTPUT"                           # multi-line
```

## Code style — YAML

- 2-space indentation, UTF-8, LF line endings, final newline, no trailing
  whitespace (per `.editorconfig`).
- Workflow files use `.yaml`; GitHub-mandated files use `.yml`.
- Every YAML file starts with the license header:
  `# License: MIT` / `# Copyright © 2026 Frequenz Energy-as-a-Service GmbH`
- Section separators: `# ═══...` for jobs, `# ── N. Description ────...`
  for steps (keep the step overview table in sync).
- `>-` (folded, strip) for `if:` and `description:` fields.
- `|` (literal) for `run:` blocks.
- Double quotes for YAML string values: `default: "3.14"`.
- Single quotes inside expressions: `== 'true'`.
- Map `${{ }}` expressions to `env:` variables; reference as shell vars in
  `run:` blocks.

## Naming conventions

| Element              | Style             | Examples                              |
|----------------------|-------------------|---------------------------------------|
| Files / directories  | kebab-case        | `run-migration.sh`, `build-report.sh` |
| Workflow inputs      | kebab-case        | `script-url-template`                 |
| Step IDs             | kebab-case        | `check-status`, `run-migration`       |
| Output keys          | snake_case        | `migration_ran`, `overall_exit`       |
| Env / shell vars     | UPPER_SNAKE_CASE  | `OLD_VERSION`, `GITHUB_OUTPUT`        |
| Labels               | prefix:kebab-case | `tool:migration:migrated`             |

## Action version pinning

- Third-party actions: full SHA pin with version comment
  (`uses: org/action@<sha> # vX.Y.Z`).
- First-party / trusted actions: semver tag (`@vX` or `@vX.Y.Z`).

## Language and spelling

- British English: "normalise", "labelling", etc.
- Two spaces after full stops in comments and descriptions.
- Use `©` (not `(c)`) in copyright notices.
- Use em-dash (—) for parenthetical remarks in comments.

## Commit messages

- Subject line: imperative mood, no trailing period, ideally ≤50 chars
  (up to ~72 is OK).
- Body: explain *why*, not just *what*; wrap at 72 chars.
- Always sign commits (`git commit -s`).
- One logical change per commit.
