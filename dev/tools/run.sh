#!/bin/bash
# Headless harness run: dev/tools/run.sh "SCRIPT" — prints status lines and QML errors.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export REEFDRIFT_HOME="${REEFDRIFT_HOME:-$(mktemp -d)}"
REEFDRIFT_ROOT="$ROOT" REEFDRIFT_SCRIPT="$1" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
timeout "${TIMEOUT:-60}" qs -p dev/harness 2>&1 | grep -E 'REEFDRIFT_|Error|error|TypeError|ReferenceError|is not a function|Cannot|Unable|unavailable|not a type|warn' | grep -v -E 'QFont|propertyCache'
