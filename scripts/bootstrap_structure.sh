#!/usr/bin/env bash
# Safe architecture scaffold. Adds missing directories and their .gitkeep markers.
# Does NOT rename a remote, move RTL, delete files, or overwrite content.
set -euo pipefail

if [[ ! -d .git ]]; then
  echo "Run this script from the root of your existing Git checkout." >&2
  exit 1
fi

dirs=(
  rtl/array/os rtl/array/ws
  rtl/tile/os rtl/tile/ws
  rtl/mesh/os rtl/mesh/ws
  rtl/control rtl/memory
  tb/array/os tb/array/ws tb/tile tb/mesh
  verification/reference verification/vectors verification/regressions
  scripts/sim scripts/synth scripts/implementation
  docs/architecture docs/design docs/verification
  reports/os reports/ws reports/comparison
)

for dir in "${dirs[@]}"; do
  mkdir -p "$dir"
  if [[ ! -e "$dir/.gitkeep" ]]; then
    : > "$dir/.gitkeep"
  fi
done

echo "Added missing architecture directories without moving existing RTL."
echo "Review with: git status --short"
