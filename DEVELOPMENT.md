# Development

This repository uses shell scripts, YAML workflows, and bats tests.
There is no build step.

## Quick start

```sh
# One-time setup for pinned bats submodules used by the tests.
git submodule update --init --recursive

# Run the full local check suite (lint + tests).
./run-tests.sh
```

`run-tests.sh` uses the bats runtime pinned in `tests/lib/*` submodules.
Dependabot updates these pinned commits via the `gitsubmodule` ecosystem.

## Bats submodules

The test stack (`bats-core`, `bats-support`, `bats-assert`) is pinned via
git submodules under `tests/lib/`.
Prefer release tags when available to avoid pulling unreleased upstream
commits.

- Initialise after clone or branch switch:

  ```sh
  git submodule update --init --recursive
  ```

- Update all three submodules to their tracked upstream branch tips:

  ```sh
  git submodule update --remote tests/lib/bats-core tests/lib/bats-support tests/lib/bats-assert
  git add tests/lib/bats-core tests/lib/bats-support tests/lib/bats-assert
  ```

  Use `git ls-remote --tags <repo-url>` to inspect available tags.

- Pin to specific release tags instead of branch tips (optional):

  ```sh
  git -C tests/lib/bats-core fetch --tags
  git -C tests/lib/bats-core checkout <bats-core-tag>

  git -C tests/lib/bats-support fetch --tags
  git -C tests/lib/bats-support checkout <bats-support-tag>

  git -C tests/lib/bats-assert fetch --tags
  git -C tests/lib/bats-assert checkout <bats-assert-tag>

  git add tests/lib/bats-core tests/lib/bats-support tests/lib/bats-assert
  ```

Dependabot for `gitsubmodule` updates the submodule commit SHA.  It does
not rely on a manifest version range like npm/pip.  If SemVer tags exist,
Dependabot can use them to order releases; otherwise it falls back to
newer commits on the tracked branch.

## Install prerequisites

`run-tests.sh` checks for these tools before running:

- `shellcheck`
- `actionlint`
- `yamllint`
- `python3`
- `git`

Install each tool with your package manager and follow the official docs:

- [bats-core installation][bats-core-install]
- [ShellCheck installation][shellcheck-install]
- [actionlint installation][actionlint-install]
- [yamllint installation][yamllint-install]
- [Python installation][python-install]

For this repository, "installing bats" means initialising the pinned
submodules shown in Quick start.

`run-tests.sh` uses the same linter/test split as CI:

- `./run-tests.sh --lint`
- `./run-tests.sh --test`

## Lint configuration

YAML lint rules are centralised in `.yamllint.yaml`.
Both CI and local runs use this file so results stay consistent.

## Test layout

- `tests/run-migration.bats` — unit tests for `scripts/run-migration.sh`
- `tests/build-report.bats` — unit tests for `scripts/build-report.sh`
- `tests/label-management.bats` — unit tests for label helper scripts
- `tests/integration.bats` — helper-script integration tests
- `tests/test-helper/common.bash` — shared bats helpers and mocks

## Helper scripts

- `scripts/run-migration.sh` — download/run migration script(s)
- `scripts/build-report.sh` — build Markdown summary/comment body
- `scripts/create-label.sh` — ensure labels exist with configured metadata
- `scripts/add-label.sh` — ensure/add labels with configured colours
- `scripts/remove-label.sh` — remove labels safely when present
- `scripts/handle-intervention.sh` — intervention completion flow
- `scripts/handle-patch-update.sh` — patch-only auto-merge flow

`tests/test-helper/common.bash` provides a mock `curl` so tests can emulate
downloaded migration scripts without network access.

## CI workflow

CI is defined in `.github/workflows/ci.yaml` and runs on `ubuntu-slim`.
It has separate jobs for:

- ShellCheck
- actionlint
- yamllint
- bats tests
- Composite-action integration test

Lint jobs use reviewdog actions with GitHub Checks reporting for inline
annotations on pull requests.

[bats-core-install]: https://bats-core.readthedocs.io/en/stable/installation.html
[shellcheck-install]: https://github.com/koalaman/shellcheck#installing
[actionlint-install]: https://github.com/rhysd/actionlint/blob/main/docs/install.md
[yamllint-install]: https://yamllint.readthedocs.io/en/stable/quickstart.html
[python-install]: https://www.python.org/downloads/
