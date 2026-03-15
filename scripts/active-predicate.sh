#!/usr/bin/env bash
set -euo pipefail

# active-predicate.sh — reads the active node's predicate.md content
# Usage: bash scripts/active-predicate.sh <tree-path>

TREE="${1:-.fractal}"

if [ ! -f "$TREE/root.md" ]; then
  echo "ERROR: no root.md at $TREE"
  exit 0
fi

AN=$(grep "^active_node:" "$TREE/root.md" 2>/dev/null | sed 's/^active_node:[[:space:]]*//' | tr -d "\"'" | head -1)

if [ -z "$AN" ] || [ "$AN" = "." ]; then
  cat "$TREE/root.md"
else
  if [ -f "$TREE/$AN/predicate.md" ]; then
    cat "$TREE/$AN/predicate.md"
  else
    echo "ERROR: no predicate.md at $TREE/$AN"
  fi
fi
