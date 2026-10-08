#!/bin/bash
# Headless ParaView on the cluster (Kitware Linux binary, MPI, Python). Run on a login node.
# Used with:  $PV/bin/pvbatch --force-offscreen-rendering render.py ...
# Version pinned in env.sh; match it on the laptop if you ever use client/server mode.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/env.sh"

mkdir -p "$PREFIX/paraview"; cd "$PREFIX/paraview"
if [ ! -x "$PV/bin/pvbatch" ]; then
  echo "=== downloading $PARAVIEW_TARBALL (~400 MB) ==="
  curl -sSL -o "$PARAVIEW_TARBALL" "$PARAVIEW_URL"
  tar xzf "$PARAVIEW_TARBALL" && rm -f "$PARAVIEW_TARBALL"
fi
"$PV/bin/pvbatch" --version
echo "=== PV=$PV ==="
