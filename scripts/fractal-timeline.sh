#!/usr/bin/env bash
set -euo pipefail

# fractal-timeline.sh — list concluded nodes from newest to oldest
# Usage:
#   bash scripts/fractal-timeline.sh              # auto-discover .fractal/
#   bash scripts/fractal-timeline.sh <tree-path>  # explicit tree or container path
#
# Output per line:
#   YYYY-MM-DD  node-name                         "One-liner from conclusion..."

# ── helpers ──────────────────────────────────────────────────────────────────

get_field() {
  local file="$1" field="$2"
  awk '
    /^---/ { if (fm==0) { fm=1; next } else { exit } }
    fm==1 && $0 ~ "^"field":" {
      sub("^"field":[[:space:]]*", "")
      gsub(/^"/, ""); gsub(/"$/, "")
      gsub(/^'"'"'/, ""); gsub(/'"'"'$/, "")
      print; exit
    }
  ' field="$field" "$file"
}

get_conclusion_oneliner() {
  local conclusion_file="$1"
  [ -f "$conclusion_file" ] || return 0
  local line
  line=$(awk '
    /^## What was achieved/ { found=1; next }
    found && /^[[:space:]]*$/ { next }
    found { print; exit }
  ' "$conclusion_file")
  [ -z "$line" ] && return 0
  if [ "${#line}" -gt 60 ]; then
    printf '%.60s...' "$line"
  else
    printf '%s' "$line"
  fi
}

# ── collect_concluded <tree_dir> <tree_root> ─────────────────────────────────
# Walks tree_dir recursively; for each node with conclusion.md, emits:
#   <mtime_epoch> <node_rel_path> <conclusion_file>

collect_concluded() {
  local tree_dir="$1"   # absolute or relative path to tree root
  local tree_root="$2"  # same as tree_dir, used for computing relative paths

  while IFS= read -r -d '' conclusion_file; do
    local node_dir
    node_dir="$(dirname "$conclusion_file")"

    # Compute relative path from tree root
    local node_rel
    node_rel="${node_dir#${tree_root}/}"
    # If node_dir == tree_root (conclusion at root), use "."
    [ "$node_rel" = "$node_dir" ] && node_rel="."

    # Skip if node_rel is empty or same as full path (couldn't strip prefix)
    [ -z "$node_rel" ] && continue

    local mtime
    mtime="$(stat -f "%m" "$conclusion_file" 2>/dev/null || echo 0)"

    printf '%s\t%s\t%s\n' "$mtime" "$node_rel" "$conclusion_file"
  done < <(find "$tree_dir" -name "conclusion.md" -print0 | sort -z)
}

# ── render_timeline <tree_dir> ───────────────────────────────────────────────

render_timeline() {
  local tree_dir="${1%/}"

  if [ ! -f "$tree_dir/root.md" ]; then
    echo "Error: no root.md in $tree_dir" >&2
    return 1
  fi

  # Collect all concluded nodes into a temp file for sorting
  local tmp
  tmp="$(mktemp)"

  collect_concluded "$tree_dir" "$tree_dir" > "$tmp"

  local count=0
  count=$(wc -l < "$tmp" | tr -d ' ')

  if [ "$count" -eq 0 ]; then
    echo "No concluded nodes found."
    rm -f "$tmp"
    return 0
  fi

  # Sort by mtime descending (newest first)
  sort -t$'\t' -k1,1rn "$tmp" | while IFS=$'\t' read -r mtime node_rel conclusion_file; do
    # Format date from epoch
    local date_str
    date_str="$(date -r "$mtime" "+%Y-%m-%d" 2>/dev/null || date "+%Y-%m-%d")"

    # Get one-liner
    local oneliner
    oneliner="$(get_conclusion_oneliner "$conclusion_file")"

    # Right-pad node name to 40 chars
    local padded_name
    padded_name="$(printf '%-40s' "$node_rel")"

    if [ -n "$oneliner" ]; then
      printf '%s  %s  "%s"\n' "$date_str" "$padded_name" "$oneliner"
    else
      printf '%s  %s\n' "$date_str" "$padded_name"
    fi
  done

  echo ""
  echo "${count} concluded nodes"

  rm -f "$tmp"
}

# ── auto-discovery ────────────────────────────────────────────────────────────

if [ -n "${1:-}" ]; then
  TREE="${1%/}"
  if [ ! -f "$TREE/root.md" ] && [ -f ".fractal/$TREE/root.md" ]; then
    TREE=".fractal/$TREE"
  fi
else
  if [ -f ".fractal/root.md" ]; then
    TREE=".fractal"
  else
    FOUND=()
    for rootmd in .fractal/*/root.md; do
      [ -f "$rootmd" ] || continue
      FOUND+=("$(dirname "$rootmd")")
    done
    if [ "${#FOUND[@]}" -gt 1 ]; then
      echo "multiple_trees: true"
      for t in "${FOUND[@]}"; do
        echo "tree: $(basename "$t")"
      done
      exit 2
    elif [ "${#FOUND[@]}" -eq 1 ]; then
      TREE="${FOUND[0]}"
    else
      echo "Error: no fractal tree found in .fractal/" >&2
      exit 1
    fi
  fi
fi

if [ ! -f "$TREE/root.md" ]; then
  # Maybe it's a container directory — find all top-level trees
  found=0
  while IFS= read -r -d '' tree_dir; do
    parent="$(dirname "$tree_dir")"
    if [ "$parent" = "$TREE" ]; then
      [ "$found" -gt 0 ] && echo ""
      render_timeline "$tree_dir"
      found=$((found + 1))
    fi
  done < <(find "$TREE" -name "root.md" -print0 | sort -z | xargs -0 -I{} dirname {} | sort -zu)

  if [ "$found" -eq 0 ]; then
    echo "No trees found in $TREE" >&2
    exit 1
  fi
else
  render_timeline "$TREE"
fi
