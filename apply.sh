#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/scripts/check-dns-delegation.sh"

if [ ! -d "$SCRIPT_DIR/.terraform" ]; then
    terraform -chdir="$SCRIPT_DIR" init
fi

terraform -chdir="$SCRIPT_DIR" apply "$@"
