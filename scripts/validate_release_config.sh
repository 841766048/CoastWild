#!/bin/bash
set -euo pipefail
[[ $# -eq 2 ]] || { echo "usage: $0 <configuration.plist> <bundle-id>" >&2; exit 64; }
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$TASK_ROOT/scripts/ci/ci_support.py" config "$1" "$2"
