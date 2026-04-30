#!/usr/bin/env bash
# License: MIT
# Copyright © 2026 Frequenz Energy-as-a-Service GmbH
#
# Resolve the composite action's public outputs.
#
# Expected environment variables (set by the composite action):
#   VALIDATE_INPUTS_CONCLUSION     – conclusion of the validate-inputs step
#   CHECK_STATUS_CONCLUSION        – conclusion of the check-status step
#   HANDLE_INTERVENTION_CONCLUSION – conclusion of the handle-intervention step
#   DEPENDABOT_METADATA_CONCLUSION – conclusion of the dependabot-metadata step
#   CHECK_UPDATE_CONCLUSION        – conclusion of the check-update step
#   RUN_MIGRATION_CONCLUSION       – conclusion of the run-migration step
#   HANDLE_PATCH_UPDATE_CONCLUSION – conclusion of the handle-patch-update step
#   SCRIPT_MIGRATION_RAN           – raw migration_ran output from run-migration
#   SCRIPT_OVERALL_EXIT            – raw overall_exit output from run-migration
#   NEEDS_MIGRATION                – raw needs_migration output from check-update
#   SCRIPT_COMMIT_MADE             – raw commit_made output from commit-result
#   ALREADY_MIGRATED               – whether the PR already has the migrated label
#   INTERVENTION_PENDING           – whether the PR currently has the pending label

set -euo pipefail

if [ -n "${SCRIPT_MIGRATION_RAN:-}" ]; then
  MIGRATION_RAN="$SCRIPT_MIGRATION_RAN"
elif [ "${ALREADY_MIGRATED:-false}" = "true" ] \
  || [ "${NEEDS_MIGRATION:-}" = "false" ]; then
  MIGRATION_RAN="true"
else
  MIGRATION_RAN="false"
fi

if [ -n "${SCRIPT_OVERALL_EXIT:-}" ]; then
  OVERALL_EXIT="$SCRIPT_OVERALL_EXIT"
elif [ "${VALIDATE_INPUTS_CONCLUSION:-}" = "failure" ] \
  || [ "${CHECK_STATUS_CONCLUSION:-}" = "failure" ] \
  || [ "${HANDLE_INTERVENTION_CONCLUSION:-}" = "failure" ] \
  || [ "${DEPENDABOT_METADATA_CONCLUSION:-}" = "failure" ] \
  || [ "${CHECK_UPDATE_CONCLUSION:-}" = "failure" ] \
  || [ "${RUN_MIGRATION_CONCLUSION:-}" = "failure" ] \
  || [ "${HANDLE_PATCH_UPDATE_CONCLUSION:-}" = "failure" ]; then
  OVERALL_EXIT="1"
elif [ "${ALREADY_MIGRATED:-false}" = "true" ] \
  && [ "${INTERVENTION_PENDING:-false}" = "true" ] \
  && [ "${HANDLE_INTERVENTION_CONCLUSION:-}" != "success" ]; then
  OVERALL_EXIT="1"
else
  OVERALL_EXIT="0"
fi

if [ -n "${NEEDS_MIGRATION:-}" ]; then
  EFFECTIVE_NEEDS_MIGRATION="$NEEDS_MIGRATION"
else
  EFFECTIVE_NEEDS_MIGRATION="false"
fi

if [ -n "${SCRIPT_COMMIT_MADE:-}" ]; then
  COMMIT_MADE="$SCRIPT_COMMIT_MADE"
else
  COMMIT_MADE="false"
fi

{
  echo "migration_ran=$MIGRATION_RAN"
  echo "overall_exit=$OVERALL_EXIT"
  echo "needs_migration=$EFFECTIVE_NEEDS_MIGRATION"
  echo "commit_made=$COMMIT_MADE"
} >>"$GITHUB_OUTPUT"
