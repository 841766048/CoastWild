#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
python3 -m unittest discover -s "$TASK_ROOT/scripts/ci/tests" -p test_ci_support.py -v
bash "$TASK_ROOT/scripts/validate_release_config.sh" "$TASK_ROOT/CoastWild/Resources/IntegrationConfig.plist" com.huankecontact.coastwild
if bash "$TASK_ROOT/scripts/validate_release_config.sh" "$TASK_ROOT/CoastWild/Resources/IntegrationConfig.plist" wrong.bundle; then
  echo "Expected bundle mismatch rejection" >&2
  exit 1
fi
