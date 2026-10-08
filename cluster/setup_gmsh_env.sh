#!/bin/bash
# Miniconda under your scratch + a `mesh` environment with Gmsh (Python API), numpy, scipy.
# Run on a login node (needs internet). ~5 min. Idempotent.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/env.sh"

if [ ! -x "$CONDA_ROOT/bin/conda" ]; then
  echo "=== installing Miniconda to $CONDA_ROOT ==="
  cd "$SCRATCH"
  curl -sSL -o miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
  bash miniconda.sh -b -p "$CONDA_ROOT"
  rm -f miniconda.sh
fi
. "$CONDA_ROOT/etc/profile.d/conda.sh"
if ! conda env list | grep -q "^$MESH_ENV "; then
  echo "=== creating env $MESH_ENV ==="
  conda create -y -n "$MESH_ENV" -c conda-forge python=3.12 python-gmsh numpy scipy
fi
conda activate "$MESH_ENV"
python -c "import gmsh, numpy, scipy; print('gmsh', gmsh.__version__, 'numpy', numpy.__version__, 'scipy', scipy.__version__)"
echo "=== use with: source $CONDA_ROOT/etc/profile.d/conda.sh && conda activate $MESH_ENV ==="
